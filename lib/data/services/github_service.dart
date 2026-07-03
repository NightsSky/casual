import 'dart:convert';

import 'package:http/http.dart' as http;

class GitHubService {
  static const _baseUrl = 'https://api.github.com';

  static String _api(String path) => '$_baseUrl$path';

  String _encodeBase64(String content) => base64Encode(utf8.encode(content));

  String _decodeBase64(String base64) => utf8.decode(base64Decode(base64));

  Future<bool> testConnection(String token) async {
    final response = await http.get(
      Uri.parse(_api('/user')),
      headers: _headers(token),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['login'] != null;
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> listFiles({
    required String owner,
    required String repo,
    required String branch,
    required String token,
    String path = '',
  }) async {
    final url = _api('/repos/$owner/$repo/contents/$path?ref=$branch');
    final response = await http.get(Uri.parse(url), headers: _headers(token));

    if (response.statusCode != 200) {
      throw Exception('获取文件列表失败: ${response.statusCode}');
    }

    final dynamic data = jsonDecode(response.body);

    if (data is! List) return [Map<String, dynamic>.from(data)];

    final files = <Map<String, dynamic>>[];
    for (final item in data) {
      final itemMap = Map<String, dynamic>.from(item);
      if (itemMap['type'] == 'file') {
        files.add(itemMap);
      } else if (itemMap['type'] == 'dir') {
        final subFiles = await listFiles(
          owner: owner,
          repo: repo,
          branch: branch,
          token: token,
          path: itemMap['path'],
        );
        files.addAll(subFiles);
      }
    }
    return files;
  }

  Future<String> getFileContent({
    required String owner,
    required String repo,
    required String path,
    required String token,
    required String branch,
  }) async {
    final url = _api('/repos/$owner/$repo/contents/$path?ref=$branch');
    final response = await http.get(Uri.parse(url), headers: _headers(token));

    if (response.statusCode != 200) {
      throw Exception('获取文件内容失败: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    if (data is List) {
      throw Exception('$path 是一个目录，不是文件');
    }

    if (data['encoding'] == 'base64') {
      return _decodeBase64(data['content']);
    }

    return data['content'] ?? '';
  }

  Future<Map<String, dynamic>> createOrUpdateFile({
    required String owner,
    required String repo,
    required String path,
    required String content,
    required String message,
    required String token,
    required String branch,
    String? sha,
  }) async {
    final url = _api('/repos/$owner/$repo/contents/$path');
    final body = <String, dynamic>{
      'message': message,
      'content': _encodeBase64(content),
      'branch': branch,
    };

    if (sha != null) body['sha'] = sha;

    final response = await http.put(
      Uri.parse(url),
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }

    final error = jsonDecode(response.body);
    throw Exception(
        error['message'] ?? 'GitHub API Error: ${response.statusCode}');
  }

  /// 查询远程文件当前的 sha，返回 null 表示文件不存在。
  Future<String?> getFileSha({
    required String owner,
    required String repo,
    required String path,
    required String token,
    required String branch,
  }) async {
    final url = _api('/repos/$owner/$repo/contents/$path?ref=$branch');
    final response = await http.get(Uri.parse(url), headers: _headers(token));

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('获取文件信息失败: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data is List) return null;
    return data['sha'] as String?;
  }

  Future<void> deleteFile({
    required String owner,
    required String repo,
    required String path,
    required String token,
    required String branch,
    required String sha,
  }) async {
    final url = _api('/repos/$owner/$repo/contents/$path');
    final response = await http.delete(
      Uri.parse(url),
      headers: _headers(token),
      body: jsonEncode({
        'message': 'Delete note: $path',
        'sha': sha,
        'branch': branch,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? '删除失败: ${response.statusCode}');
    }
  }

  Map<String, String> _headers(String token) => {
        'Accept': 'application/vnd.github.v3+json',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
}
