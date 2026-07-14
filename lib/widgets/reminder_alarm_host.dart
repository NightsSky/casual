import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/reminder.dart';
import '../providers/reminder_provider.dart';
import '../services/reminder_alarm_window_service.dart';
import '../services/window_service.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';
import 'reminder_alarm_panel.dart';

class ReminderAlarmHost extends ConsumerStatefulWidget {
  const ReminderAlarmHost({
    super.key,
    required this.child,
    this.openAlarmWindow,
  });

  final Widget child;
  final Future<bool> Function(Reminder reminder)? openAlarmWindow;

  @override
  ConsumerState<ReminderAlarmHost> createState() => _ReminderAlarmHostState();
}

class _ReminderAlarmHostState extends ConsumerState<ReminderAlarmHost> {
  final List<Reminder> _pendingReminders = [];
  StreamSubscription<Reminder>? _subscription;
  bool _showingAlarm = false;

  @override
  void initState() {
    super.initState();
    _subscription =
        ref.read(reminderServiceProvider).windowsAlarmStream.listen(_enqueue);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _enqueue(Reminder reminder) {
    _pendingReminders.add(reminder);
    if (!_showingAlarm) {
      unawaited(_showNextAlarm());
    }
  }

  Future<void> _showNextAlarm() async {
    _showingAlarm = true;
    try {
      while (mounted && _pendingReminders.isNotEmpty) {
        final reminder = _pendingReminders.removeAt(0);
        // Windows 到点提醒优先使用独立小窗口承载闹钟，
        // 主窗口保持隐藏或最小化状态，避免提醒时把完整工作区拉到前台。
        final openAlarmWindow =
            widget.openAlarmWindow ?? ReminderAlarmWindowService.show;
        final openedInAlarmWindow = await openAlarmWindow(reminder);
        if (openedInAlarmWindow) continue;

        // 独立提醒窗口不可用时回退到旧的主窗口 Dialog，保证提醒不会静默丢失。
        try {
          await WindowService.instance
              .showWindow()
              .timeout(const Duration(milliseconds: 300));
        } on TimeoutException {
          // 测试环境或窗口插件短暂无响应时，不能阻塞闹钟弹窗本身。
        } catch (error) {
          debugPrint('[ReminderAlarmHost] failed to focus main window: $error');
        }
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _ReminderAlarmDialog(reminder: reminder),
        );
      }
    } finally {
      _showingAlarm = false;
      if (mounted && _pendingReminders.isNotEmpty) {
        unawaited(_showNextAlarm());
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ReminderAlarmDialog extends StatefulWidget {
  const _ReminderAlarmDialog({required this.reminder});

  final Reminder reminder;

  @override
  State<_ReminderAlarmDialog> createState() => _ReminderAlarmDialogState();
}

class _ReminderAlarmDialogState extends State<_ReminderAlarmDialog> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = widget.reminder.title.trim().isEmpty
        ? l10n.reminderAlarmDefaultBody
        : widget.reminder.title.trim();

    return Dialog(
      alignment: Alignment.bottomRight,
      insetPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ReminderAlarmPanel(
        message: message,
        reminderTime: DateTime.now(),
        onLater: () => Navigator.of(context).pop(),
        onConfirm: () => Navigator.of(context).pop(),
      ),
    );
  }
}
