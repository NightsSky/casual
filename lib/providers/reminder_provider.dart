import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/reminder.dart';
import '../services/reminder_service.dart';
import '../data/services/storage_service.dart';

final reminderServiceProvider = Provider<ReminderService>((ref) {
  final service = ReminderService(StorageService());
  ref.onDispose(service.dispose);
  return service;
});

final reminderProvider =
    StateNotifierProvider<ReminderNotifier, ReminderState>((ref) {
  final service = ref.watch(reminderServiceProvider);
  return ReminderNotifier(service);
});

class ReminderState {
  final List<Reminder> reminders;
  final bool isLoading;
  final String? error;

  ReminderState({
    this.reminders = const [],
    this.isLoading = false,
    this.error,
  });

  ReminderState copyWith({
    List<Reminder>? reminders,
    bool? isLoading,
    String? error,
  }) {
    return ReminderState(
      reminders: reminders ?? this.reminders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ReminderNotifier extends StateNotifier<ReminderState> {
  final ReminderService _service;

  ReminderNotifier(this._service) : super(ReminderState()) {
    loadReminders();
  }

  Future<void> loadReminders() async {
    state = state.copyWith(isLoading: true);
    try {
      final reminders = await _service.loadReminders();
      state = state.copyWith(
        reminders: reminders,
        isLoading: false,
        error: null,
      );

      for (final reminder in reminders) {
        if (reminder.enabled) {
          await _service.scheduleReminder(reminder);
        }
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> addReminder(Reminder reminder) async {
    final updatedReminders = [...state.reminders, reminder];
    state = state.copyWith(reminders: updatedReminders);

    await _service.saveReminders(updatedReminders);
    if (reminder.enabled) {
      await _service.scheduleReminder(reminder);
    }
  }

  Future<void> updateReminder(Reminder reminder) async {
    final updatedReminders =
        state.reminders.map((r) => r.id == reminder.id ? reminder : r).toList();
    state = state.copyWith(reminders: updatedReminders);

    await _service.saveReminders(updatedReminders);
    if (reminder.enabled) {
      await _service.scheduleReminder(reminder);
    } else {
      await _service.cancelReminder(reminder.id);
    }
  }

  Future<void> deleteReminder(String id) async {
    await _service.cancelReminder(id);

    final updatedReminders = state.reminders.where((r) => r.id != id).toList();
    state = state.copyWith(reminders: updatedReminders);

    await _service.saveReminders(updatedReminders);
  }

  Future<void> toggleReminder(String id) async {
    final reminder = state.reminders.firstWhere((r) => r.id == id);
    var updated = reminder.copyWith(enabled: !reminder.enabled);
    if (updated.enabled) {
      // 重新启用已过期的单次提醒时顺延到未来，否则开关显示开启但永远不会触发
      updated = updated.rescheduledIfExpired();
    }
    await updateReminder(updated);
  }
}
