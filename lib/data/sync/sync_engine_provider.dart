import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/git_config.dart';
import '../../domain/models/note.dart';
import '../../ui/features/notes/view_models/notes_view_model.dart';
import 'remote/remote_repo.dart';
import 'sync_base_store.dart';
import 'sync_engine.dart';

/// 把 [NotesNotifier] 适配成引擎所需的 [SyncNotesPort]。
///
/// 引擎只经此口读写笔记，所有变更仍流经内存状态权威（NotesNotifier），
/// 再由其持久化——引擎不直写存储（多窗口不变量，见 doc/data-flow.md）。
class _NotesPortAdapter implements SyncNotesPort {
  _NotesPortAdapter(this._notifier);

  final NotesNotifier _notifier;

  @override
  List<Note> snapshot() => _notifier.snapshot();

  @override
  void applyRemoteUpsert(Note note) => _notifier.applyRemoteUpsert(note);

  @override
  void applyRemoteDelete(String noteId) => _notifier.applyRemoteDelete(noteId);

  @override
  void rewriteNoteId(String oldId, String newId) =>
      _notifier.rewriteNoteId(oldId, newId);

  @override
  void markPushed(String noteId, String filePath) =>
      _notifier.markPushed(noteId, filePath);
}

final syncBaseStoreProvider = Provider<SyncBaseStore>((ref) => SyncBaseStore());

/// 远端仓库工厂：默认按平台构造真实 [RemoteRepo]（GitHub Git Data API /
/// Gitee 逐文件）。测试可覆盖此 provider 注入 fake，无需真实网络。
final remoteRepoFactoryProvider =
    Provider<RemoteRepo Function(GitConfig config)>(
  (ref) => (config) => createRemoteRepo(config),
);

/// 设备标签：用于冲突副本命名，帮助用户区分副本来自哪端。
String _deviceLabel() {
  if (kIsWeb) return 'web';
  if (Platform.isWindows) return 'windows';
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  return 'device';
}

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    notesPort: _NotesPortAdapter(ref.read(notesProvider.notifier)),
    baseStore: ref.read(syncBaseStoreProvider),
    deviceLabel: _deviceLabel(),
    remoteFactory: ref.read(remoteRepoFactoryProvider),
  );
});
