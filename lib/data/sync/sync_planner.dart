/// 同步判定器（doc/sync-design.md §6 判定表 + §6.3 重命名对账 + §5.3 路径分配）。
///
/// 纯函数：输入本地文件状态、base 快照、远端清单（及按需下载的远端内容），
/// 输出动作计划。不做任何 IO、不运行 diff3（规则 4 产出 [MergeAction]，
/// 由引擎执行合并并分流冲突处理）。
///
/// 两阶段调用协议：首次调用若返回的 [SyncPlan.needsDownload] 非空，
/// 引擎下载这些路径后携带 `downloads` 重新调用；此时动作列表为空，
/// 不得部分执行。全部所需内容就绪后返回完整动作计划（至多两轮）。
///
/// 身份键（key）约定（§5.1）：
/// - Markdown：front-matter `id`；
/// - txt：远端路径（路径即身份，重命名 = 删除旧 + 新建新，由引擎在
///   进入判定器之前拆分为两个独立条目）；
/// - 从未同步的新笔记：引擎提供的任意唯一键（推送成功后由引擎落 base）。
library;

import 'blob_sha.dart';

// ---------------------------------------------------------------------------
// 输入模型
// ---------------------------------------------------------------------------

/// 本地笔记的文件视角快照（引擎已把 Note 序列化为仓库文件内容）。
class LocalFileState {
  const LocalFileState({
    required this.key,
    required this.title,
    required this.extension,
    required this.content,
    this.path,
  });

  final String key;

  /// 当前远端路径；null = 从未同步（待分配）。已同步笔记与 base.path 一致。
  final String? path;

  final String title;

  /// 'md' 或 'txt'。
  final String extension;

  /// 完整文件内容（md 含 front-matter）。
  final String content;
}

/// base 快照：上次同步成功时双方共识的版本（§4.1，不变量 I2）。
class BaseEntry {
  const BaseEntry({
    required this.key,
    required this.path,
    required this.blobSha,
    required this.content,
  });

  final String key;
  final String path;
  final String blobSha;
  final String content;
}

/// 远端清单条目（来自 trees API，未下载内容）。
class RemoteFileState {
  const RemoteFileState({required this.path, required this.blobSha});

  final String path;
  final String blobSha;
}

/// 已下载的远端文件内容；[frontMatterId] 由引擎解析 front-matter 得出
/// （txt 或无 front-matter 的 md 为 null）。
class DownloadedRemoteFile {
  const DownloadedRemoteFile({
    required this.path,
    required this.content,
    this.frontMatterId,
  });

  final String path;
  final String content;
  final String? frontMatterId;
}

// ---------------------------------------------------------------------------
// 输出模型
// ---------------------------------------------------------------------------

/// 判定产物。[needsDownload] 非空时 [actions] 必为空（见库注释的两阶段协议）。
class SyncPlan {
  const SyncPlan({required this.needsDownload, required this.actions});

  final List<String> needsDownload;
  final List<SyncAction> actions;
}

sealed class SyncAction {
  const SyncAction();

  String get key;
}

/// 推送本地内容到远端（规则 2/7/9 及规则 2 的重命名变体）。
class PushAction extends SyncAction {
  const PushAction({
    required this.key,
    required this.path,
    required this.content,
    this.oldPath,
    this.remoteBlobSha,
    this.recreatesRemoteDeleted = false,
  });

  @override
  final String key;

  /// 目标路径（重命名时为新路径）。
  final String path;

  /// 重命名时的旧路径：与新路径写入同一提交（GitHub）或先建后删（Gitee）。
  final String? oldPath;

  final String content;

  /// 远端当前 blob sha，供 Gitee 逐文件乐观锁：无重命名时是 [path] 处的
  /// 更新凭据；重命名时是 [oldPath] 处的删除凭据。创建（规则 7/9）为 null。
  final String? remoteBlobSha;

