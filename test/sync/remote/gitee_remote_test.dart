import 'dart:convert';

import 'package:casual/data/sync/remote/gitee_remote.dart';
import 'package:casual/data/sync/remote/remote_repo.dart';
import 'package:casual/domain/models/git_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _config = GitConfig(
  platform: GitPlatform.gitee,
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
  group('GiteeRemote 读端点', () {
    test('fetchHead：branches 端点 + access_token query 认证', () async {
      late http.Request captured;
      final remote = GiteeRemote(_config, client: MockClient((req) async {
        captured = req;
        return _json({
          'name': 'main',
          'commit': {'sha': 'head9'},
        });
      }));
      expect(await remote.fetchHead(), 'head9');
      expect(captured.url.path, '/api/v5/repos/o/r/branches/main');
      expect(captured.url.queryParameters['access_token'], 'tok');
    });

    test('fetchHead：404 返回 null', () async {
      final remote = GiteeRemote(_config, client: MockClient((req) async {
        return _json({'message': 'Not Found'}, 404);
      }));
      expect(await remote.fetchHead(), isNull);
    });

    test('listTree 过滤 blob；truncated 抛异常', () async {
      final remote = GiteeRemote(_config, client: MockClient((req) async {
        expect(req.url.path, '/api/v5/repos/o/r/git/trees/head9');
        return _json({
          'truncated': false,
          'tree': [
            {'path': 'notes', 'type': 'tree', 'sha': 't'},
            {'path': 'notes/a.md', 'type': 'blob', 'sha': 'b1'},
          ],
        });
      }));
      final files = await remote.listTree('head9');
      expect(files.single.path, 'notes/a.md');

      final truncated = GiteeRemote(_config, client: MockClient((req) async {
        return _json({'truncated': true, 'tree': []});
      }));
      expect(
        () => truncated.listTree('head9'),
        throwsA(isA<RemoteListingTruncatedException>()),
      );
    });

    test('fetchBlob 解码 base64', () async {
      final remote = GiteeRemote(_config, client: MockClient((req) async {
        expect(req.url.path, '/api/v5/repos/o/r/git/blobs/sha1');
        return _json({
          'content': base64Encode(utf8.encode('内容')),
          'encoding': 'base64',
        });
      }));
      expect(await remote.fetchBlob('sha1'), '内容');
    });
  });

  group('GiteeRemote.commitChanges（逐文件降级模式）', () {
    test('创建用 POST、更新带 sha 用 PUT、删除带 sha/branch/message', () async {
      final requests = <http.Request>[];
      final remote = GiteeRemote(_config, client: MockClient((req) async {
        requests.add(req);
        return _json({'content': {}, 'commit': {}}, 200);
      }));

      final result = await remote.commitChanges(const RemoteCommitRequest(
        message: 'sync batch',
        writes: [
          RemoteWrite(path: 'notes/new.md', content: 'N'),
          RemoteWrite(path: 'notes/upd.md', content: 'U', remoteBlobSha: 'u1'),
        ],
        deletes: [RemoteDelete(path: 'notes/del.md', remoteBlobSha: 'd1')],
      ));

      expect(result.allSucceeded, isTrue);
      expect(
        requests.map((r) => '${r.method} ${r.url.path}').toList(),
        [
          'POST /api/v5/repos/o/r/contents/notes/new.md',
          'PUT /api/v5/repos/o/r/contents/notes/upd.md',
          'DELETE /api/v5/repos/o/r/contents/notes/del.md',
        ],
      );

      final create = jsonDecode(requests[0].body) as Map<String, dynamic>;
      expect(create.containsKey('sha'), isFalse);
      expect(create['branch'], 'main');
      expect(create['message'], 'sync batch');
      expect(utf8.decode(base64Decode(create['content'] as String)), 'N');

      final update = jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(update['sha'], 'u1');

      final del = jsonDecode(requests[2].body) as Map<String, dynamic>;
      expect(del['sha'], 'd1');
      expect(del['branch'], 'main');
      expect(del['message'], 'sync batch');
    });

    test('重命名：先建新路径成功后才删旧路径', () async {
      final calls = <String>[];
      final remote = GiteeRemote(_config, client: MockClient((req) async {
        calls.add('${req.method} ${Uri.decodeComponent(req.url.path)}');
        return _json({}, 200);
      }));

      await remote.commitChanges(const RemoteCommitRequest(
        message: 'm',
        writes: [
          RemoteWrite(
            path: 'notes/新名.md',
            content: 'X',
            deleteOldPath: 'notes/旧名.md',
            deleteOldPathSha: 'old1',
          ),
        ],
        deletes: [],
      ));

      expect(calls, [
        'POST /api/v5/repos/o/r/contents/notes/新名.md',
        'DELETE /api/v5/repos/o/r/contents/notes/旧名.md',
      ]);
    });

    test('重命名写入失败 → 绝不删除旧路径（防丢内容）', () async {
      final calls = <String>[];
      final remote = GiteeRemote(_config, client: MockClient((req) async {
        calls.add('${req.method} ${Uri.decodeComponent(req.url.path)}');
        return _json({'message': 'file exists'}, 400);
      }));

      final result = await remote.commitChanges(const RemoteCommitRequest(
        message: 'm',
        writes: [
          RemoteWrite(
            path: 'notes/新名.md',
            content: 'X',
            deleteOldPath: 'notes/旧名.md',
            deleteOldPathSha: 'old1',
          ),
        ],
        deletes: [],
      ));

      expect(calls, ['POST /api/v5/repos/o/r/contents/notes/新名.md'],
          reason: '写入失败后不得发出删除请求');
      expect(result.failedPaths, {'notes/新名.md'});
      expect(result.failureMessages['notes/新名.md'], contains('file exists'));
    });

    test('单文件失败不中断批次，逐条记录', () async {
      final remote = GiteeRemote(_config, client: MockClient((req) async {
        if (req.url.path.endsWith('bad.md')) {
          return _json({'message': 'sha mismatch'}, 409);
        }
        return _json({}, 200);
      }));

      final result = await remote.commitChanges(const RemoteCommitRequest(
        message: 'm',
        writes: [],
        deletes: [
          RemoteDelete(path: 'notes/bad.md', remoteBlobSha: 'x'),
          RemoteDelete(path: 'notes/good.md', remoteBlobSha: 'y'),
        ],
      ));

      expect(result.failedPaths, {'notes/bad.md'});
      expect(result.failureMessages['notes/bad.md'], contains('sha mismatch'));
    });

    test('路径特殊字符逐段转义（中文、空格、#）', () async {
      late Uri captured;
      final remote = GiteeRemote(_config, client: MockClient((req) async {
        captured = req.url;
        return _json({}, 200);
      }));

      await remote.commitChanges(const RemoteCommitRequest(
        message: 'm',
        writes: [RemoteWrite(path: 'notes/会议 #1.md', content: 'X')],
        deletes: [],
      ));

      // '#' 若不转义会被解析成 fragment，路径必须含其转义形式。
      expect(captured.path, contains('%23'));
      expect(captured.fragment, isEmpty);
      expect(
        Uri.decodeComponent(captured.path),
        '/api/v5/repos/o/r/contents/notes/会议 #1.md',
      );
    });

    test('重命名缺少旧路径 sha → 写入成功但删除记为失败', () async {
      final calls = <String>[];
      final remote = GiteeRemote(_config, client: MockClient((req) async {
        calls.add(req.method);
        return _json({}, 200);
      }));

      final result = await remote.commitChanges(const RemoteCommitRequest(
        message: 'm',
        writes: [
          RemoteWrite(
            path: 'notes/新名.md',
            content: 'X',
            deleteOldPath: 'notes/旧名.md',
          ),
        ],
        deletes: [],
      ));

      expect(calls, ['POST'], reason: '没有 sha 不发删除请求');
      expect(result.failedPaths, {'notes/旧名.md'});
    });
  });
}
