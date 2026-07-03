import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/git_config_repository.dart';
import '../../../../data/repositories/git_sync_repository.dart';
import '../../../../domain/models/models.dart';
import '../../notes/view_models/notes_view_model.dart';

class GitState {
  final GitConfig config;
  final bool isSyncing;
  final String? syncError;
  final bool connected;
  final List<SyncLog> syncLogs;

  const GitState({
    required this.config,
    this.isSyncing = false,
    this.syncError,
    this.connected = false,
    this.syncLogs = const [],
  });

  String get syncStatusText {
    if (isSyncing) return '同步中...';
    if (syncError != null) return '同步失败: $syncError';
    if (config.lastSyncTime != null) {
      final date = config.lastSyncTime!;
      return '上次同步: ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '未同步';
  }

  GitState copyWith({
    GitConfig? config,
    bool? isSyncing,
    String? syncError,
    bool clearSyncError = false,
    bool? connected,
    List<SyncLog>? syncLogs,
  }) {
    return GitState(
      config: config ?? this.config,
      isSyncing: isSyncing ?? this.isSyncing,
      syncError: clearSyncError ? null : syncError ?? this.syncError,
      connected: connected ?? this.connected,
      syncLogs: syncLogs ?? this.syncLogs,
    );
  }
}

class GitNotifier extends StateNotifier<GitState> {
  GitNotifier(
    this._ref,
    this._configRepository,
    this._syncRepository,
  ) : super(const GitState(
          config: GitConfig(
              platform: GitPlatform.github, token: '', owner: '', repo: ''),
        ));

  final Ref _ref;
  final GitConfigRepository _configRepository;
  final GitSyncRepository _syncRepository;

  Future<void> loadConfig() async {
    final config = await _configRepository.loadConfig();
    state = state.copyWith(config: config);
  }

  void setConfig(GitConfig config) {
    state = state.copyWith(config: config, connected: false);
    _configRepository.saveConfig(config);
  }

  void clearConfig() {
    const config =
        GitConfig(platform: GitPlatform.github, token: '', owner: '', repo: '');
    state =
        state.copyWith(config: config, connected: false, clearSyncError: true);
    _configRepository.saveConfig(config);
  }

  Future<bool> testConnection() async {
    if (!state.config.isConfigured) {
      state = state.copyWith(syncError: '请先配置 Git 平台');
      return false;
    }

    state = state.copyWith(isSyncing: true, clearSyncError: true);
    try {
      final result = await _syncRepository.testConnection(state.config);
      state = state.copyWith(connected: result, isSyncing: false);
      return result;
    } catch (e) {
      state = state.copyWith(
          syncError: e.toString(), connected: false, isSyncing: false);
      return false;
    }
  }

  Future<List<Note>> pullNotes() async {
    if (!state.config.isConfigured) return [];

    state = state.copyWith(isSyncing: true, clearSyncError: true);
    try {
      final notes = await _syncRepository.pullNotes(state.config);
      final now = DateTime.now();
      final updatedConfig = state.config.copyWith(lastSyncTime: now);
      state = state.copyWith(config: updatedConfig, isSyncing: false);
      await _configRepository.saveConfig(updatedConfig);
      return notes;
    } catch (e) {
      state = state.copyWith(syncError: e.toString(), isSyncing: false);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> pushNote(Note note) async {
    if (!state.config.isConfigured) return null;

    state = state.copyWith(isSyncing: true, clearSyncError: true);
    try {
      final result = await _syncRepository.pushNote(state.config, note);
      final now = DateTime.now();
      final updatedConfig = state.config.copyWith(lastSyncTime: now);
      state = state.copyWith(config: updatedConfig, isSyncing: false);
      await _configRepository.saveConfig(updatedConfig);
      return result;
    } catch (e) {
      state = state.copyWith(syncError: e.toString(), isSyncing: false);
      rethrow;
    }
  }

  Future<void> deleteRemoteNote(String filePath, String? sha) async {
    if (!state.config.isConfigured) return;

    state = state.copyWith(isSyncing: true, clearSyncError: true);
    try {
      await _syncRepository.deleteRemoteNote(
        state.config,
        filePath: filePath,
        sha: sha,
      );
      state = state.copyWith(isSyncing: false);
    } catch (e) {
      state = state.copyWith(syncError: e.toString(), isSyncing: false);
      rethrow;
    }
  }

  Future<List<Note>> fullSync() async {
    if (!state.config.isConfigured) return [];

    final notesNotifier = _ref.read(notesProvider.notifier);
    final unsyncedNotes = _ref
        .read(notesProvider)
        .notes
        .where((n) => n.syncStatus == SyncStatus.local)
        .toList();

    // 主同步入口先把本地未同步编辑写入远程，成功后记录远程路径和 sha，
    // 避免随后拉取远程列表时又用旧内容覆盖本地修改。
    for (final note in unsyncedNotes) {
      final result = await pushNote(note);
      if (result != null) {
        notesNotifier.markSynced(
          note.id,
          result['filePath'] as String,
          sha: result['sha'] as String?,
        );
      }
    }

    // 本地推送完成后再读取远程最新版本，供页面导入远程新增或其他设备更新的笔记。
    return pullNotes();
  }

  Future<void> clearAll() => _configRepository.clearAll();

  void addSyncLog(SyncLogType type, String message) {
    final log = SyncLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      message: message,
      timestamp: DateTime.now(),
    );
    final logs = [log, ...state.syncLogs];
    state =
        state.copyWith(syncLogs: logs.length > 50 ? logs.sublist(0, 50) : logs);
  }
}

final gitProvider = StateNotifierProvider<GitNotifier, GitState>((ref) {
  return GitNotifier(
    ref,
    ref.watch(gitConfigRepositoryProvider),
    ref.watch(gitSyncRepositoryProvider),
  );
});