  /// 规则 7：远端已删除但本地有修改，重建远端文件（引擎应提示用户）。
  final bool recreatesRemoteDeleted;

  /// 成功后 base ← (key, path, 本地内容)。
}

/// 以远端内容覆盖/导入本地（规则 3/8/10 及远端重命名变体）。
class PullAction extends SyncAction {
  const PullAction({
    required this.key,
    required this.path,
    required this.content,
    required this.blobSha,
    this.oldPath,
    this.isNew = false,
    this.restoresLocalDeleted = false,
    this.duplicateOfKey,
    this.needsIdInjection = false,
  });

  /// md 有 id → id；md 无 id / txt → 路径（见 [needsIdInjection]）。
  @override
  final String key;

  final String path;

  /// 远端重命名（§6.3）：本地记录需从旧路径迁到 [path]。
  final String? oldPath;

  final String content;

  /// 落盘成功后写入 base 的远端 blob sha。
  final String blobSha;

  /// 规则 10：本地不存在，导入新笔记。
  final bool isNew;

  /// 规则 8：本地已删除但远端有修改，恢复该笔记（引擎应提示用户，
  /// 用户再删需重新确认，不自动重删）。
  final bool restoresLocalDeleted;

  /// §5.4 重复 id：远端出现与既有笔记相同 id 的第二个文件。按新笔记导入，
  /// 引擎须改写新 id 并在下轮推送回写远端。
  final String? duplicateOfKey;

  /// md 文件无 front-matter id（外部工具创建）：导入时注入新 id（“收编”），
  /// 注入产生的内容变化由下轮推送自然回写。
  final bool needsIdInjection;
}

/// 删除远端文件（规则 5；远端已重命名时作用于新路径）。
class DeleteRemoteAction extends SyncAction {
  const DeleteRemoteAction({
    required this.key,
    required this.path,
    required this.remoteBlobSha,
  });

  @override
  final String key;
  final String path;

  /// Gitee 删除接口的乐观锁凭据。
  final String remoteBlobSha;
}

/// 删除本地笔记（规则 6：远端已删除且本地无修改）。
class DeleteLocalAction extends SyncAction {
  const DeleteLocalAction({required this.key});

  @override
  final String key;
}

/// 双方都有修改（规则 4/11）：交引擎跑 diff3，干净则双写，
/// 冲突则走冲突副本流程（§7.2）。规则 11（无共同祖先）时 [baseContent] 为空串。
class MergeAction extends SyncAction {
  const MergeAction({
    required this.key,
    required this.path,
    required this.baseContent,
    required this.localContent,
    required this.remoteContent,
    required this.remoteBlobSha,
    this.oldPath,
  });

  @override
  final String key;

  /// 合并结果的落点路径（任一侧重命名时为对应新路径，远端命名优先）。
  final String path;

  /// 路径发生变化时的旧路径。
  final String? oldPath;

  final String baseContent;
  final String localContent;
  final String remoteContent;

  /// 远端当前内容所在路径的 blob sha（乐观锁/删除凭据）：
  /// 无重命名时即 [path] 处的 sha；任一侧重命名时为远端内容实际所在
  /// 路径（本地改名 → [oldPath]；远端改名 → [path]）的 sha。
  final String remoteBlobSha;
}

/// 双方内容已一致但 base 缺失/过期：仅建立 base，无网络 IO
/// （规则 4 伪分叉快路径、规则 11 内容相同）。
class AdoptBaseAction extends SyncAction {
  const AdoptBaseAction({
    required this.key,
    required this.path,
    required this.content,
    required this.blobSha,
  });

  @override
  final String key;
  final String path;
  final String content;
  final String blobSha;
}

/// 双方都已删除：仅清掉遗留的 base 记录。
class ForgetBaseAction extends SyncAction {
  const ForgetBaseAction({required this.key});

  @override
  final String key;
}

// ---------------------------------------------------------------------------
// 判定主流程
// ---------------------------------------------------------------------------

