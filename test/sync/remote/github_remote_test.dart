import 'dart:convert';

import 'package:casual/data/sync/remote/github_remote.dart';
import 'package:casual/data/sync/remote/remote_repo.dart';
import 'package:casual/domain/models/git_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _config = GitConfig(
  platform: GitPlatform.github,
  token: 'tok',
  owner: 'o',
  repo: 'r',
  branch: 'main',
);

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {
      'content-type': 'application/json',
    });

void main() {
  group('GitHubRemote.fetchHead', () {
    test('返回分支 head 的 commit sha，并带 Bearer 认证头', () async {
      late http.Request captured;
      final remote = GitHubRemote(_config, client: MockClient((req) async {
        captured = req;
        return _json({
          'ref': 'refs/heads/main',
          'object': {'sha': 'head123', 'type': 'commit'},
        });
      }));
      expect(await remote.fetchHead(), 'head123');
      expect(captured.url.path, '/repos/o/r/git/ref/heads/main');
      expect(captured.headers['Authorization'], 'Bearer tok');
    });

    test('404（分支不存在）与 409（空仓库）都返回 null', () async {
      for (final status in [404, 409]) {
        final remote = GitHubRemote(_config, client: MockClient((req) async {
          return _json({'message': 'x'}, status);
        }));
        expect(await remote.fetchHead(), isNull, reason: 'HTTP $status');
      }
    });
  });

  group('GitHubRemote.listTree', () {
    test('递归清单只保留 blob 条目', () async {
      late http.Request captured;
      final remote = GitHubRemote(_config, client: MockClient((req) async {
        captured = req;
        return _json({
          'truncated': false,
          'tree': [
            {'path': 'notes', 'type': 'tree', 'sha': 't1'},
            {'path': 'notes/a.md', 'type': 'blob', 'sha': 'b1'},
            {'path': 'notes/b.txt', 'type': 'blob', 'sha': 'b2'},
          ],
        });
      }));
      final files = await remote.listTree('head123');
      expect(captured.url.path, '/repos/o/r/git/trees/head123');
      expect(captured.url.queryParameters['recursive'], '1');
      expect(files.map((f) => f.path), ['notes/a.md', 'notes/b.txt']);
      expect(files.first.blobSha, 'b1');
    });

    test('truncated 清单直接抛异常（防误删红线）', () async {
      final remote = GitHubRemote(_config, client: MockClient((req) async {
        return _json({'truncated': true, 'tree': []});
      }));
      expect(
        () => remote.listTree('head123'),
        throwsA(isA<RemoteListingTruncatedException>()),
      );
    });
  });

  group('GitHubRemote.fetchBlob', () {
    test('解码带换行分隔的 base64（UTF-8 中文）', () async {
      final raw = base64Encode(utf8.encode('# 会议\n正文内容'));
      // 模拟 GitHub 每 60 字符插入换行的返回格式。
      final wrapped = '${raw.substring(0, 8)}\n${raw.substring(8)}\n';
      final remote = GitHubRemote(_config, client: MockClient((req) async {
        expect(req.url.path, '/repos/o/r/git/blobs/blobsha');
        return _json({'content': wrapped, 'encoding': 'base64'});
      }));
      expect(await remote.fetchBlob('blobsha'), '# 会议\n正文内容');
    });
  });

  group('GitHubRemote.commitChanges', () {
    test('空请求不产生任何网络调用', () async {
      final remote = GitHubRemote(_config, client: MockClient((req) async {
        fail('不应发出请求');
      }));
      final result = await remote.commitChanges(const RemoteCommitRequest(
        message: 'm',
        writes: [],
        deletes: [],
      ));
      expect(result.newHeadSha, isNull);
      expect(result.allSucceeded, isTrue);
    });

    test('更新+重命名+删除 → 单提交原子写入，请求序列与 payload 正确', () async {
      final requests = <http.Request>[];
      var blobCount = 0;
      final remote = GitHubRemote(_config, client: MockClient((req) async {
        requests.add(req);
        final path = req.url.path;
        if (req.method == 'GET' && path == '/repos/o/r/git/commits/head1') {
          return _json({
            'sha': 'head1',
            'tree': {'sha': 'basetree'},
          });
        }
        if (req.method == 'POST' && path == '/repos/o/r/git/blobs') {
          blobCount++;
          return _json({'sha': 'blob$blobCount'}, 201);
        }
        if (req.method == 'POST' && path == '/repos/o/r/git/trees') {
          return _json({'sha': 'newtree'}, 201);
        }
        if (req.method == 'POST' && path == '/repos/o/r/git/commits') {
          return _json({'sha': 'newcommit'}, 201);
        }
        if (req.method == 'PATCH' && path == '/repos/o/r/git/refs/heads/main') {
          return _json({
            'object': {'sha': 'newcommit'},
          });
        }
        fail('未预期的请求: ${req.method} $path');
      }));

      final result = await remote.commitChanges(const RemoteCommitRequest(
        message: 'sync: 2 updated, 1 deleted',
        expectedHeadSha: 'head1',
        writes: [
          RemoteWrite(path: 'notes/a.md', content: 'A2', remoteBlobSha: 'oldA'),
          RemoteWrite(
            path: 'notes/新名.md',
            content: 'B2',
            deleteOldPath: 'notes/旧名.md',
            deleteOldPathSha: 'oldB',
          ),
        ],
        deletes: [RemoteDelete(path: 'notes/c.md', remoteBlobSha: 'oldC')],
      ));

      expect(result.newHeadSha, 'newcommit');
      expect(result.allSucceeded, isTrue);

      // 序列：读 head 提交 → 2×blob → tree → commit → ref。
      expect(
        requests.map((r) => '${r.method} ${r.url.path}').toList(),
        [
          'GET /repos/o/r/git/commits/head1',
          'POST /repos/o/r/git/blobs',
          'POST /repos/o/r/git/blobs',
          'POST /repos/o/r/git/trees',
          'POST /repos/o/r/git/commits',
          'PATCH /repos/o/r/git/refs/heads/main',
        ],
      );

      // blob 内容按 base64(UTF-8) 上传。
      final blob1 = jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(blob1['encoding'], 'base64');
      expect(utf8.decode(base64Decode(blob1['content'] as String)), 'A2');

      // tree：base_tree + 写入两条 + 重命名旧路径删除 + 纯删除。
      final tree = jsonDecode(requests[3].body) as Map<String, dynamic>;
      expect(tree['base_tree'], 'basetree');
      final entries = (tree['tree'] as List).cast<Map<String, dynamic>>();
      expect(entries, [
        {'path': 'notes/a.md', 'mode': '100644', 'type': 'blob', 'sha': 'blob1'},
        {'path': 'notes/新名.md', 'mode': '100644', 'type': 'blob', 'sha': 'blob2'},
        {'path': 'notes/旧名.md', 'mode': '100644', 'type': 'blob', 'sha': null},
        {'path': 'notes/c.md', 'mode': '100644', 'type': 'blob', 'sha': null},
      ]);

      // commit：parent = expectedHeadSha。
      final commit = jsonDecode(requests[4].body) as Map<String, dynamic>;
      expect(commit['message'], 'sync: 2 updated, 1 deleted');
      expect(commit['tree'], 'newtree');
      expect(commit['parents'], ['head1']);

      // ref：非强推。
      final ref = jsonDecode(requests[5].body) as Map<String, dynamic>;
      expect(ref['sha'], 'newcommit');
      expect(ref['force'], false);
    });

    test('updateRef 422 → RemoteHeadMovedException（会话级重试信号）', () async {
      final remote = GitHubRemote(_config, client: MockClient((req) async {
        final path = req.url.path;
        if (path == '/repos/o/r/git/commits/head1') {
          return _json({
            'tree': {'sha': 'basetree'},
          });
        }
        if (path == '/repos/o/r/git/blobs') return _json({'sha': 'b'}, 201);
        if (path == '/repos/o/r/git/trees') return _json({'sha': 't'}, 201);
        if (path == '/repos/o/r/git/commits') return _json({'sha': 'c'}, 201);
        if (req.method == 'PATCH') {
          return _json({'message': 'Update is not a fast forward'}, 422);
        }
        fail('未预期的请求: $path');
      }));

      expect(
        () => remote.commitChanges(const RemoteCommitRequest(
          message: 'm',
          expectedHeadSha: 'head1',
          writes: [RemoteWrite(path: 'notes/a.md', content: 'x')],
          deletes: [],
        )),
        throwsA(isA<RemoteHeadMovedException>()),
      );
    });

    test('空仓库首次提交：无 base_tree、无 parent、POST 创建引用', () async {
      final requests = <http.Request>[];
      final remote = GitHubRemote(_config, client: MockClient((req) async {
        requests.add(req);
        final path = req.url.path;
        if (path == '/repos/o/r/git/blobs') return _json({'sha': 'b1'}, 201);
        if (path == '/repos/o/r/git/trees') return _json({'sha': 't1'}, 201);
        if (path == '/repos/o/r/git/commits') return _json({'sha': 'c1'}, 201);
        if (req.method == 'POST' && path == '/repos/o/r/git/refs') {
          return _json({'ref': 'refs/heads/main'}, 201);
        }
        fail('未预期的请求: ${req.method} $path');
      }));

      final result = await remote.commitChanges(const RemoteCommitRequest(
        message: 'first',
        writes: [RemoteWrite(path: 'notes/a.md', content: 'A')],
        deletes: [],
      ));

      expect(result.newHeadSha, 'c1');
      final tree = jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(tree.containsKey('base_tree'), isFalse);
      final commit = jsonDecode(requests[2].body) as Map<String, dynamic>;
      expect(commit['parents'], isEmpty);
      final ref = jsonDecode(requests[3].body) as Map<String, dynamic>;
      expect(ref['ref'], 'refs/heads/main');
    });

    test('空仓库首次提交不允许删除/重命名（程序性防护）', () async {
      final remote = GitHubRemote(_config, client: MockClient((req) async {
        fail('不应发出请求');
      }));
      expect(
        () => remote.commitChanges(const RemoteCommitRequest(
          message: 'm',
          writes: [],
          deletes: [RemoteDelete(path: 'x', remoteBlobSha: 's')],
        )),
        throwsArgumentError,
      );
    });
  });
}
