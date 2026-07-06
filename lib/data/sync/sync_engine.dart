/// 同步会话引擎（doc/sync-design.md §8.1 会话时序）。
///
/// 一次 [SyncEngine.sync] = 一个完整会话：
/// ① fetchHead → ② listTree（notesDir 前缀 + .md/.txt 过滤）→
/// ③ 判定（sync_planner）→ ④ 按需下载 → ⑤ 本地落盘（无冲突项）→
/// ⑥ 远端提交（GitHub 原子 / Gitee 逐文件）→ ⑦ head 移动重试（≤3）→
/// ⑧ 更新 base 表。
///
/// 冲突（规则 4：本地与远端都改过）不在会话内自动处置——引擎取远端
/// 最后提交时间、把该篇收集进 [SyncReport.conflicts]，本地/base/远端
/// 三方均不动，交由 UI 层逐篇二选一（§7）。用户裁决后调
/// [SyncEngine.resolveConflict] 纯本地落地，下轮同步自然推送。
///
/// v1 老数据的迁移（§12）被吸收为会话内的"合成 base"步骤：
/// 笔记带 filePath 但没有 base 记录时，以远端当前版本为共识合成 base
/// （远端文件已有不同 id 时以远端 id 为准改写本地）。逐笔记幂等，
/// 无需独立迁移会话或版本标记。
///
/// 并发保证：
/// - 进程内互斥，进行中再调 sync 返回 skipped 报告；
/// - 落盘/推送前对每篇做二次校验，会话期间被用户改动的笔记跳过本轮；
/// - 引擎只应在主窗口运行（多窗口不变量，§11.3）。
library;

import '../../domain/models/git_config.dart';
import '../../domain/models/note.dart';
import '../../domain/models/note_sync_base.dart';
import '../../utils/markdown_utils.dart' show generateId;
import 'blob_sha.dart';
import 'note_file_codec.dart';
import 'remote/remote_repo.dart';
import 'sync_base_store.dart';
import 'sync_planner.dart';

/// 冲突副本携带的标签（§7.2），UI 据此过滤/角标。
const kConflictTag = 'conflict';

/// base 表条目（含 syncedAt）转判定器输入（仅需身份四元组）。
extension _NoteSyncBaseToEntry on NoteSyncBase {
  BaseEntry toBaseEntry() => BaseEntry(
        key: key,
        path: path,
        blobSha: blobSha,
        content: content,
      );
}

/// 引擎对本地笔记状态的读写口，由状态层（NotesNotifier）实现。
/// 所有变更必须经内存状态权威流入 UI 与持久化，引擎不得直写存储
/// （多窗口架构不变量，见 doc/data-flow.md 独立窗口章节）。
abstract interface class SyncNotesPort {
  /// 当前全部笔记快照。
  List<Note> snapshot();

  /// 按 note.id 覆盖或新增（远端权威内容落盘，调用方已置好 synced 态）。
  void applyRemoteUpsert(Note note);

  /// 远端删除传播到本地。
  void applyRemoteDelete(String noteId);

  /// 迁移对齐：远端文件已带不同 id 时，以远端 id 为准改写本地笔记 id
  /// （先迁移者胜，§12）。
  void rewriteNoteId(String oldId, String newId);

  /// 推送成功回写：filePath + synced 状态。
  void markPushed(String noteId, String filePath);
}

/// 一篇笔记的同步冲突（判定表规则 4：本地与远端都相对 base 改动）。
///
/// 引擎在会话中检测到冲突时，**不自动合并、不覆盖任何一方**，而是把
/// 冲突连同双方最后更新时间收集起来交回 UI（doc/sync-design.md §7）。
/// base/local/remote 三份全文都随会话下载完成，裁决时无需再请求网络。
class SyncConflict {
  const SyncConflict({
    required this.key,
    required this.noteId,
    required this.title,
    required this.path,
    required this.remoteContent,
    required this.remoteBlobSha,
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
    this.oldPath,
  });

  /// 判定身份键（md=note.id；txt=路径），裁决时定位 base/笔记。
  final String key;

  /// 本地笔记 id（用于回写）。
  final String noteId;

  /// 展示用标题（取本地当前标题）。
  final String title;

  /// 远端文件路径（"用远程覆盖"落点）。
  final String path;

