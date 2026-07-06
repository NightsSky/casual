// 同步引擎 v2 远端层的真仓库联调脚本（doc/sync-design.md §14 M2 验收）。
//
// 用一个可写的测试仓库验证 RemoteRepo 全链路：
// fetchHead → listTree → 原子/逐文件提交（创建、更新、重命名）→
// fetchBlob 内容往返 → 本地 blob sha 与服务端一致性 → 清理删除。
//
// 用法（在项目根目录）：
//   dart run tool/remote_live_check.dart \
//     --platform github --owner <owner> --repo <repo> --token <token> [--branch main] [--keep]
//
// 注意：请指向专用测试仓库。脚本只在 `.gitnote-live-check/` 目录下读写，
// 结束时默认清理；--keep 保留现场供人工检查。
//
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:casual/data/sync/blob_sha.dart';
import 'package:casual/data/sync/remote/remote_repo.dart';
import 'package:casual/domain/models/git_config.dart';

const _probeDir = '.gitnote-live-check';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  if (options == null) {
    print('用法: dart run tool/remote_live_check.dart '
        '--platform github|gitee --owner O --repo R --token T [--branch main] [--keep]');
    exitCode = 2;
    return;
  }

  final config = GitConfig(
    platform:
        options['platform'] == 'gitee' ? GitPlatform.gitee : GitPlatform.github,
    token: options['token']!,
    owner: options['owner']!,
    repo: options['repo']!,
    branch: options['branch'] ?? 'main',
  );
  final remote = createRemoteRepo(config);
  final stamp = DateTime.now().toIso8601String();
  const pathA = '$_probeDir/联调 a.md';
  const pathB = '$_probeDir/b.md';
  const pathB2 = '$_probeDir/b-重命名.md';
  const contentA1 = '---\nid: livecheck-a\n---\n\n# 联调 A v1\n';
  const contentA2 = '---\nid: livecheck-a\n---\n\n# 联调 A v2（更新）\n';
  final contentB = '联调 B · $stamp\n';

  var failures = 0;
  Future<void> step(String name, Future<void> Function() body) async {
    try {
      await body();
      print('✔ $name');
    } catch (e) {
      failures++;
      print('✘ $name\n  $e');
    }
  }

  String? head;
  await step('① fetchHead', () async {
    head = await remote.fetchHead();
    print('  head = ${head ?? '(空仓库/分支不存在)'}');
  });

  await step('② 提交：创建两个文件（含中文/空格路径）', () async {
    final result = await remote.commitChanges(RemoteCommitRequest(
      message: 'live-check: create ($stamp)',
      expectedHeadSha: head,
      writes: [
        const RemoteWrite(path: pathA, content: contentA1),
        RemoteWrite(path: pathB, content: contentB),
      ],
      deletes: const [],
    ));
    if (!result.allSucceeded) {
      throw StateError('部分失败: ${result.failureMessages}');
    }
  });

  late String headAfterCreate;
  await step('③ head 前进 + 清单可见 + 本地 blob sha 与服务端一致', () async {
    final newHead = await remote.fetchHead();
    if (newHead == null || newHead == head) {
      throw StateError('head 未前进: $newHead');
    }
    headAfterCreate = newHead;
    final tree = await remote.listTree(newHead);
    final a = tree.firstWhere((f) => f.path == pathA,
        orElse: () => throw StateError('清单缺少 $pathA'));
    final localSha = computeBlobSha(contentA1);
    if (a.blobSha != localSha) {
      throw StateError('blob sha 不一致: 服务端 ${a.blobSha} vs 本地 $localSha');
    }
  });

  await step('④ fetchBlob 内容往返（UTF-8）', () async {
    final tree = await remote.listTree(headAfterCreate);
    final a = tree.firstWhere((f) => f.path == pathA);
    final fetched = await remote.fetchBlob(a.blobSha);
    if (fetched != contentA1) {
      throw StateError('内容不一致（长度 ${fetched.length} vs ${contentA1.length}）');
    }
  });

  await step('⑤ 提交：更新 A + 重命名 B（乐观锁凭据）', () async {
    final tree = await remote.listTree(headAfterCreate);
    final aSha = tree.firstWhere((f) => f.path == pathA).blobSha;
    final bSha = tree.firstWhere((f) => f.path == pathB).blobSha;
    final result = await remote.commitChanges(RemoteCommitRequest(
      message: 'live-check: update+rename ($stamp)',
      expectedHeadSha: headAfterCreate,
      writes: [
        RemoteWrite(path: pathA, content: contentA2, remoteBlobSha: aSha),
        RemoteWrite(
          path: pathB2,
          content: contentB,
          deleteOldPath: pathB,
          deleteOldPathSha: bSha,
        ),
      ],
      deletes: const [],
    ));
    if (!result.allSucceeded) {
      throw StateError('部分失败: ${result.failureMessages}');
    }
    final afterHead = await remote.fetchHead();
    final after = await remote.listTree(afterHead!);
    final paths = after.map((f) => f.path).toSet();
    if (!paths.contains(pathB2) || paths.contains(pathB)) {
      throw StateError('重命名未生效: $paths');
    }
    if (after.firstWhere((f) => f.path == pathA).blobSha !=
        computeBlobSha(contentA2)) {
      throw StateError('更新后的 sha 不符');
    }
  });

  if (options.containsKey('keep')) {
    print('… --keep 已指定，保留 $_probeDir/ 现场');
  } else {
    await step('⑥ 清理：删除联调文件', () async {
      final cleanupHead = await remote.fetchHead();
      final tree = await remote.listTree(cleanupHead!);
      final probes =
          tree.where((f) => f.path.startsWith('$_probeDir/')).toList();
      final result = await remote.commitChanges(RemoteCommitRequest(
        message: 'live-check: cleanup ($stamp)',
        expectedHeadSha: cleanupHead,
        writes: const [],
        deletes: [
          for (final f in probes)
            RemoteDelete(path: f.path, remoteBlobSha: f.blobSha),
        ],
      ));
      if (!result.allSucceeded) {
        throw StateError('部分失败: ${result.failureMessages}');
      }
    });
  }

  print(failures == 0 ? '\n全部通过 ✅' : '\n$failures 个步骤失败 ❌');
  exitCode = failures == 0 ? 0 : 1;
}

Map<String, String>? _parseArgs(List<String> args) {
  final map = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) return null;
    final key = arg.substring(2);
    if (key == 'keep') {
      map['keep'] = 'true';
      continue;
    }
    if (i + 1 >= args.length) return null;
    map[key] = args[++i];
  }
  const required = ['platform', 'owner', 'repo', 'token'];
  if (required.any((k) => !map.containsKey(k))) return null;
  return map;
}
