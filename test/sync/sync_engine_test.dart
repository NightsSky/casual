import 'package:casual/data/sync/blob_sha.dart';
import 'package:casual/data/sync/remote/remote_repo.dart';
import 'package:casual/data/sync/sync_base_store.dart';
import 'package:casual/data/sync/sync_engine.dart';
import 'package:casual/data/sync/sync_planner.dart' show RemoteFileState;
import 'package:casual/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// 全内存 fakes
// ---------------------------------------------------------------------------

class FakeNotesPort implements SyncNotesPort {
  FakeNotesPort(this.notes);

  List<Note> notes;
  final rewrites = <String, String>{};
  void Function()? onSnapshot;

  @override
  List<Note> snapshot() {
    onSnapshot?.call();
    return List.of(notes);
  }

  @override
  void applyRemoteUpsert(Note note) {
    final i = notes.indexWhere((n) => n.id == note.id);
    if (i == -1) {
      notes = [...notes, note];
    } else {
      notes = [...notes]..[i] = note;
    }
  }

  @override
  void applyRemoteDelete(String noteId) {
    notes = notes.where((n) => n.id != noteId).toList();
  }

  @override
  void rewriteNoteId(String oldId, String newId) {
    rewrites[oldId] = newId;
    final i = notes.indexWhere((n) => n.id == oldId);
    if (i != -1) notes = [...notes]..[i] = notes[i].copyWith(id: newId);
  }

  @override
  void markPushed(String noteId, String filePath) {
    final i = notes.indexWhere((n) => n.id == noteId);
    if (i == -1) return;
    notes = [...notes]
      ..[i] = notes[i].copyWith(
        filePath: filePath,
        syncStatus: SyncStatus.synced,
        syncedAt: DateTime.now(),
      );
  }

  Note? byId(String id) =>
      notes.cast<Note?>().firstWhere((n) => n!.id == id, orElse: () => null);
}

class FakeBaseStore implements SyncBaseStore {
  List<NoteSyncBase> bases = [];

  @override
  Future<List<NoteSyncBase>> load() async => List.of(bases);

  @override
  Future<void> saveAll(List<NoteSyncBase> value) async {
    bases = List.of(value);
  }

  NoteSyncBase? byKey(String key) =>
      bases.cast<NoteSyncBase?>().firstWhere(
            (b) => b!.key == key,
            orElse: () => null,
          );
}

class FakeRemoteRepo implements RemoteRepo {
  FakeRemoteRepo([Map<String, String>? files]) : files = {...?files} {
    if (this.files.isNotEmpty) _advanceHead();
  }

  Map<String, String> files;
  String? headSha;
  int _commitCount = 0;
  final commitLog = <RemoteCommitRequest>[];

  /// 提交前回调：测试用它模拟"会话期间其他设备推送"。
  void Function()? beforeCommit;

  /// 逐文件模式（Gitee 式）：忽略 head 乐观锁，按 failPaths 记录失败。
  bool perFileMode = false;
  Set<String> failPaths = {};

  /// 冲突取远端提交时间时返回（测试可设定，默认给个固定值）。
  DateTime? lastCommitTime = DateTime.utc(2026, 7, 6, 15, 10);

  void _advanceHead() => headSha = 'head${++_commitCount}';

  /// 模拟其他设备直接改远端。
  void externalWrite(String path, String content) {
    files[path] = content;
    _advanceHead();
  }

  @override
  Future<String?> fetchHead() async => headSha;

  @override
  Future<List<RemoteFileState>> listTree(String headSha) async => [
        for (final e in files.entries)
          RemoteFileState(path: e.key, blobSha: computeBlobSha(e.value)),
      ];

  @override
  Future<String> fetchBlob(String blobSha) async {
    for (final content in files.values) {
      if (computeBlobSha(content) == blobSha) return content;
    }
    throw const RemoteException('blob 不存在');
  }

  @override
  Future<DateTime?> fetchLastCommitTime(String path) async => lastCommitTime;

