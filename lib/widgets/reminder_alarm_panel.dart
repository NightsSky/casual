import 'package:flutter/material.dart';

import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';

/// 提醒到点时展示的右下角弹框内容，供主窗口兜底 Dialog 和 Windows 独立提醒窗口共用。
class ReminderAlarmPanel extends StatelessWidget {
  const ReminderAlarmPanel({
    super.key,
    required this.message,
    required this.reminderTime,
    required this.onLater,
    required this.onConfirm,
  });

  final String message;
  final DateTime reminderTime;
  final VoidCallback onLater;
  final VoidCallback onConfirm;

  static const Size panelSize = Size(368, 240);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final alarmTime = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(reminderTime),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        width: panelSize.width,
        constraints: const BoxConstraints(minHeight: 208),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.bgTertiary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AlarmHeader(onClose: onConfirm),
            // 兜底 Dialog 路径下 insetPadding 会把可用高度压到内容自然高度以下，
            // 用 Flexible + 滚动容器承接，避免小屏或紧约束时 RenderFlex 溢出。
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.access_time_rounded,
                      text: '${l10n.reminderTime} $alarmTime',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.notifications_none_rounded,
                      text: l10n.reminderAlarmSource,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _AlarmActionButton(
                            onPressed: onLater,
                            text: l10n.reminderAlarmLater,
                            trailingIcon: Icons.keyboard_arrow_down_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AlarmActionButton(
                            onPressed: onConfirm,
                            text: l10n.reminderAlarmAcknowledge,
                            isPrimary: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlarmHeader extends StatelessWidget {
  const _AlarmHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.only(left: 18, right: 10),
      color: const Color(0xFFEAF1FA),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_rounded,
            color: Color(0xFF1677FF),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.reminder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1677FF),
                fontSize: AppFontSize.base,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: const Color(0xFF9AA3AD),
            splashRadius: 18,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSize.sm,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _AlarmActionButton extends StatelessWidget {
  const _AlarmActionButton({
    required this.onPressed,
    required this.text,
    this.trailingIcon,
    this.isPrimary = false,
  });

  final VoidCallback onPressed;
  final String text;
  final IconData? trailingIcon;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final foreground =
        isPrimary ? const Color(0xFF006DFF) : AppColors.textPrimary;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFFF2F3F5),
        foregroundColor: foreground,
        minimumSize: const Size.fromHeight(36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        textStyle: TextStyle(
          fontSize: AppFontSize.base,
          fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 2),
            Icon(trailingIcon, size: 16),
          ],
        ],
      ),
    );
  }
}
