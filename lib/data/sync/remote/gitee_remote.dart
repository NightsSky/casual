import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../domain/models/git_config.dart';
import '../sync_planner.dart' show RemoteFileState;
import 'remote_repo.dart';

/// Gitee 远端实现：逐文件 contents API 降级模式（doc/sync-design.md §8.4/§10）。
///
/// Gitee OpenAPI v5 的 git-data 端点只读（trees/blobs 可查），没有公开的
/// create-tree/create-commit/update-ref，无法原子提交。因此：
/// - 每个文件操作是独立提交，靠 per-file sha 做乐观锁；
/// - 单文件失败只记录到 [RemoteCommitResult.failedPaths]，不中断批次（§8.1）；
/// - 重命名 = 先建新路径、后删旧路径：写入失败则跳过删除，
///   中断时最多残留一个旧文件（残留会在下轮以重复 id 导入为可见的
///   副本笔记，用户可删，绝不丢内容），见 §8.4。
///
/// 认证沿用 Gitee 惯例：access_token 作为 query 参数
/// （与 lib/data/services/gitee_service.dart 一致）。
class GiteeRemote implements RemoteRepo {
  GiteeRemote(this._config, {http.Client? client})
      : _client = client ?? http.Client();

  final GitConfig _config;
  final http.Client _client;

  static const _host = 'gitee.com';

  /// contents 路径含用户可控的文件名（中文、空格、# 等），
  /// 一律用 pathSegments 构造让每段正确转义。
  Uri _uri(List<String> segments, [Map<String, String> query = const {}]) =>
      Uri(
        scheme: 'https',
        host: _host,
        pathSegments: [
          'api',
          'v5',
          'repos',
          _config.owner,
          _config.repo,
          ...segments,
        ],
        queryParameters: {...query, 'access_token': _config.token},
      );

  @override
  Future<String?> fetchHead() async {
    final response =
        await _client.get(_uri(['branches', ..._config.branch.split('/')]));
    if (response.statusCode == 404) return null;
    _ensureOk(response, '获取分支 head');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final commit = data['commit'] as Map<String, dynamic>?;
    return commit?['sha'] as String?;
  }

  @override
  Future<List<RemoteFileState>> listTree(String headSha) async {
    final response =
        await _client.get(_uri(['git', 'trees', headSha], {'recursive': '1'}));
    _ensureOk(response, '获取远端清单');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['truncated'] == true) {
      throw const RemoteListingTruncatedException(
          '远端文件清单超出 API 上限被截断，为防误删已中止同步');
    }
    final entries = (data['tree'] as List).cast<Map<String, dynamic>>();
    return [
      for (final e in entries)
        if (e['type'] == 'blob')
          RemoteFileState(path: e['path'] as String, blobSha: e['sha'] as String),
    ];
  }

  @override
  Future<String> fetchBlob(String blobSha) async {
    final response = await _client.get(_uri(['git', 'blobs', blobSha]));
    _ensureOk(response, '读取文件内容');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['encoding'] == 'base64') {
      final compact = (data['content'] as String).replaceAll(RegExp(r'\s'), '');
      return utf8.decode(base64Decode(compact));
    }
    return data['content'] as String? ?? '';
  }

  @override
  Future<DateTime?> fetchLastCommitTime(String path) async {
    // Gitee v5：GET /repos/{owner}/{repo}/commits?path=&sha=分支&per_page=1。
    // 取 commit.committer.date（服务端时间）。失败不抛，返回 null。
    try {
      final response = await _client.get(_uri(['commits'], {
        'path': path,
        'sha': _config.branch,
        'per_page': '1',
      }));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final data = jsonDecode(response.body);
      if (data is! List || data.isEmpty) return null;
      final commit = (data.first as Map<String, dynamic>)['commit']
          as Map<String, dynamic>?;
      final committer = commit?['committer'] as Map<String, dynamic>?;
      final dateStr = committer?['date'] as String?;
      return dateStr == null ? null : DateTime.tryParse(dateStr)?.toLocal();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<RemoteCommitResult> commitChanges(RemoteCommitRequest request) async {
    if (request.isEmpty) return const RemoteCommitResult();

    final failedPaths = <String>{};
    final failureMessages = <String, String>{};

    void recordFailure(String path, Object error) {
      failedPaths.add(path);
      failureMessages[path] = error is RemoteException
          ? error.toString()
          : '未知错误: $error';
    }

    // 先写后删：任何时刻远端都持有内容，中断只残留旧文件不丢数据。
    for (final write in request.writes) {
      try {
        await _writeFile(write, request.message);
      } catch (e) {
        recordFailure(write.path, e);
        continue; // 写入失败时绝不能删除旧路径（重命名会丢内容）
      }
      final oldPath = write.deleteOldPath;
      if (oldPath != null) {
        try {
          final oldSha = write.deleteOldPathSha;
          if (oldSha == null) {
            throw const RemoteException('缺少旧路径的 sha，无法删除');
          }
          await _deleteFile(oldPath, oldSha, request.message);
        } catch (e) {
          // 新路径已写成功，旧文件残留可下轮清理，只记录不回滚。
          recordFailure(oldPath, e);
        }
      }
    }

    for (final delete in request.deletes) {
      try {
        await _deleteFile(delete.path, delete.remoteBlobSha, request.message);
      } catch (e) {
        recordFailure(delete.path, e);
      }
    }

    return RemoteCommitResult(
      failedPaths: failedPaths,
      failureMessages: failureMessages,
    );
  }

  Future<void> _writeFile(RemoteWrite write, String message) async {
    final uri = _uri(['contents', ...write.path.split('/')]);
    final body = jsonEncode({
      'message': message,
      'content': base64Encode(utf8.encode(write.content)),
      'branch': _config.branch,
      if (write.remoteBlobSha != null) 'sha': write.remoteBlobSha,
    });
    // Gitee 惯例：创建用 POST，更新必须带 sha 用 PUT，
    // 否则服务端按创建处理并报"文件名已存在"。
    final response = write.remoteBlobSha == null
        ? await _client.post(uri, headers: _jsonHeaders, body: body)
        : await _client.put(uri, headers: _jsonHeaders, body: body);
    _ensureOk(response, '写入 ${write.path}');
  }

  Future<void> _deleteFile(String path, String sha, String message) async {
    final response = await _client.delete(
      _uri(['contents', ...path.split('/')]),
      headers: _jsonHeaders,
      body: jsonEncode({
        'message': message,
        'sha': sha,
        'branch': _config.branch,
      }),
    );
    _ensureOk(response, '删除 $path');
  }

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  void _ensureOk(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw RemoteException(
      '$action失败: ${_errorMessage(response)}',
      statusCode: response.statusCode,
    );
  }

  String _errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
    } catch (_) {}
    return 'HTTP ${response.statusCode}';
  }
}