  /// 路径变化时的旧路径（本地重命名后又冲突时清理旧远端路径）。
  final String? oldPath;

  /// 远端版本全文（"用远程覆盖"时落地内容）。
  final String remoteContent;

  final String remoteBlobSha;

  /// 本地最后编辑时间（展示用，来自 Note.updatedAt）。
  final DateTime localUpdatedAt;

  /// 远端最后提交时间（展示用，服务端 committer date；取不到为 null）。
  final DateTime? remoteUpdatedAt;
}

/// 用户对某篇冲突的裁决。
enum ConflictChoice {
  /// 保留本地：本地内容不动、标记待推送，base ← 远端（下轮推送覆盖远端）。
  keepLocal,

  /// 用远程覆盖：远端内容落地本地，base ← 远端。
  takeRemote,
}

/// 一篇冲突的裁决结果（UI 逐篇收集后回传引擎落地）。
class ConflictResolution {
  const ConflictResolution({required this.conflict, required this.choice});

  final SyncConflict conflict;
  final ConflictChoice choice;
}

/// 一次同步会话的结果摘要。
class SyncReport {
  SyncReport({
    this.skipped = false,
    this.pushed = 0,
    this.pulled = 0,
    this.deletedLocal = 0,
    this.deletedRemote = 0,
    this.restored = 0,
    this.failures = const [],
    this.pendingConflicts = const [],
  });

  /// true = 已有会话进行中，本次未执行。
  final bool skipped;

  final int pushed;
  final int pulled;
  final int deletedLocal;
  final int deletedRemote;

  /// 规则 7/8 触发的恢复次数（删除让位于修改，需向用户提示）。
  final int restored;

  /// 逐文件失败明细（Gitee 降级模式）。
  final List<String> failures;

  /// 待用户裁决的冲突（规则 4）。会话本身不处理，交 UI 逐篇二选一，
  /// 用户选择后调 [SyncEngine.resolveConflicts] 落地（§7.2）。
  final List<SyncConflict> pendingConflicts;

  bool get hasAnyChange =>
      pushed + pulled + deletedLocal + deletedRemote > 0;

  /// 同步日志摘要。
  String summary() {
    if (skipped) return '已有同步进行中，本次跳过';
    final parts = <String>[
      if (pushed > 0) '推送 $pushed',
      if (pulled > 0) '拉取 $pulled',
      if (deletedLocal > 0) '本地删除 $deletedLocal',
      if (deletedRemote > 0) '远端删除 $deletedRemote',
      if (restored > 0) '恢复 $restored',
      if (pendingConflicts.isNotEmpty) '待解决冲突 ${pendingConflicts.length}',
      if (failures.isNotEmpty) '失败 ${failures.length}',
    ];
    return parts.isEmpty ? '已是最新，无变更' : parts.join(' · ');
  }
}

class SyncEngine {
  SyncEngine({
    required this.notesPort,
    required this.baseStore,
    required this.deviceLabel,
    RemoteRepo Function(GitConfig config)? remoteFactory,
  }) : _remoteFactory = remoteFactory ?? ((c) => createRemoteRepo(c));

  final SyncNotesPort notesPort;
  final SyncBaseStore baseStore;
  final String deviceLabel;
  final RemoteRepo Function(GitConfig config) _remoteFactory;

  static const _maxHeadMovedRetries = 3;

  bool _running = false;

  Future<SyncReport> sync(GitConfig config) async {
    if (_running) return SyncReport(skipped: true);
    _running = true;
    try {
      return await _sessionWithRetry(config);
    } finally {
      _running = false;
    }
  }

  Future<SyncReport> _sessionWithRetry(GitConfig config) async {
    final remote = _remoteFactory(config);
    // 会话级累计：head 移动重试时，本地已生效的动作（拉取/本地删除/冲突
    // 收集）不会在下一轮重现（重判为规则 1），必须跨 attempt 累计；
    // 推送类在提交失败后会被下一轮重新规划，只计成功那轮的。
    final acc = _Counters();
    for (var attempt = 0; attempt < _maxHeadMovedRetries; attempt++) {
      final c = _Counters();
      try {
        await _attempt(remote, config, c);
        acc.absorb(c, localOnly: false);
        return acc.toReport();
      } on RemoteHeadMovedException {
        acc.absorb(c, localOnly: true);
        continue;
      }
    }
    throw const RemoteException('远端持续有新提交，多次重试未完成，请稍后再试');
  }

