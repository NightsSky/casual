import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/update_provider.dart';
import '../services/update_service.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';

/// 展示更新对话框。对话框内容随 [updateProvider] 状态变化。
///
/// 关闭对话框时将更新状态重置回 idle，避免下次残留旧的下载进度/错误。
Future<void> showUpdateDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const UpdateDialog(),
  ).then((_) {
    ref.read(updateProvider.notifier).reset();
  });
}

/// 应用内更新对话框：展示版本、更新说明、下载进度并触发安装。
class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(updateProvider);
    final release = state.release;

    final title = switch (state.phase) {
      UpdatePhase.error => l10n.updateCheckFailed,
      _ => l10n.updateAvailable,
    };

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (release != null) ...[
                Text(
                  l10n.updateNewVersion(release.tagName),
                  style: const TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.updateCurrentVersion(state.currentVersion),
                  style: const TextStyle(
                    fontSize: AppFontSize.xs,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (release.body.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.updateReleaseNotes,
                    style: const TextStyle(
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        release.body.trim(),
                        style: const TextStyle(fontSize: AppFontSize.sm),
                      ),
                    ),
                  ),
                ],
              ],
              if (state.phase == UpdatePhase.error &&
                  state.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.error,
                  ),
                ),
              ],
              if (state.phase == UpdatePhase.downloading) ...[
                const SizedBox(height: AppSpacing.md),
                _DownloadProgress(progress: state.progress),
              ],
              // Windows 若发布的是 zip 压缩包，提示用户下载后手动解压覆盖。
              if (state.phase == UpdatePhase.readyToInstall &&
                  (state.downloadedFilePath?.toLowerCase().endsWith('.zip') ??
                      false)) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.updateWindowsZipHint,
                  style: const TextStyle(
                    fontSize: AppFontSize.xs,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: _buildActions(context, ref, state),
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    WidgetRef ref,
    UpdateState state,
  ) {
    final l10n = context.l10n;
    final notifier = ref.read(updateProvider.notifier);
    final release = state.release;

    void close() => Navigator.of(context).pop();

    Future<void> openReleasePage() async {
      if (release == null || release.htmlUrl.isEmpty) return;
      await launchUrl(
        Uri.parse(release.htmlUrl),
        mode: LaunchMode.externalApplication,
      );
    }

    switch (state.phase) {
      case UpdatePhase.downloading:
        return [
          TextButton(
            onPressed: null,
            child: Text(l10n.updateDownloading),
          ),
        ];
      case UpdatePhase.readyToInstall:
        return [
          TextButton(onPressed: close, child: Text(l10n.updateLater)),
          FilledButton(
            onPressed: () => notifier.install(),
            child: Text(l10n.updateInstallNow),
          ),
        ];
      case UpdatePhase.error:
        return [
          TextButton(onPressed: close, child: Text(l10n.cancel)),
          if (release != null && release.htmlUrl.isNotEmpty)
            FilledButton(
              onPressed: openReleasePage,
              child: Text(l10n.updateOpenReleasePage),
            ),
        ];
      case UpdatePhase.available:
      default:
        return [
          TextButton(onPressed: close, child: Text(l10n.updateLater)),
          if (UpdateService.supportsInAppDownload)
            FilledButton(
              onPressed: () => notifier.download(),
              child: Text(l10n.updateDownloadInstall),
            )
          else
            FilledButton(
              onPressed: openReleasePage,
              child: Text(l10n.updateOpenReleasePage),
            ),
        ];
    }
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.progress});

  /// 0~1 的确定进度；负值表示总长未知（不确定进度）。
  final double progress;

  @override
  Widget build(BuildContext context) {
    final indeterminate = progress < 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.round),
          child: LinearProgressIndicator(
            value: indeterminate ? null : progress.clamp(0.0, 1.0),
            minHeight: 6,
          ),
        ),
        if (!indeterminate) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: AppFontSize.xs,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