  @override
  Future<RemoteCommitResult> commitChanges(RemoteCommitRequest request) async {
    if (request.isEmpty) return const RemoteCommitResult();
    beforeCommit?.call();
    beforeCommit = null;
    commitLog.add(request);

    if (!perFileMode && request.expectedHeadSha != headSha) {
      throw const RemoteHeadMovedException('head moved');
    }

    final failedPaths = <String>{};
    final failureMessages = <String, String>{};
    for (final w in request.writes) {
      if (perFileMode && failPaths.contains(w.path)) {
        failedPaths.add(w.path);
        failureMessages[w.path] = 'simulated failure';
        continue;
      }
      files[w.path] = w.content;
      if (w.deleteOldPath != null) files.remove(w.deleteOldPath);
    }
    for (final d in request.deletes) {
      if (perFileMode && failPaths.contains(d.path)) {
        failedPaths.add(d.path);
        failureMessages[d.path] = 'simulated failure';
        continue;
      }
      files.remove(d.path);
    }
    _advanceHead();
    return RemoteCommitResult(
      newHeadSha: perFileMode ? null : headSha,
      failedPaths: failedPaths,
      failureMessages: failureMessages,
    );
  }
}

// ---------------------------------------------------------------------------
// 脚手架
// ---------------------------------------------------------------------------

const _config = GitConfig(
  platform: GitPlatform.github,
  token: 't',
  owner: 'o',
  repo: 'r',
);

({SyncEngine engine, FakeNotesPort port, FakeBaseStore store, FakeRemoteRepo remote})
    _rig({List<Note> notes = const [], Map<String, String>? remoteFiles}) {
  final port = FakeNotesPort(List.of(notes));
  final store = FakeBaseStore();
  final remote = FakeRemoteRepo(remoteFiles);
  final engine = SyncEngine(
    notesPort: port,
    baseStore: store,
    deviceLabel: 'test-device',
    remoteFactory: (_) => remote,
  );
  return (engine: engine, port: port, store: store, remote: remote);
}

Note _md(String id, String title, String content, {String? filePath}) => Note(
      id: id,
      title: title,
      content: content,
      format: NoteFormat.markdown,
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 2),
      filePath: filePath,
      syncStatus:
          filePath == null ? SyncStatus.local : SyncStatus.synced,
    );