  /// 落地用户对冲突的逐篇裁决（doc/sync-design.md §7.2）。**纯本地操作**，
  /// 不触网：保留本地 → base ← 远端 + 本地标脏（下次同步推送覆盖远端）；
  /// 用远程覆盖 → 远端内容落地本地 + base ← 远端。落地后立即保存 base 表。
  /// 返回后调用方应触发一次新同步，把"保留本地"的改动推上去。
  Future<void> resolveConflicts(List<ConflictResolution> resolutions) async {
    if (resolutions.isEmpty) return;
    final baseByKey = <String, NoteSyncBase>{
      for (final b in await baseStore.load()) b.key: b,
    };
    final now = DateTime.now();
    final byId = {for (final n in notesPort.snapshot()) n.id: n};

    for (final r in resolutions) {
      final conflict = r.conflict;
      final note = byId[conflict.noteId];
      if (note == null) continue; // 会话后被删，跳过

      // 无论哪种选择，base 都推进到远端版本：这是双方新的共识锚点。
      baseByKey[conflict.key] = NoteSyncBase(
        key: conflict.key,
        path: conflict.path,
        blobSha: conflict.remoteBlobSha,
        content: conflict.remoteContent,
        syncedAt: now,
      );

      switch (r.choice) {
        case ConflictChoice.keepLocal:
          // 本地内容不动，仅置为待推送；下次同步 base(=远端) ≠ 本地 → 规则 2 推送。
          notesPort.applyRemoteUpsert(note.copyWith(
            syncStatus: SyncStatus.local,
            filePath: conflict.path,
            updatedAt: now,
          ));
        case ConflictChoice.takeRemote:
          final decoded = decodeNoteFile(conflict.path, conflict.remoteContent);
          notesPort.applyRemoteUpsert(note.copyWith(
            title: decoded.title,
            content: decoded.body,
            tags: decoded.tags,
            category: decoded.category ?? note.category,
            updatedAt: decoded.updated ?? now,
            syncedAt: now,
            syncStatus: SyncStatus.synced,
            filePath: conflict.path,
            sha: conflict.remoteBlobSha,
          ));
      }
    }
    await baseStore.saveAll(baseByKey.values.toList());
  }

