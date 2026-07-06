import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/git_config_repository.dart';
import '../../../../data/repositories/git_sync_repository.dart';
import '../../../../data/sync/sync_engine.dart';
import '../../../../data/sync/sync_engine_provider.dart';
import '../../../../domain/models/models.dart';

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


  /// 主同步入口（v2 引擎，doc/sync-design.md §8）。
  ///
  /// 一次调用 = 一个完整同步会话：判定拉/推/删除并各自执行，
  /// 冲突收集到 [SyncReport.pendingConflicts] 返回，由 UI 调
  /// [resolveConflicts] 落地裁决后再同步一次（推送「保留本地」的改动）。
  Future<SyncReport> runSync() async {
    if (!state.config.isConfigured) {
      return SyncReport();
    }

    state = state.copyWith(isSyncing: true, clearSyncError: true);
    try {
      final engine = _ref.read(syncEngineProvider);
      final report = await engine.sync(state.config);

      final now = DateTime.now();
      final updatedConfig = state.config.copyWith(lastSyncTime: now);
      state = state.copyWith(config: updatedConfig, isSyncing: false);
      await _configRepository.saveConfig(updatedConfig);

      addSyncLog(
        report.failures.isEmpty ? SyncLogType.success : SyncLogType.warning,
        report.summary(),
      );
      return report;
    } catch (e) {
      state = state.copyWith(syncError: e.toString(), isSyncing: false);
      addSyncLog(SyncLogType.error, e.toString());
      rethrow;
    }
  }

  /// 落地用户对冲突的裁决（doc/sync-design.md §7.2）。
  /// 纯本地操作不触网，调用后应再同步一次把「保留本地」的推上去。
  Future<void> resolveConflicts(List<ConflictResolution> resolutions) async {
    final engine = _ref.read(syncEngineProvider);
    await engine.resolveConflicts(resolutions);
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
