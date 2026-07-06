import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../domain/models/git_config.dart';
import '../sync_planner.dart' show RemoteFileState;
import 'remote_repo.dart';

/// GitHub 远端实现：Git Data API 组装单提交原子写入（doc/sync-design.md §8.4）。
///
/// 提交流程：blobs → tree（base_tree = head 的 tree，删除项 sha 置 null，
/// 重命名 = 旧路径 null + 新路径 blob）→ commit（parent = expectedHeadSha）→
/// updateRef（force: false）。updateRef 被拒即仓库级乐观锁失败，
/// 抛 [RemoteHeadMovedException] 交引擎重试整个会话。
///
/// 全部端点以 sha 或引用名寻址，路径只出现在请求体中，
/// 因此文件名的特殊字符无需拼 URL（对比 contents API）。
class GitHubRemote implements RemoteRepo {
  GitHubRemote(this._config, {http.Client? client})
      : _client = client ?? http.Client();

  final GitConfig _config;
  final http.Client _client;

  static const _host = 'api.github.com';

  Map<String, String> get _headers => {
        'Accept': 'application/vnd.github.v3+json',
        'Authorization': 'Bearer ${_config.token}',
        'Content-Type': 'application/json',
      };

  Uri _uri(List<String> segments, [Map<String, String>? query]) => Uri(
        scheme: 'https',
        host: _host,
        pathSegments: ['repos', _config.owner, _config.repo, ...segments],
        queryParameters: query,
      );

  /// 分支名可能含 '/'（如 feature/x），按段拆入路径。
  List<String> get _branchSegments => _config.branch.split('/');

  @override
  Future<String?> fetchHead() async {
    final response = await _client.get(
      _uri(['git', 'ref', 'heads', ..._branchSegments]),
      headers: _headers,
    );
    // 404 = 分支不存在；409 = 空仓库（无任何提交）。
    if (response.statusCode == 404 || response.statusCode == 409) return null;
    _ensureOk(response, '获取分支 head');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['object'] as Map<String, dynamic>)['sha'] as String;
  }

  @override
  Future<List<RemoteFileState>> listTree(String headSha) async {
    // trees 端点接受 commit sha（服务端自动解引用到其根 tree）。
    final response = await _client.get(
      _uri(['git', 'trees', headSha], {'recursive': '1'}),
      headers: _headers,
    );
    _ensureOk(response, '获取远端清单');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['truncated'] == true) {
      // 清单被截断时继续规划会把"未列出"误判为"远端已删除"，必须中止。
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
    final response = await _client.get(
      _uri(['git', 'blobs', blobSha]),
      headers: _headers,
    );
    _ensureOk(response, '读取文件内容');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['encoding'] == 'base64') {
      // GitHub 返回的 base64 带换行分隔，需去除全部空白再解码。
      final compact = (data['content'] as String).replaceAll(RegExp(r'\s'), '');
      return utf8.decode(base64Decode(compact));
    }
    return data['content'] as String? ?? '';
  }

  @override
  Future<DateTime?> fetchLastCommitTime(String path) async {
    // 该路径最新一次提交的 committer date（服务端时间）。失败不抛，返回 null。
    try {
      final response = await _client.get(
        _uri(['commits'], {
          'path': path,
          'sha': _config.branch,
          'per_page': '1',
        }),
        headers: _headers,
      );
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

    final headSha = request.expectedHeadSha;
    final hasDeletes = request.deletes.isNotEmpty ||
        request.writes.any((w) => w.deleteOldPath != null);
    if (headSha == null && hasDeletes) {
      throw ArgumentError('空仓库的首次提交不可能包含删除/重命名操作');
    }

    // ① base tree：head 提交的根 tree sha（删除项以 base_tree 为基准做差量）。
    String? baseTreeSha;
    if (headSha != null) {
      final commitResp = await _client.get(
        _uri(['git', 'commits', headSha]),
        headers: _headers,
      );
      _ensureOk(commitResp, '读取 head 提交');
      final commit = jsonDecode(commitResp.body) as Map<String, dynamic>;
      baseTreeSha = (commit['tree'] as Map<String, dynamic>)['sha'] as String;
    }

    // ② 上传 blob（幂等：相同内容得到相同 sha）。
    final treeEntries = <Map<String, dynamic>>[];
    for (final write in request.writes) {
      final blobResp = await _client.post(
        _uri(['git', 'blobs']),
        headers: _headers,
        body: jsonEncode({
          'content': base64Encode(utf8.encode(write.content)),
          'encoding': 'base64',
        }),
      );
      _ensureOk(blobResp, '上传 ${write.path}');
      final blobSha =
          (jsonDecode(blobResp.body) as Map<String, dynamic>)['sha'] as String;
      treeEntries.add({
        'path': write.path,
        'mode': '100644',
        'type': 'blob',
        'sha': blobSha,
      });
      if (write.deleteOldPath != null) {
        treeEntries.add({
          'path': write.deleteOldPath,
          'mode': '100644',
          'type': 'blob',
          'sha': null, // sha 为 null = 从 base_tree 中移除该路径
        });
      }
    }
    for (final delete in request.deletes) {
      treeEntries.add({
        'path': delete.path,
        'mode': '100644',
        'type': 'blob',
        'sha': null,
      });
    }

    // ③ 创建 tree。
    final treeResp = await _client.post(
      _uri(['git', 'trees']),
      headers: _headers,
      body: jsonEncode({
        if (baseTreeSha != null) 'base_tree': baseTreeSha,
        'tree': treeEntries,
      }),
    );
    _ensureOk(treeResp, '创建目录树');
    final newTreeSha =
        (jsonDecode(treeResp.body) as Map<String, dynamic>)['sha'] as String;

    // ④ 创建提交。
    final commitResp = await _client.post(
      _uri(['git', 'commits']),
      headers: _headers,
      body: jsonEncode({
        'message': request.message,
        'tree': newTreeSha,
        'parents': [if (headSha != null) headSha],
      }),
    );
    _ensureOk(commitResp, '创建提交');
    final newCommitSha =
        (jsonDecode(commitResp.body) as Map<String, dynamic>)['sha'] as String;

    // ⑤ 推进分支引用（仓库级乐观锁）。
    if (headSha != null) {
      final refResp = await _client.patch(
        _uri(['git', 'refs', 'heads', ..._branchSegments]),
        headers: _headers,
        body: jsonEncode({'sha': newCommitSha, 'force': false}),
      );
      if (refResp.statusCode == 422 || refResp.statusCode == 409) {
        throw RemoteHeadMovedException(
          '推送期间远端分支已被其他设备更新',
          statusCode: refResp.statusCode,
        );
      }
      _ensureOk(refResp, '推进分支引用');
    } else {
      // 空仓库/分支不存在：创建分支引用。
      final refResp = await _client.post(
        _uri(['git', 'refs']),
        headers: _headers,
        body: jsonEncode({
          'ref': 'refs/heads/${_config.branch}',
          'sha': newCommitSha,
        }),
      );
      if (refResp.statusCode == 422 || refResp.statusCode == 409) {
        // 分支被并发创建，同样视为 head 移动交由会话重试。
        throw RemoteHeadMovedException(
          '推送期间分支已被其他设备创建',
          statusCode: refResp.statusCode,
        );
      }
      _ensureOk(refResp, '创建分支引用');
    }

    return RemoteCommitResult(newHeadSha: newCommitSha);
  }

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