  Future<void> _attempt(
    RemoteRepo remote,
    GitConfig config,
    _Counters c,
  ) async {
    // ① / ② 远端状态。
    final head = await remote.fetchHead();
    final remoteFiles = head == null
        ? <RemoteFileState>[]
        : (await remote.listTree(head))
            .where((f) => _isNoteFile(f.path, config.notesDir))
            .toList();
    final shaByPath = {for (final f in remoteFiles) f.path: f.blobSha};

    final baseByKey = <String, NoteSyncBase>{
      for (final b in await baseStore.load()) b.key: b,
    };

    final downloads = <String, DownloadedRemoteFile>{};
    Future<DownloadedRemoteFile> download(String path) async {
      final content = await remote.fetchBlob(shaByPath[path]!);
      final id = path.toLowerCase().endsWith('.md')
          ? decodeNoteFile(path, content).id
          : null;
      return DownloadedRemoteFile(
          path: path, content: content, frontMatterId: id);
    }

    try {
      // —— v1 老数据合成 base（§12 迁移吸收，逐笔记幂等）——
      for (final note in notesPort.snapshot()) {
        final fp = note.filePath;
        if (fp == null || fp.isEmpty || !shaByPath.containsKey(fp)) continue;
        var key = note.format == NoteFormat.txt ? fp : note.id;
        if (baseByKey.containsKey(key)) continue;

        final dl = downloads[fp] ??= await download(fp);
        if (note.format == NoteFormat.markdown) {
          final remoteId = dl.frontMatterId;
          if (remoteId != null && remoteId != note.id) {
            notesPort.rewriteNoteId(note.id, remoteId);
            key = remoteId;
            if (baseByKey.containsKey(key)) continue;
          }
        }
        baseByKey[key] = NoteSyncBase(
          key: key,
          path: fp,
          blobSha: shaByPath[fp]!,
          content: dl.content,
          syncedAt: DateTime.now(),
        );
      }

      // —— ③ 构造判定输入（id 改写后重新快照）——
      final notes = notesPort.snapshot();
      final noteByKey = <String, Note>{};
      final locals = <LocalFileState>[];
      for (final note in notes) {
        final key = _syncKey(note);
        final base = baseByKey[key];
        locals.add(LocalFileState(
          key: key,
          path: base?.path,
          title: note.title,
          extension: note.format == NoteFormat.txt ? 'txt' : 'md',
          content: encodeNoteFile(note, template: base?.content),
        ));
        noteByKey[key] = note;
      }

      final baseEntries = [
        for (final b in baseByKey.values) b.toBaseEntry(),
      ];
      var plan = planSync(
        locals: locals,
        bases: baseEntries,
        remoteFiles: remoteFiles,
        notesDir: config.notesDir,
        downloads: downloads,
      );
      // ④ 按需下载后重判（协议上至多两轮，防御性设上限）。
      var guard = 0;
      while (plan.needsDownload.isNotEmpty && guard++ < 5) {
        for (final path in plan.needsDownload) {
          downloads[path] ??= await download(path);
        }
        plan = planSync(
          locals: locals,
          bases: baseEntries,
          remoteFiles: remoteFiles,
          notesDir: config.notesDir,
          downloads: downloads,
        );
      }
      if (plan.needsDownload.isNotEmpty) {
        throw const RemoteException('远端内容下载不完整，已中止本轮同步');
      }

      // —— ⑤/⑥ 执行计划 ——
      final latestById = {for (final n in notesPort.snapshot()) n.id: n};
      final writes = <RemoteWrite>[];
      final deletes = <RemoteDelete>[];
      // 提交成功后才生效的 base 变更与回写（value null = 删除该 key）。
      final pendingBase = <String, NoteSyncBase?>{};
      final pendingPushed = <String, String>{}; // noteId → filePath
      final writeKeyByPath = <String, String>{}; // 提交失败回滚用
      // 规则 4 冲突：暂存 action，循环后统一取远端时间构造 SyncConflict。
      final mergeConflicts = <MergeAction>[];

      for (final action in plan.actions) {
        switch (action) {
          case PushAction():
            final note = noteByKey[action.key];
            if (note == null) continue;
            final latest = latestById[note.id];
            if (latest == null) continue; // 会话中被删，下轮按规则 5 传播
            final base = baseByKey[action.key];
            if (encodeNoteFile(latest, template: base?.content) !=
                action.content) {
              continue; // 会话中被编辑，下轮重判
            }
            writes.add(RemoteWrite(
              path: action.path,
              content: action.content,
              remoteBlobSha:
                  action.oldPath == null ? action.remoteBlobSha : null,
              deleteOldPath: action.oldPath,
              deleteOldPathSha:
                  action.oldPath == null ? null : action.remoteBlobSha,
            ));
            final baseKey = _baseKeyForPush(note, action);
            writeKeyByPath[action.path] = baseKey;
            pendingBase[baseKey] = NoteSyncBase(
              key: baseKey,
              path: action.path,
              blobSha: computeBlobSha(action.content),
              content: action.content,
              syncedAt: DateTime.now(),
            );
            if (baseKey != action.key) baseByKey.remove(action.key);
            pendingPushed[note.id] = action.path;
            c.pushed++;
            // 规则 7 的重建对用户的提示在 M4 冲突体验中按条目呈现，
            // 报告层面计入 pushed。

          case PullAction():
            _applyPull(action, noteByKey, latestById, baseByKey, c);

          case MergeAction():
            // v2 二选一：不自动合并、不覆盖任一方，暂存冲突，循环后统一取
            // 远端时间构造 SyncConflict 交回 UI 裁决（doc/sync-design.md §7）。
            // 会话中又被用户编辑的跳过本轮（规划输入已过期，下轮重判）。
            final note = noteByKey[action.key];
            final latest = note == null ? null : latestById[note.id];
            if (latest != null &&
                encodeNoteFile(latest, template: baseByKey[action.key]?.content) ==
                    action.localContent) {
              mergeConflicts.add(action);
            }

          case DeleteLocalAction():
            final note = noteByKey[action.key];
            if (note != null) {
              final latest = latestById[note.id];
              final base = baseByKey[action.key];
              // 会话中被编辑的不删（等价规则 8 的保守立场），下轮重判。
              if (latest != null &&
                  base != null &&
                  encodeNoteFile(latest, template: base.content) !=
                      base.content) {
                continue;
              }
              if (latest != null) notesPort.applyRemoteDelete(note.id);
            }
            baseByKey.remove(action.key);
            c.deletedLocal++;

          case DeleteRemoteAction():
            deletes.add(RemoteDelete(
              path: action.path,
              remoteBlobSha: action.remoteBlobSha,
            ));
            writeKeyByPath[action.path] = action.key;
            pendingBase[action.key] = null;
            c.deletedRemote++;

          case AdoptBaseAction():
            baseByKey[action.key] = NoteSyncBase(
              key: action.key,
              path: action.path,
              blobSha: action.blobSha,
              content: action.content,
              syncedAt: DateTime.now(),
            );
            final note = noteByKey[action.key];
            if (note != null) notesPort.markPushed(note.id, action.path);

          case ForgetBaseAction():
            baseByKey.remove(action.key);
        }
      }

      // —— ⑥ 远端提交 ——
      if (writes.isNotEmpty || deletes.isNotEmpty) {
        final result = await remote.commitChanges(RemoteCommitRequest(
          message: _commitMessage(c),
          expectedHeadSha: head,
          writes: writes,
          deletes: deletes,
        ));
        for (final failedPath in result.failedPaths) {
          final key = writeKeyByPath[failedPath];
          if (key == null) continue; // 重命名旧路径删除失败：残留下轮清理
          pendingBase.remove(key);
          pendingPushed.removeWhere(
              (_, path) => path == failedPath);
          c.failures.add(
              '$failedPath: ${result.failureMessages[failedPath] ?? '未知错误'}');
        }
      }
      for (final entry in pendingBase.entries) {
        if (entry.value == null) {
          baseByKey.remove(entry.key);
        } else {
          baseByKey[entry.key] = entry.value!;
        }
      }
      for (final entry in pendingPushed.entries) {
        notesPort.markPushed(entry.key, entry.value);
      }

      // —— 冲突收集（规则 4）：不动本地/base，仅取远端时间构造待裁决项 ——
      // 会话中又被用户编辑的冲突项跳过本轮（规划输入已过期，下轮重判）。
      for (final action in mergeConflicts) {
        final note = noteByKey[action.key];
        if (note == null) continue;
        final latest = latestById[note.id];
        if (latest == null) continue; // 会话中被删，下轮重判
        if (encodeNoteFile(latest, template: baseByKey[action.key]?.content) !=
            action.localContent) {
          continue; // 会话中被编辑，下轮重判
        }
        DateTime? remoteTime;
        try {
          remoteTime = await remote.fetchLastCommitTime(action.path);
        } catch (_) {
          // 取时间失败不阻塞冲突裁决，弹窗上远端时间显示为未知。
          remoteTime = null;
        }
        c.conflicts.add(SyncConflict(
          key: action.key,
          noteId: note.id,
          title: latest.title,
          path: action.path,
          oldPath: action.oldPath,
          remoteContent: action.remoteContent,
          remoteBlobSha: action.remoteBlobSha,
          localUpdatedAt: latest.updatedAt,
          remoteUpdatedAt: remoteTime,
        ));
      }
    } finally {
      // head 移动重试前也要保存：拉取类 base 已生效（远端确认状态），
      // 保存幂等且防止重试轮重复下载。
      await baseStore.saveAll(baseByKey.values.toList());
    }
  }

