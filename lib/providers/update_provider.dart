import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/app_release.dart';
import '../services/update_service.dart';

/// 更新流程所处的阶段。
enum UpdatePhase {
  /// 尚未检查。
  idle,

  /// 正在检查远端版本。
  checking,

  /// 已是最新版本。
  upToDate,

  /// 发现新版本，等待用户下载。
  available,

  /// 正在下载安装包。
  downloading,

  /// 下载完成，等待触发安装。
  readyToInstall,

  /// 出错。
  error,
}

/// 更新状态（不可变）。
@immutable
class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.currentVersion = '',
    this.release,
    this.progress = 0,
    this.downloadedFilePath,
    this.errorMessage,
  });

  final UpdatePhase phase;
  final String currentVersion;

  /// 最新的 Release（检查完成后填充，无论是否需要升级）。
  final AppRelease? release;

  /// 下载进度 0~1；-1 表示总长度未知（不确定进度）。
  final double progress;

  /// 下载完成后的本地文件路径。
  final String? downloadedFilePath;

  final String? errorMessage;

  bool get hasUpdate => phase == UpdatePhase.available ||
      phase == UpdatePhase.downloading ||
      phase == UpdatePhase.readyToInstall;

  UpdateState copyWith({
    UpdatePhase? phase,
    String? currentVersion,
    AppRelease? release,
    double? progress,
    String? downloadedFilePath,
    String? errorMessage,
    bool clearError = false,
    bool clearFile = false,
  }) {
    return UpdateState(
      phase: phase ?? this.phase,
      currentVersion: currentVersion ?? this.currentVersion,
      release: release ?? this.release,
      progress: progress ?? this.progress,
      downloadedFilePath:
          clearFile ? null : (downloadedFilePath ?? this.downloadedFilePath),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// 驱动检查 / 下载 / 安装的状态机。
class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier(this._service) : super(const UpdateState());

  final UpdateService _service;

  /// 检查更新。[silent] 用于启动时静默检查（无更新则不改动可见状态）。
  Future<void> checkForUpdate({bool silent = false}) async {
    if (state.phase == UpdatePhase.checking ||
        state.phase == UpdatePhase.downloading) {
      return;
    }
    state = state.copyWith(phase: UpdatePhase.checking, clearError: true);
    try {
      final result = await _service.checkForUpdate();
      if (!mounted) return;
      if (result.hasUpdate) {
        state = state.copyWith(
          phase: UpdatePhase.available,
          currentVersion: result.currentVersion,
          release: result.release,
          progress: 0,
          clearFile: true,
        );
      } else {
        state = state.copyWith(
          phase: UpdatePhase.upToDate,
          currentVersion: result.currentVersion,
          release: result.release,
        );
      }
    } catch (error) {
      if (!mounted) return;
      // 静默检查失败时不打扰用户，仅回到 idle。
      if (silent) {
        state = state.copyWith(phase: UpdatePhase.idle);
      } else {
        state = state.copyWith(
          phase: UpdatePhase.error,
          errorMessage: error.toString(),
        );
      }
    }
  }

  /// 下载当前平台适用的安装包。
  Future<void> download() async {
    final release = state.release;
    if (release == null) return;
    if (!UpdateService.supportsInAppDownload) return;

    final asset = release.assetForPlatform(
      isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
      isWindows: !kIsWeb && defaultTargetPlatform == TargetPlatform.windows,
    );
    if (asset == null) {
      state = state.copyWith(
        phase: UpdatePhase.error,
        errorMessage: '未找到适用于当前平台的安装包',
      );
      return;
    }

    state = state.copyWith(
      phase: UpdatePhase.downloading,
      progress: 0,
      clearError: true,
      clearFile: true,
    );
    try {
      final path = await _service.downloadAsset(
        asset,
        onProgress: (progress, received, total) {
          if (!mounted) return;
          state = state.copyWith(progress: progress);
        },
      );
      if (!mounted) return;
      state = state.copyWith(
        phase: UpdatePhase.readyToInstall,
        progress: 1,
        downloadedFilePath: path,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        phase: UpdatePhase.error,
        errorMessage: error.toString(),
      );
    }
  }

  /// 触发安装已下载的文件。
  Future<bool> install() async {
    final path = state.downloadedFilePath;
    if (path == null) return false;
    try {
      return await _service.installDownloadedFile(path);
    } catch (error) {
      if (mounted) {
        state = state.copyWith(
          phase: UpdatePhase.error,
          errorMessage: error.toString(),
        );
      }
      return false;
    }
  }

  /// 重置回初始状态（关闭对话框后调用）。
  void reset() {
    state = const UpdateState();
  }
}

final updateServiceProvider = Provider<UpdateService>((ref) {
  final service = UpdateService();
  ref.onDispose(service.dispose);
  return service;
});

final updateProvider =
    StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  return UpdateNotifier(ref.watch(updateServiceProvider));
});
