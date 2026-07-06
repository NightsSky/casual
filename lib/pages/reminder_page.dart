import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/models/reminder.dart';
import '../providers/reminder_provider.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';

/// 把间隔分钟数格式化为本地化的「1 小时 30 分钟」形式
String _formatIntervalDuration(BuildContext context, int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return [
    if (hours > 0) context.l10n.durationHours(hours),
    if (minutes > 0 || hours == 0) context.l10n.durationMinutes(minutes),
  ].join(' ');
}

class ReminderPage extends ConsumerStatefulWidget {
  const ReminderPage({super.key});

  @override
  ConsumerState<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends ConsumerState<ReminderPage> {
  @override
  Widget build(BuildContext context) {
    final reminderState = ref.watch(reminderProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(context.l10n.reminders),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showReminderDialog(context),
                ),
              ],
            ),
      body: reminderState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : reminderState.reminders.isEmpty
              ? _buildEmptyState()
              : _buildReminderList(reminderState.reminders),
      floatingActionButton: isDesktop
          ? FloatingActionButton(
              onPressed: () => _showReminderDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alarm_add, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.l10n.noRemindersYet,
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.createFirstReminder,
            style: TextStyle(
                fontSize: AppFontSize.sm, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderList(List<Reminder> reminders) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        final reminder = reminders[index];
        return Card(
          child: InkWell(
            onTap: () => _showReminderDialog(context, reminder: reminder),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.title,
                          style: const TextStyle(
                            fontSize: AppFontSize.lg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _formatReminderTime(reminder),
                          style: const TextStyle(
                            fontSize: AppFontSize.sm,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (reminder.repeat != RepeatType.none)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              _getRepeatLabel(reminder.repeat),
                              style: const TextStyle(
                                fontSize: AppFontSize.xs,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Switch(
                    value: reminder.enabled,
                    onChanged: (_) => ref
                        .read(reminderProvider.notifier)
                        .toggleReminder(reminder.id),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatReminderTime(Reminder reminder) {
    if (reminder.repeat == RepeatType.interval) {
      return context.l10n.reminderIntervalEvery(
        _formatIntervalDuration(context, reminder.intervalMinutes ?? 0),
      );
    }
    return DateFormat('HH:mm').format(reminder.time);
  }

  String _getRepeatLabel(RepeatType repeat) {
    switch (repeat) {
      case RepeatType.none:
        return context.l10n.reminderNone;
      case RepeatType.daily:
        return context.l10n.reminderDaily;
      case RepeatType.weekly:
        return context.l10n.reminderWeekly;
      case RepeatType.monthly:
        return context.l10n.reminderMonthly;
      case RepeatType.weekdays:
        return context.l10n.reminderWeekdays;
      case RepeatType.interval:
        return context.l10n.reminderInterval;
      case RepeatType.custom:
        return context.l10n.reminderCustom;
    }
  }

  void _showReminderDialog(BuildContext context, {Reminder? reminder}) {
    showDialog(
      context: context,
      useSafeArea: true,
      builder: (context) => _ReminderDialog(reminder: reminder),
    );
  }
}

class _ReminderDialog extends ConsumerStatefulWidget {
  final Reminder? reminder;

  const _ReminderDialog({this.reminder});

  @override
  ConsumerState<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends ConsumerState<_ReminderDialog> {
  static const List<int> _minutePresets = [0, 1, 5, 10, 15, 20, 30, 45];

  late TextEditingController _titleController;
  late DateTime _selectedTime;
  late RepeatType _selectedRepeat;
  late int _intervalHours;
  late int _intervalMinutes;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.reminder?.title ?? '');
    final now = DateTime.now();
    final defaultTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    _selectedTime = widget.reminder?.time ?? defaultTime;
    _selectedRepeat = widget.reminder?.repeat ?? RepeatType.none;
    final interval = widget.reminder?.intervalMinutes ?? 60;
    _intervalHours = interval ~/ 60;
    _intervalMinutes = interval % 60;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.reminder != null;
    final dialogTitle =
        isEdit ? context.l10n.editReminder : context.l10n.addReminder;
    final mediaQuery = MediaQuery.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 14,
      shadowColor: const Color(0x26000000),
      backgroundColor: AppColors.bgTertiary,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: mediaQuery.size.height -
              mediaQuery.padding.vertical -
              AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              decoration: const BoxDecoration(
                color: AppColors.bgPrimary,
                border: Border(
                  bottom: BorderSide(color: AppColors.borderColor),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      dialogTitle,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: AppFontSize.xl,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: _dialogInputDecoration(
                        labelText: context.l10n.reminderTitle,
                        hintText: context.l10n.enterReminderTitle,
                        icon: Icons.edit_note_outlined,
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // 间隔型助手从保存时刻开始计时，具体时分无意义，隐藏固定时刻选择。
                    if (_selectedRepeat != RepeatType.interval) ...[
                      Text(
                        context.l10n.reminderTime,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFontSize.sm,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      InkWell(
                        onTap: _selectTime,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.bgSecondary,
                            border: Border.all(color: AppColors.borderColor),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.bgTertiary,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  border: Border.all(
                                    color: AppColors.borderColor,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.access_time,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.selectTime,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: AppFontSize.xs,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      DateFormat('HH:mm').format(_selectedTime),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: AppFontSize.xl,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: AppColors.textPlaceholder,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    DropdownButtonFormField<RepeatType>(
                      initialValue: _selectedRepeat,
                      isExpanded: true,
                      decoration: _dialogInputDecoration(
                        labelText: context.l10n.reminderRepeat,
                        icon: Icons.repeat,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: RepeatType.none,
                          child: Text(context.l10n.reminderNone),
                        ),
                        DropdownMenuItem(
                          value: RepeatType.daily,
                          child: Text(context.l10n.reminderDaily),
                        ),
                        DropdownMenuItem(
                          value: RepeatType.weekly,
                          child: Text(context.l10n.reminderWeekly),
                        ),
                        DropdownMenuItem(
                          value: RepeatType.monthly,
                          child: Text(context.l10n.reminderMonthly),
                        ),
                        DropdownMenuItem(
                          value: RepeatType.weekdays,
                          child: Text(context.l10n.reminderWeekdays),
                        ),
                        DropdownMenuItem(
                          value: RepeatType.interval,
                          child: Text(context.l10n.reminderInterval),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedRepeat = value);
                        }
                      },
                    ),
                    if (_selectedRepeat == RepeatType.interval) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _buildIntervalPicker(),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              decoration: const BoxDecoration(
                color: AppColors.bgTertiary,
                border: Border(
                  top: BorderSide(color: AppColors.borderColor),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (isEdit)
                    TextButton.icon(
                      onPressed: _deleteReminder,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(context.l10n.deleteReminder),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.cancel),
                  ),
                  FilledButton.icon(
                    onPressed: _saveReminder,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(context.l10n.save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dialogInputDecoration({
    required String labelText,
    String? hintText,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      filled: true,
      fillColor: AppColors.bgSecondary,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: _dialogInputBorder(AppColors.borderColor),
      enabledBorder: _dialogInputBorder(AppColors.borderColor),
      focusedBorder: _dialogInputBorder(AppColors.primary),
    );
  }

  OutlineInputBorder _dialogInputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color),
    );
  }

  /// 小时 + 分钟两个下拉组成的间隔选择器。
  /// 小时为 0 时分钟列表不提供 0，保证总间隔至少 1 分钟
  /// （iOS 周期通知的系统下限为 60 秒）。
  Widget _buildIntervalPicker() {
    final minuteValues = {
      ..._minutePresets.where((m) => _intervalHours > 0 || m > 0),
      _intervalMinutes,
    }.toList()
      ..sort();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.reminderInterval,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _intervalHours,
                  isExpanded: true,
                  decoration: _dialogInputDecoration(
                    labelText: context.l10n.reminderIntervalHoursLabel,
                  ),
                  items: [
                    for (var h = 0; h <= 24; h++)
                      DropdownMenuItem(value: h, child: Text('$h')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _intervalHours = value;
                      if (_intervalHours == 0 && _intervalMinutes == 0) {
                        _intervalMinutes = 30;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _intervalMinutes,
                  isExpanded: true,
                  decoration: _dialogInputDecoration(
                    labelText: context.l10n.reminderIntervalMinutesLabel,
                  ),
                  items: [
                    for (final m in minuteValues)
                      DropdownMenuItem(value: m, child: Text('$m')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _intervalMinutes = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.reminderIntervalHint,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSize.xs,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTime),
    );

    if (time != null) {
      setState(() {
        _selectedTime = DateTime(
          _selectedTime.year,
          _selectedTime.month,
          _selectedTime.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Future<void> _saveReminder() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    final isInterval = _selectedRepeat == RepeatType.interval;
    final intervalMinutes = _intervalHours * 60 + _intervalMinutes;
    if (isInterval && intervalMinutes < 1) {
      return;
    }

    // 单次提醒若所选时分已过，顺延到明天（rescheduledIfExpired），
    // 否则会被调度层因时间过期静默跳过；
    // 间隔提醒由 rescheduledIfExpired 把计时锚点重置为当前时刻。
    final reminder = (widget.reminder?.copyWith(
              title: title,
              time: _selectedTime,
              repeat: _selectedRepeat,
              intervalMinutes: isInterval ? intervalMinutes : null,
            ) ??
            Reminder(
              title: title,
              time: _selectedTime,
              repeat: _selectedRepeat,
              intervalMinutes: isInterval ? intervalMinutes : null,
            ))
        .rescheduledIfExpired();

    try {
      // 保存提示必须等本地持久化和系统通知调度完成后再展示，
      // 否则 Android 权限或系统调度异常会被“已保存”提示掩盖。
      if (widget.reminder == null) {
        await ref.read(reminderProvider.notifier).addReminder(reminder);
      } else {
        await ref.read(reminderProvider.notifier).updateReminder(reminder);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.reminderSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.reminderSaveFailed(e.toString()))),
      );
    }
  }

  Future<void> _deleteReminder() async {
    final reminder = widget.reminder;
    if (reminder == null) return;

    // 删除助手会取消后续系统提醒，先二次确认，避免误触导致提醒计划丢失。
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgTertiary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(context.l10n.confirmDelete)),
          ],
        ),
        content: Text(context.l10n.confirmDeleteReminder(reminder.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(context.l10n.delete),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;
    ref.read(reminderProvider.notifier).deleteReminder(reminder.id);
    Navigator.of(context).pop();
  }
}