  // -------------------------------------------------------------------------
  // 动作执行细节
  // -------------------------------------------------------------------------

  void _applyPull(
    PullAction action,
    Map<String, Note> noteByKey,
    Map<String, Note> latestById,
    Map<String, NoteSyncBase> baseByKey,
    _Counters c,
  ) {
    final decoded = decodeNoteFile(action.path, action.content);
    final isTxt = decoded.format == NoteFormat.txt;

    if (action.isNew || !noteByKey.containsKey(action.key)) {
      // 规则 10 / 重复 id / 规则 8 的重命名变体（本地已无该笔记）。
      final noteId = action.duplicateOfKey != null || decoded.id == null
          ? generateId()
          : decoded.id!;
      final now = DateTime.now();
      notesPort.applyRemoteUpsert(Note(
        id: noteId,
        title: decoded.title,
        content: decoded.body,
        tags: decoded.tags,
        category: decoded.category ?? '未分类',
        format: decoded.format,
        createdAt: decoded.created ?? now,
        updatedAt: decoded.updated ?? now,
        syncedAt: now,
        syncStatus: SyncStatus.synced,
        filePath: action.path,
        sha: action.blobSha,
      ));
      final baseKey = isTxt ? action.path : noteId;
      baseByKey[baseKey] = NoteSyncBase(
        key: baseKey,
        path: action.path,
        blobSha: action.blobSha,
        content: action.content,
        syncedAt: now,
      );
      c.pulled++;
      if (action.restoresLocalDeleted) c.restored++;
      return;
    }

    // 规则 3 / 远端重命名：覆盖已有笔记。
    final note = noteByKey[action.key]!;
    final latest = latestById[note.id];
    if (latest == null) return; // 会话中被删，下轮重判
    final base = baseByKey[action.key];
    if (base != null &&
        encodeNoteFile(latest, template: base.content) != base.content) {
      return; // 会话中被编辑（规划时未变），下轮按规则 4 合并
    }
    notesPort.applyRemoteUpsert(latest.copyWith(
      title: decoded.title,
      content: decoded.body,
      tags: decoded.tags,
      category: decoded.category ?? latest.category,
      updatedAt: decoded.updated ?? DateTime.now(),
      syncedAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
      filePath: action.path,
      sha: action.blobSha,
    ));
    // txt 的 key 即路径：远端重命名时 base key 随之迁移。
    final baseKey = isTxt ? action.path : action.key;
    if (baseKey != action.key) baseByKey.remove(action.key);
    baseByKey[baseKey] = NoteSyncBase(
      key: baseKey,
      path: action.path,
      blobSha: action.blobSha,
      content: action.content,
      syncedAt: DateTime.now(),
    );
    c.pulled++;
    if (action.restoresLocalDeleted) c.restored++;
  }