SyncPlan planSync({
  required List<LocalFileState> locals,
  required List<BaseEntry> bases,
  required List<RemoteFileState> remoteFiles,
  required String notesDir,
  Map<String, DownloadedRemoteFile> downloads = const {},
}) {
  final localByKey = <String, LocalFileState>{};
  for (final l in locals) {
    if (localByKey.containsKey(l.key)) {
      throw ArgumentError('重复的本地身份键: ${l.key}');
    }
    localByKey[l.key] = l;
  }
  final baseByKey = <String, BaseEntry>{};
  for (final b in bases) {
    if (baseByKey.containsKey(b.key)) {
      throw ArgumentError('重复的 base 身份键: ${b.key}');
    }
    baseByKey[b.key] = b;
  }
  final remoteByPath = {for (final r in remoteFiles) r.path: r};

  final basePaths = {for (final b in bases) b.path};

  // 未匹配远端文件：不在任何 base.path 上，可能是新增/重命名目标/重复 id。
  // 全部需要内容（front-matter id）才能完成对账。
  final unmatchedRemote =
      remoteFiles.where((r) => !basePaths.contains(r.path)).toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final needsDownload = <String>{};
  for (final r in unmatchedRemote) {
    if (!downloads.containsKey(r.path)) needsDownload.add(r.path);
  }

  // 远端 id → 路径 索引（仅来自已下载的未匹配文件）。
  final remoteIdToPath = <String, String>{};
  for (final r in unmatchedRemote) {
    final id = downloads[r.path]?.frontMatterId;
    if (id != null) remoteIdToPath[id] = r.path;
  }

  // 路径占用表（小写比较：git 大小写敏感，但避免产生仅大小写不同的路径，
  // 防止仓库在 Windows 上 clone 时文件互踩）。
  final occupiedLower = <String>{
    for (final r in remoteFiles) r.path.toLowerCase(),
    for (final l in locals)
      if (l.path != null) l.path!.toLowerCase(),
  };

  final actions = <SyncAction>[];
  final claimedRemotePaths = <String>{};

  // 有未下载的未匹配远端文件时，无法区分"远端重命名"与"远端删除"
  // （id 未知），相关判定必须推迟到下一轮。
  final hasUndownloadedUnmatched =
      unmatchedRemote.any((r) => !downloads.containsKey(r.path));

  /// 规则 3/4/8 需要远端内容；缺失时登记下载并跳过该键（本轮计划会作废）。
  DownloadedRemoteFile? requireDownload(String path) {
    final dl = downloads[path];
    if (dl == null) needsDownload.add(path);
    return dl;
  }

  final allKeys = {...localByKey.keys, ...baseByKey.keys}.toList()..sort();

  for (final key in allKeys) {
    final base = baseByKey[key];
    final local = localByKey[key];

    // ---- 无 base：本地新建（规则 9 / 11） ----
    if (base == null) {
      final l = local!;
      final remotePathSameId = remoteIdToPath[key];
      if (remotePathSameId != null) {
        // 规则 11：双端同源新建（同 id）。
        claimedRemotePaths.add(remotePathSameId);
        final rf = remoteByPath[remotePathSameId]!;
        final dl = downloads[remotePathSameId]!;
        if (computeBlobSha(l.content) == rf.blobSha) {
          actions.add(AdoptBaseAction(
            key: key,
            path: remotePathSameId,
            content: l.content,
            blobSha: rf.blobSha,
          ));
        } else {
          actions.add(MergeAction(
            key: key,
            path: remotePathSameId,
            baseContent: '',
            localContent: l.content,
            remoteContent: dl.content,
            remoteBlobSha: rf.blobSha,
          ));
        }
      } else {
        // 规则 9：推送新笔记。
        final path = allocatePath(
          dir: notesDir,
          title: l.title,
          key: key,
          extension: l.extension,
          occupiedLower: occupiedLower,
        );
        actions.add(PushAction(key: key, path: path, content: l.content));
      }
      continue;
    }

    // ---- 有 base ----
    final localExists = local != null;
    final localSha = localExists ? computeBlobSha(local.content) : null;
    final contentChanged = localExists && localSha != base.blobSha;
    final renameWanted = localExists &&
        local.extension == 'md' &&
        _renameWanted(local.title, base.path, key);
    final localChanged = contentChanged || renameWanted;

    final remoteAtBase = remoteByPath[base.path];

    if (remoteAtBase != null) {
      // ---- base 路径仍在远端（规则 1–5、7 不涉及；5 指本地删）----
      final remoteChanged = remoteAtBase.blobSha != base.blobSha;

      if (!localExists) {
        if (!remoteChanged) {
          // 规则 5：本地删除传播到远端。
          actions.add(DeleteRemoteAction(
            key: key,
            path: base.path,
            remoteBlobSha: remoteAtBase.blobSha,
          ));
        } else {
          // 规则 8：本地删、远端改 → 删除让位于修改，恢复到本地。
          final dl = requireDownload(base.path);
          if (dl != null) {
            actions.add(PullAction(
              key: key,
              path: base.path,
              content: dl.content,
              blobSha: remoteAtBase.blobSha,
              restoresLocalDeleted: true,
            ));
          }
        }
        continue;
      }

      if (!localChanged && !remoteChanged) continue; // 规则 1

      if (localChanged && !remoteChanged) {
        // 规则 2：推送（可能含重命名）。
        final newPath = renameWanted
            ? allocatePath(
                dir: _posixDirname(base.path),
                title: local.title,
                key: key,
                extension: local.extension,
                occupiedLower: occupiedLower,
                selfPath: base.path,
              )
            : base.path;
        actions.add(PushAction(
          key: key,
          path: newPath,
          oldPath: renameWanted ? base.path : null,
          content: local.content,
          remoteBlobSha: remoteAtBase.blobSha,
        ));
        continue;
      }

      if (!localChanged && remoteChanged) {
        // 规则 3：拉取覆盖本地。
        final dl = requireDownload(base.path);
        if (dl != null) {
          actions.add(PullAction(
            key: key,
            path: base.path,
            content: dl.content,
            blobSha: remoteAtBase.blobSha,
          ));
        }
        continue;
      }

      // 规则 4：双方都变。
      if (localSha == remoteAtBase.blobSha) {
        // 伪分叉：内容已一致（双方做了同样的修改）。
        if (renameWanted) {
          // 内容一致但本地想改名 → 纯重命名推送。
          final newPath = allocatePath(
            dir: _posixDirname(base.path),
            title: local.title,
            key: key,
            extension: local.extension,
            occupiedLower: occupiedLower,
            selfPath: base.path,
          );
          actions.add(PushAction(
            key: key,
            path: newPath,
            oldPath: base.path,
            content: local.content,
            remoteBlobSha: remoteAtBase.blobSha,
          ));
        } else {
          actions.add(AdoptBaseAction(
            key: key,
            path: base.path,
            content: local.content,
            blobSha: remoteAtBase.blobSha,
          ));
        }
        continue;
      }
      final dl = requireDownload(base.path);
      if (dl != null) {
        final newPath = renameWanted
            ? allocatePath(
                dir: _posixDirname(base.path),
                title: local.title,
                key: key,
                extension: local.extension,
                occupiedLower: occupiedLower,
                selfPath: base.path,
              )
            : base.path;
        actions.add(MergeAction(
          key: key,
          path: newPath,
          oldPath: renameWanted ? base.path : null,
          baseContent: base.content,
          localContent: local.content,
          remoteContent: dl.content,
          remoteBlobSha: remoteAtBase.blobSha,
        ));
      }
      continue;
    }

    // ---- base 路径从远端消失：重命名或删除（§6.3）----
    final renamedPath = remoteIdToPath[key];
    if (renamedPath == null && hasUndownloadedUnmatched) {
      // 未匹配文件未全部下载，无法断定是否为重命名；
      // 本轮计划会因 needsDownload 非空而作废，跳过该键。
      continue;
    }
    if (renamedPath != null) {
      // 远端重命名/移动，可能伴随内容修改。落点采纳远端新路径。
      claimedRemotePaths.add(renamedPath);
      final rf = remoteByPath[renamedPath]!;
      final dl = downloads[renamedPath]!;
      final remoteChanged = rf.blobSha != base.blobSha;

      if (!localExists) {
        if (remoteChanged) {
          // 规则 8 变体：本地删、远端（移动并）改 → 恢复。
          actions.add(PullAction(
            key: key,
            path: renamedPath,
            oldPath: base.path,
            content: dl.content,
            blobSha: rf.blobSha,
            restoresLocalDeleted: true,
          ));
        } else {
          // 规则 5 变体：本地删除传播，作用于远端新路径。
          actions.add(DeleteRemoteAction(
            key: key,
            path: renamedPath,
            remoteBlobSha: rf.blobSha,
          ));
        }
      } else if (!contentChanged && !remoteChanged) {
        // 仅路径变化：本地记录迁移到新路径（内容原样回写）。
        // 注：本地此时若想改名（renameWanted），远端命名优先，下轮不再触发
        // （引擎更新 filePath 后 renameWanted 以新路径重新评估）。
        actions.add(PullAction(
          key: key,
          path: renamedPath,
          oldPath: base.path,
          content: dl.content,
          blobSha: rf.blobSha,
        ));
      } else if (contentChanged && !remoteChanged) {
        // 本地内容领先，推送到远端新路径。
        actions.add(PushAction(
          key: key,
          path: renamedPath,
          content: local.content,
          remoteBlobSha: rf.blobSha,
        ));
      } else if (!contentChanged && remoteChanged) {
        actions.add(PullAction(
          key: key,
          path: renamedPath,
          oldPath: base.path,
          content: dl.content,
          blobSha: rf.blobSha,
        ));
      } else {
        actions.add(MergeAction(
          key: key,
          path: renamedPath,
          oldPath: base.path,
          baseContent: base.content,
          localContent: local.content,
          remoteContent: dl.content,
          remoteBlobSha: rf.blobSha,
        ));
      }
      continue;
    }

    // 真·远端删除。
    if (!localExists) {
      actions.add(ForgetBaseAction(key: key)); // 双端都删
    } else if (!localChanged) {
      actions.add(DeleteLocalAction(key: key)); // 规则 6
    } else {
      // 规则 7：删除让位于修改，按新文件重建远端。
      final path = allocatePath(
        dir: _posixDirname(base.path),
        title: local.title,
        key: key,
        extension: local.extension,
        occupiedLower: occupiedLower,
        selfPath: base.path, // 自身旧路径（远端已空闲）优先复用
      );
      actions.add(PushAction(
        key: key,
        path: path,
        content: local.content,
        recreatesRemoteDeleted: true,
      ));
    }
  }

  // ---- 第二遍：未被认领的未匹配远端文件（规则 10 / §5.4 重复 id）----
  for (final rf in unmatchedRemote) {
    if (claimedRemotePaths.contains(rf.path)) continue;
    final dl = downloads[rf.path];
    if (dl == null) continue; // 已登记 needsDownload

    final id = dl.frontMatterId;
    if (id != null && baseByKey.containsKey(id)) {
      // 重复 id：id 的正身仍在 base.path 上（否则第一遍已按重命名认领）。
      actions.add(PullAction(
        key: rf.path,
        path: rf.path,
        content: dl.content,
        blobSha: rf.blobSha,
        isNew: true,
        duplicateOfKey: id,
      ));
      continue;
    }
    final isMd = rf.path.toLowerCase().endsWith('.md');
    actions.add(PullAction(
      key: id ?? rf.path,
      path: rf.path,
      content: dl.content,
      blobSha: rf.blobSha,
      isNew: true,
      needsIdInjection: isMd && id == null,
    ));
  }

  if (needsDownload.isNotEmpty) {
    return SyncPlan(
      needsDownload: needsDownload.toList()..sort(),
      actions: const [],
    );
  }
  return SyncPlan(needsDownload: const [], actions: actions);
}

