/// 同步引擎的远端仓库抽象（doc/sync-design.md §8.4 / §9.3）。
///
/// 接口按同步会话（§8.1）的步骤切分：
/// ① [RemoteRepo.fetchHead] → ② [RemoteRepo.listTree] →
/// ④ [RemoteRepo.fetchBlob] → ⑥ [RemoteRepo.commitChanges]。
///
/// 两个实现：
/// - GitHub（`github_remote.dart`）：Git Data API 单提交原子写入，
///   updateRef 作仓库级乐观锁（失败抛 [RemoteHeadMovedException]，
///   引擎回到步骤 ① 重试，最多 3 次）；
/// - Gitee（`gitee_remote.dart`）：v5 无 git-data 写端点，逐文件
///   contents API + per-file sha 乐观锁，单文件失败不中断（§8.1 要点）。
///
/// 该层不理解笔记语义（id/front-matter/判定表），只搬运文件字节。
library;

import 'package:http/http.dart' as http;

import '../../../domain/models/git_config.dart';
import '../sync_planner.dart' show RemoteFileState;
import 'gitee_remote.dart';
import 'github_remote.dart';

/// 一次远端写入；[deleteOldPath] 非空表示重命名——旧路径的删除与新路径的
/// 写入必须捆绑：GitHub 进同一提交；Gitee 只有写入成功才删除旧路径，
/// 保证中断时最多残留旧文件、绝不丢内容（§8.4）。
class RemoteWrite {
  const RemoteWrite({
    required this.path,
    required this.content,
    this.remoteBlobSha,
    this.deleteOldPath,
    this.deleteOldPathSha,
  });

  final String path;
  final String content;

  /// [path] 处远端当前 blob sha：Gitee 更新的乐观锁凭据；创建为 null。
  final String? remoteBlobSha;

  /// 重命名时的旧路径。
  final String? deleteOldPath;

  /// 旧路径的 blob sha（Gitee 删除凭据）。
  final String? deleteOldPathSha;
}

/// 一次远端删除（规则 5 的纯删除；重命名的删除走 [RemoteWrite.deleteOldPath]）。
class RemoteDelete {
  const RemoteDelete({required this.path, required this.remoteBlobSha});

  final String path;

  /// Gitee 删除凭据；GitHub 原子提交不需要（tree 层面移除）。
  final String remoteBlobSha;
}

class RemoteCommitRequest {
  const RemoteCommitRequest({
    required this.message,
    required this.writes,
    required this.deletes,
    this.expectedHeadSha,
  });

  /// 提交信息（§8.3 模板）。Gitee 逐文件模式下每个操作复用同一条。
  final String message;

  final List<RemoteWrite> writes;
  final List<RemoteDelete> deletes;

  /// 会话步骤 ① 取到的 head commit sha；null 表示空仓库/分支不存在
  /// （GitHub 走首次提交 + 创建分支 ref）。
  final String? expectedHeadSha;

  bool get isEmpty => writes.isEmpty && deletes.isEmpty;
}

class RemoteCommitResult {
  const RemoteCommitResult({
    this.newHeadSha,
    this.failedPaths = const {},
    this.failureMessages = const {},
  });

  /// GitHub：新提交 sha；Gitee 逐文件模式为 null（引擎不依赖——
  /// 写入内容的 blob sha 可由 computeBlobSha 本地推得）。
  final String? newHeadSha;

  /// 逐文件模式下失败的路径（写入失败记新路径，删除失败记删除路径）。
  /// 原子模式（GitHub）要么全部成功要么抛异常，恒为空。
  final Set<String> failedPaths;

  /// 失败路径 → 错误信息（供同步日志展示）。
  final Map<String, String> failureMessages;

  bool get allSucceeded => failedPaths.isEmpty;
}

/// 远端操作异常基类。
class RemoteException implements Exception {
  const RemoteException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? message : '$message (HTTP $statusCode)';
}

/// 仓库级乐观锁失败：提交期间远端 head 又前进了（非 fast-forward）。
/// 引擎应放弃本轮写入、回到会话步骤 ① 重新拉清单判定（§8.1 步骤 ⑦）。
class RemoteHeadMovedException extends RemoteException {
  const RemoteHeadMovedException(super.message, {super.statusCode});
}

/// 远端清单不完整（GitHub trees API `truncated: true`）。
/// 必须中止会话：不完整的清单会让判定器把"未列出"误判为"远端已删除"，
/// 进而删除本地笔记（安全红线，不变量 I3）。
class RemoteListingTruncatedException extends RemoteException {
  const RemoteListingTruncatedException(super.message);
}

/// 远端仓库操作接口（实现见 github_remote.dart / gitee_remote.dart）。
abstract interface class RemoteRepo {
  /// 分支 head commit sha；分支不存在或空仓库返回 null。
  Future<String?> fetchHead();

  /// 递归列出 [headSha] 下的全部 blob（path + blob sha）。
  /// 引擎自行按 notesDir 前缀与扩展名过滤。
  Future<List<RemoteFileState>> listTree(String headSha);

  /// 按 blob sha 读取内容并按 UTF-8 解码。
  /// 走 git blobs 端点，不受 contents API 1MB 限制（§10）。
  Future<String> fetchBlob(String blobSha);

  /// 查询某文件在远端最新一次提交的**服务端提交时间**（committer date，
  /// 非任何设备本地时钟）。仅在确认冲突时调用（罕见），供二选一弹窗展示
  /// 供用户参考（§7.1）。无法获取时返回 null，不阻断同步。
  Future<DateTime?> fetchLastCommitTime(String path);

  /// 提交一批变更。请求为空时直接返回空结果，不产生网络请求。
  Future<RemoteCommitResult> commitChanges(RemoteCommitRequest request);
}

/// 按配置构造对应平台的远端实现。[client] 供测试注入。
RemoteRepo createRemoteRepo(GitConfig config, {http.Client? client}) {
  switch (config.platform) {
    case GitPlatform.github:
      return GitHubRemote(config, client: client);
    case GitPlatform.gitee:
      return GiteeRemote(config, client: client);
  }
}