  // -------------------------------------------------------------------------
  // 工具
  // -------------------------------------------------------------------------

  /// 判定器身份键（§5.1）：md=note.id；txt=远端路径（未同步用临时键）。
  String _syncKey(Note note) {
    if (note.format != NoteFormat.txt) return note.id;
    final fp = note.filePath;
    return (fp == null || fp.isEmpty) ? 'txt-new:${note.id}' : fp;
  }

  /// push 落 base 的键：txt 用分配到的路径（下轮 filePath 对上）。
  String _baseKeyForPush(Note note, PushAction action) =>
      note.format == NoteFormat.txt ? action.path : action.key;

  bool _isNoteFile(String path, String notesDir) {
    final lower = path.toLowerCase();
    if (!lower.endsWith('.md') && !lower.endsWith('.txt')) return false;
    if (notesDir.isEmpty) return true;
    return path.startsWith('$notesDir/');
  }

  String _commitMessage(_Counters c) {
    final parts = <String>[
      if (c.pushed > 0) '${c.pushed} pushed',
      if (c.deletedRemote > 0) '${c.deletedRemote} deleted',
    ];
    final detail = parts.isEmpty ? 'update' : parts.join(', ');
    return 'sync: $detail (from $deviceLabel)';
  }
}

class _Counters {
  int pushed = 0;
  int pulled = 0;
  int deletedLocal = 0;
  int deletedRemote = 0;
  int restored = 0;
  final failures = <String>[];

  /// 待裁决冲突（规则 4）：本地/base/远端均未改动，仅收集供 UI 二选一。
  final conflicts = <SyncConflict>[];

  /// 吸收一轮 attempt 的计数。[localOnly] = 只吸收本地已生效的部分
  /// （head 移动重试路径：推送类将在下一轮重新规划并重计）。
  void absorb(_Counters other, {required bool localOnly}) {
    pulled += other.pulled;
    conflicts.addAll(other.conflicts);
    deletedLocal += other.deletedLocal;
    restored += other.restored;
    failures.addAll(other.failures);
    if (!localOnly) {
      pushed += other.pushed;
      deletedRemote += other.deletedRemote;
    }
  }

  SyncReport toReport() => SyncReport(
        pushed: pushed,
        pulled: pulled,
        deletedLocal: deletedLocal,
        deletedRemote: deletedRemote,
        restored: restored,
        failures: List.of(failures),
        pendingConflicts: List.of(conflicts),
      );
}