// ---------------------------------------------------------------------------
// 路径策略（§5.3）
// ---------------------------------------------------------------------------

const _windowsReservedNames = {
  'CON', 'PRN', 'AUX', 'NUL', //
  'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
  'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
};

/// 标题 → 合法文件名（不含扩展名）：替换 Windows/Unix 非法字符、去控制字符、
/// 去首尾空白与点号、截断至 80 字符、规避 Windows 保留设备名，空标题回退
/// untitled。
String sanitizeFileTitle(String title) {
  var s = title
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  s = _trimDotsAndSpaces(s);
  if (s.length > 80) {
    s = s.substring(0, 80);
    // 避免截断在 UTF-16 代理对中间产生非法字符。
    final last = s.codeUnitAt(s.length - 1);
    if (last >= 0xD800 && last <= 0xDBFF) s = s.substring(0, s.length - 1);
    s = _trimDotsAndSpaces(s);
  }
  if (_windowsReservedNames.contains(s.toUpperCase())) s = '$s-note';
  if (s.isEmpty) s = 'untitled';
  return s;
}

String _trimDotsAndSpaces(String s) =>
    s.replaceAll(RegExp(r'^[. \t]+|[. \t]+$'), '');

/// 在 [dir] 下为标题分配未被占用的路径：`{title}.{ext}` →
/// `{title}-{key 前 8 位}.{ext}` → `{title}-{key}.{ext}`。
/// 占用比较大小写不敏感；[selfPath]（当前自身路径）不算占用。
/// 分配结果会加入 [occupiedLower]，保证同一轮规划内不重复分配。
String allocatePath({
  required String dir,
  required String title,
  required String key,
  required String extension,
  required Set<String> occupiedLower,
  String? selfPath,
}) {
  final name = sanitizeFileTitle(title);
  final selfLower = selfPath?.toLowerCase();

  bool isFree(String candidate) {
    final lower = candidate.toLowerCase();
    return lower == selfLower || !occupiedLower.contains(lower);
  }

  final prefix = dir.isEmpty ? '' : '$dir/';
  final shortId = key.length > 8 ? key.substring(0, 8) : key;
  for (final candidate in [
    '$prefix$name.$extension',
    '$prefix$name-$shortId.$extension',
    '$prefix$name-$key.$extension',
  ]) {
    if (isFree(candidate)) {
      occupiedLower.add(candidate.toLowerCase());
      return candidate;
    }
  }
  // key 全长仍碰撞：只可能是自身已占用同名路径（isFree 已放行）或输入矛盾。
  throw StateError('无法为 "$title"（$key）分配路径：候选路径全部被占用');
}

/// 本地标题是否要求重命名：与 base 路径的文件名（含短 id 后缀形态）都不一致。
bool _renameWanted(String title, String basePath, String key) {
  final fileName = _posixBasenameWithoutExtension(basePath);
  final expected = sanitizeFileTitle(title);
  if (fileName == expected) return false;
  final shortId = key.length > 8 ? key.substring(0, 8) : key;
  if (fileName == '$expected-$shortId') return false;
  if (fileName == '$expected-$key') return false;
  return true;
}

// 仓库路径永远使用 POSIX 分隔符（§5.3 / 规则 3 跨平台约束）。
String _posixDirname(String path) {
  final i = path.lastIndexOf('/');
  return i == -1 ? '' : path.substring(0, i);
}

String _posixBasenameWithoutExtension(String path) {
  final slash = path.lastIndexOf('/');
  final name = slash == -1 ? path : path.substring(slash + 1);
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}
