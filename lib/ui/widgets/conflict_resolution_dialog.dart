import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/sync/sync_engine.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/constants.dart';

/// 同步冲突裁决对话框（doc/sync-design.md §7）。
///
/// 展示本地与远端最后更新时间，用户选「保留本地 / 用远程覆盖 / 取消」。
/// 逐篇冲突串行弹窗，收集所有裁决后批量落地（[SyncEngine.resolveConflicts]）。
class ConflictResolutionDialog extends StatelessWidget {
  const ConflictResolutionDialog({
    super.key,
    required this.conflict,
    required this.currentIndex,
    required this.totalCount,
  });

  final SyncConflict conflict;
  final int currentIndex;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.syncConflictTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          Text(
            '${currentIndex + 1}/$totalCount',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conflict.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _TimelineRow(
              label: l10n.syncConflictLocalTime,
              time: conflict.localUpdatedAt,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.xs),
            _TimelineRow(
              label: l10n.syncConflictRemoteTime,
              time: conflict.remoteUpdatedAt,
              color: AppColors.success,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.syncConflictDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.cancel),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(ConflictChoice.takeRemote),
          child: Text(l10n.syncConflictTakeRemote),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ConflictChoice.keepLocal),
          child: Text(l10n.syncConflictKeepLocal),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.time,
    required this.color,
  });

  final String label;
  final DateTime? time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final timeStr = time == null
        ? l10n.syncConflictTimeUnknown
        : DateFormat('yyyy-MM-dd HH:mm').format(time!);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          timeStr,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

extension _L10nExt on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