void main() {
  group('推送与拉取', () {
    test('本地新建 md → 推送带 front-matter；再次同步无变更（幂等）', () async {
      final r = _rig(notes: [_md('id-aaaa', '会议', '# 正文\n')]);

      final report = await r.engine.sync(_config);
      expect(report.pushed, 1);
      expect(r.remote.files.keys, ['notes/会议.md']);
      final remoteContent = r.remote.files['notes/会议.md']!;
      expect(remoteContent, contains('id: id-aaaa'));
      expect(remoteContent, contains('# 正文'));
      expect(r.port.byId('id-aaaa')!.filePath, 'notes/会议.md');
      expect(r.store.byKey('id-aaaa')!.path, 'notes/会议.md');

      final second = await r.engine.sync(_config);
      expect(second.hasAnyChange, isFalse);
      expect(r.remote.commitLog, hasLength(1), reason: '第二轮不应产生提交');
    });

    test('远端新增（带 id）→ 导入本地', () async {
      final r = _rig(remoteFiles: {
        'notes/远方笔记.md': '---\nid: remote-01\ntags: [work]\n---\n\n远方内容\n',
      });

      final report = await r.engine.sync(_config);
      expect(report.pulled, 1);
      final note = r.port.byId('remote-01')!;
      expect(note.title, '远方笔记');
      expect(note.content, '远方内容\n');
      expect(note.tags, ['work']);
      expect(note.syncStatus, SyncStatus.synced);
      expect(r.store.byKey('remote-01'), isNotNull);
    });

    test('远端无 id 的 md → 导入并在下一轮回写注入 id（收编）', () async {
      final r = _rig(remoteFiles: {'notes/手写.md': '外部工具写的\n'});

      final first = await r.engine.sync(_config);
      expect(first.pulled, 1);
      final note = r.port.notes.single;
      expect(note.id, isNotEmpty);

      final second = await r.engine.sync(_config);
      expect(second.pushed, 1, reason: '注入 front-matter 的内容变化回写远端');
      expect(r.remote.files['notes/手写.md'], contains('id: ${note.id}'));

      final third = await r.engine.sync(_config);
      expect(third.hasAnyChange, isFalse);
    });

    test('txt：推送纯文本，base 以路径为键', () async {
      final r = _rig(notes: [
        Note(
          id: 'txt-note',
          title: '备忘',
          content: '纯文本内容',
          format: NoteFormat.txt,
        ),
      ]);

      final report = await r.engine.sync(_config);
      expect(report.pushed, 1);
      expect(r.remote.files['notes/备忘.txt'], '纯文本内容',
          reason: 'txt 不注入 front-matter');
      expect(r.store.byKey('notes/备忘.txt'), isNotNull);
      expect(r.port.byId('txt-note')!.filePath, 'notes/备忘.txt');
    });
  });

  group('冲突二选一（§7）', () {
    // 建立共识 base 的公共起点：一篇双端一致的笔记。
    Future<({SyncEngine engine, FakeNotesPort port, FakeBaseStore store, FakeRemoteRepo remote})>
        establishedRig() async {
      final r = _rig(notes: [_md('id-m', '文档', '第一段。\n\n中间。\n\n第三段。\n')]);
      await r.engine.sync(_config);
      return r;
    }

    // 让本地与远端都相对 base 改动，触发规则 4 冲突。
    Future<({SyncEngine engine, FakeNotesPort port, FakeBaseStore store, FakeRemoteRepo remote})>
        divergedRig() async {
      final r = await establishedRig();
      const remotePath = 'notes/文档.md';
      r.remote.externalWrite(
        remotePath,
        r.remote.files[remotePath]!.replaceFirst('第一段。', '第一段（远端版）。'),
      );
      r.remote.lastCommitTime = DateTime.utc(2026, 7, 6, 15, 10);
      final note = r.port.byId('id-m')!;
      r.port.applyRemoteUpsert(note.copyWith(
        content: note.content.replaceFirst('第三段。', '第三段（本地版）。'),
        syncStatus: SyncStatus.local,
        updatedAt: DateTime.utc(2026, 7, 6, 14, 32),
      ));
      return r;
    }

    test('双端都改（哪怕不同段落）→ 收集为待裁决冲突，不自动合并、不动本地/base/远端',
        () async {
      final r = await divergedRig();
      const remotePath = 'notes/文档.md';
      final remoteBefore = r.remote.files[remotePath]!;
      final baseBefore = r.store.byKey('id-m')!.content;

      final report = await r.engine.sync(_config);

      expect(report.pendingConflicts, hasLength(1));
      final conflict = report.pendingConflicts.single;
      expect(conflict.noteId, 'id-m');
      expect(conflict.localUpdatedAt, DateTime.utc(2026, 7, 6, 14, 32));
      expect(conflict.remoteUpdatedAt, DateTime.utc(2026, 7, 6, 15, 10));
      // 未裁决前一切不动。
      expect(r.port.byId('id-m')!.content, contains('第三段（本地版）。'));
      expect(r.port.byId('id-m')!.content, isNot(contains('第一段（远端版）。')));
      expect(r.remote.files[remotePath], remoteBefore);
      expect(r.store.byKey('id-m')!.content, baseBefore);
      expect(r.port.notes, hasLength(1), reason: '不生成冲突副本');
    });

    test('保留本地：base←远端 + 本地标脏；下一轮把本地推覆盖远端', () async {
      final r = await divergedRig();
      final report = await r.engine.sync(_config);
      final conflict = report.pendingConflicts.single;

      await r.engine.resolveConflicts(
        [ConflictResolution(conflict: conflict, choice: ConflictChoice.keepLocal)],
      );
      // base 推进到远端版本，本地内容保留并转为待推送。
      expect(r.store.byKey('id-m')!.content, contains('第一段（远端版）。'));
      expect(r.port.byId('id-m')!.content, contains('第三段（本地版）。'));
      expect(r.port.byId('id-m')!.syncStatus, SyncStatus.local);

      final second = await r.engine.sync(_config);
      expect(second.pushed, 1);
      expect(second.pendingConflicts, isEmpty);
      expect(r.remote.files['notes/文档.md'], contains('第三段（本地版）。'));
    });

    test('用远程覆盖：远端内容落地本地 + base←远端；下一轮无变更', () async {
      final r = await divergedRig();
      final report = await r.engine.sync(_config);
      final conflict = report.pendingConflicts.single;

      await r.engine.resolveConflicts(
        [ConflictResolution(conflict: conflict, choice: ConflictChoice.takeRemote)],
      );
      final note = r.port.byId('id-m')!;
      expect(note.content, contains('第一段（远端版）。'));
      expect(note.content, isNot(contains('第三段（本地版）。')));
      expect(note.syncStatus, SyncStatus.synced);

      final second = await r.engine.sync(_config);
      expect(second.hasAnyChange, isFalse);
      expect(second.pendingConflicts, isEmpty);
    });

    test('未裁决（不调 resolveConflicts）→ 下次同步仍再次提示同一冲突', () async {
      final r = await divergedRig();
      final first = await r.engine.sync(_config);
      expect(first.pendingConflicts, hasLength(1));

      // 用户没处理，直接再同步一次。
      final second = await r.engine.sync(_config);
      expect(second.pendingConflicts, hasLength(1),
          reason: '取消/忽略后不落 base，下轮重新提示');
      expect(r.port.notes, hasLength(1));
    });
  });

  group('删除传播', () {
    test('本地删除 → 传播到远端', () async {
      final r = _rig(notes: [_md('id-d', '要删的', '内容\n')]);
      await r.engine.sync(_config);
      expect(r.remote.files, isNotEmpty);

      r.port.applyRemoteDelete('id-d'); // 模拟用户删除（仅本地）
      final report = await r.engine.sync(_config);
      expect(report.deletedRemote, 1);
      expect(r.remote.files, isEmpty);
      expect(r.store.bases, isEmpty);
    });

    test('远端删除 → 传播到本地', () async {
      final r = _rig(notes: [_md('id-d', '被远端删', '内容\n')]);
      await r.engine.sync(_config);

      r.remote.files.clear();
      r.remote.externalWrite('notes/占位.md', '---\nid: other\n---\n\nx\n');
      r.remote.files.remove('notes/占位.md'); // 只为推进 head
      final report = await r.engine.sync(_config);
      expect(report.deletedLocal, 1);
      expect(r.port.byId('id-d'), isNull);
    });

    test('规则 8：本地删 + 远端改 → 恢复到本地并计数提示', () async {
      final r = _rig(notes: [_md('id-r', '文档', '旧内容\n')]);
      await r.engine.sync(_config);

      r.port.applyRemoteDelete('id-r');
      r.remote.externalWrite(
        'notes/文档.md',
        r.remote.files['notes/文档.md']!.replaceFirst('旧内容', '远端新内容'),
      );

      final report = await r.engine.sync(_config);
      expect(report.restored, 1);
      expect(report.deletedRemote, 0);
      final restored = r.port.notes.single;
      expect(restored.content, contains('远端新内容'));
    });
  });

  group('会话健壮性', () {
    test('head 移动 → 自动重试成功，推送不重复计数', () async {
      final r = _rig(notes: [_md('id-h', '笔记', '内容\n')]);
      // 第一次提交前另一设备推了别的文件。
      r.remote.beforeCommit = () {
        r.remote.externalWrite('notes/other.md', '---\nid: zz\n---\n\n他人\n');
      };

      final report = await r.engine.sync(_config);
      expect(report.pushed, 1, reason: '重试轮才成功，计数不翻倍');
      expect(report.pulled, 1, reason: '重试轮拉到了他人的新文件');
      expect(r.remote.files.keys, containsAll(['notes/笔记.md', 'notes/other.md']));
    });

    test('Gitee 逐文件失败：失败项不落 base，下轮重推', () async {
      final r = _rig(notes: [
        _md('id-ok', '好的', 'A\n'),
        _md('id-bad', '坏的', 'B\n'),
      ]);
      r.remote.perFileMode = true;
      r.remote.failPaths = {'notes/坏的.md'};

      final report = await r.engine.sync(_config);
      expect(report.failures, hasLength(1));
      expect(r.store.byKey('id-ok'), isNotNull);
      expect(r.store.byKey('id-bad'), isNull);

      r.remote.failPaths = {};
      final second = await r.engine.sync(_config);
      expect(second.pushed, 1, reason: '失败项下一轮重推');
      expect(r.store.byKey('id-bad'), isNotNull);
    });

    test('会话中用户编辑的笔记本轮跳过推送', () async {
      final r = _rig(notes: [_md('id-e', '编辑中', '规划时内容\n')]);
      var snapshots = 0;
      r.port.onSnapshot = () {
        snapshots++;
        // 规划完成后（第 3 次快照取 latest 前）用户又改了内容。
        if (snapshots == 3) {
          final n = r.port.byId('id-e')!;
          r.port.notes = [
            n.copyWith(content: '会话中新改的\n', updatedAt: DateTime.now()),
          ];
        }
      };

      final report = await r.engine.sync(_config);
      expect(report.pushed, 0, reason: '内容与规划输入不一致，跳过');
      expect(r.remote.files, isEmpty);
      expect(r.store.bases, isEmpty);

      r.port.onSnapshot = null;
      final second = await r.engine.sync(_config);
      expect(second.pushed, 1);
      expect(r.remote.files['notes/编辑中.md'], contains('会话中新改的'));
    });
  });

  group('v1 迁移（合成 base）', () {
    test('老数据：远端无 front-matter → 合成 base + 注入 id 回写，不产生重复笔记', () async {
      // v1 状态：本地笔记 filePath 指向远端纯正文文件，无 base 表。
      final r = _rig(
        notes: [_md('id-v1', '旧笔记', '正文未变\n', filePath: 'notes/旧笔记.md')],
        remoteFiles: {'notes/旧笔记.md': '正文未变\n'},
      );

      final report = await r.engine.sync(_config);
      // 合成 base 后：本地 encode（含 front-matter）≠ base（纯正文）→ 规则 2 推送升级。
      expect(report.pushed, 1);
      expect(report.pulled, 0, reason: '不得把同一篇当远端新增再导入一份');
      expect(r.port.notes, hasLength(1), reason: 'P1 回归：不产生重复笔记');
      expect(r.remote.files['notes/旧笔记.md'], contains('id: id-v1'));

      final second = await r.engine.sync(_config);
      expect(second.hasAnyChange, isFalse);
    });

    test('老数据：远端已被他端注入不同 id → 以远端 id 改写本地', () async {
      final r = _rig(
        notes: [_md('local-id', '共享', '同一份\n', filePath: 'notes/共享.md')],
        remoteFiles: {
          'notes/共享.md': '---\nid: winner-id\n---\n\n同一份\n',
        },
      );

      await r.engine.sync(_config);
      expect(r.port.rewrites['local-id'], 'winner-id');
      expect(r.port.byId('winner-id'), isNotNull);
      expect(r.port.byId('local-id'), isNull);
      expect(r.port.notes, hasLength(1));
      expect(r.store.byKey('winner-id'), isNotNull);
    });
  });
}
