import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/services/storage_service.dart';
import '../domain/models/reminder.dart';

class ReminderService {
  static const String _storageKey = 'reminders';

  final FlutterLocalNotificationsPlugin _mobilePlugin =
      FlutterLocalNotificationsPlugin();
  final StorageService _storage;

  bool _initialized = false;
  Timer? _tickTimer;
  final Map<String, DateTime> _nextFireAt = {};
  final Set<String> _firedInThisMinute = {};

  ReminderService(this._storage);

  bool get _useLocalNotifier => !kIsWeb && Platform.isWindows;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    if (_useLocalNotifier) {
      await localNotifier.setup(
        appName: 'casual',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
    } else {
      // tz.local 默认为 UTC，zonedSchedule 依赖它换算触发时间，
      // 必须先设置为设备时区，否则非 UTC 时区的提醒会整体偏移
      try {
        final timeZoneName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReminderService] failed to set local timezone: $e');
        }
      }

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        linux: linuxSettings,
      );

      await _mobilePlugin.initialize(initSettings);

      if (Platform.isAndroid) {
        await _mobilePlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        await _mobilePlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    }

    _initialized = true;
  }

  Future<List<Reminder>> loadReminders() async {
    final jsonString = await _storage.read(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => Reminder.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveReminders(List<Reminder> reminders) async {
    final jsonList = reminders.map((r) => r.toJson()).toList();
    await _storage.write(_storageKey, jsonEncode(jsonList));
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    await initialize();

    if (!reminder.enabled) {
      await cancelReminder(reminder.id);
      return;
    }

    if (_useLocalNotifier) {
      _scheduleWindowsReminder(reminder);
      return;
    }

    await _scheduleMobileReminder(reminder);
  }

  Future<void> cancelReminder(String reminderId) async {
    await initialize();

    _nextFireAt.remove(reminderId);
    _firedInThisMinute.removeWhere((k) => k.startsWith('$reminderId::'));

    if (!_useLocalNotifier) {
      final id = reminderId.hashCode;
      await _mobilePlugin.cancel(id);
      for (int day = DateTime.monday; day <= DateTime.friday; day++) {
        await _mobilePlugin.cancel(id + day);
      }
    }

    if (_nextFireAt.isEmpty) {
      _tickTimer?.cancel();
      _tickTimer = null;
    }
  }

  Future<void> cancelAllReminders() async {
    await initialize();

    _nextFireAt.clear();
    _firedInThisMinute.clear();
    _tickTimer?.cancel();
    _tickTimer = null;

    if (!_useLocalNotifier) {
      await _mobilePlugin.cancelAll();
    }
  }

  Future<void> rescheduleAll(List<Reminder> reminders) async {
    await initialize();
    await cancelAllReminders();
    for (final r in reminders) {
      if (r.enabled) {
        await scheduleReminder(r);
      }
    }
  }

  void _scheduleWindowsReminder(Reminder reminder) {
    final next = _computeNextFire(reminder, DateTime.now());
    if (next == null) {
      _nextFireAt.remove(reminder.id);
      return;
    }
    _nextFireAt[reminder.id] = next;
    _ensureTickTimer();
  }

  void _ensureTickTimer() {
    if (_tickTimer != null) return;
    if (kDebugMode) {
      debugPrint('[ReminderService] tick timer started');
    }
    _tickTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _onTick();
    });
  }

  Future<void> _onTick() async {
    if (_nextFireAt.isEmpty) return;
    final now = DateTime.now();
    final entries = _nextFireAt.entries.toList();
    final reminders = await loadReminders();

    for (final entry in entries) {
      final id = entry.key;
      final fireAt = entry.value;
      final diff = fireAt.difference(now).inSeconds;
      if (diff > 5) continue;

      final reminder = reminders.firstWhere(
        (r) => r.id == id,
        orElse: () => Reminder(
          id: id,
          title: '',
          time: fireAt,
        ),
      );
      if (reminder.title.isEmpty || !reminder.enabled) {
        _nextFireAt.remove(id);
        continue;
      }

      final tag = '$id::${fireAt.toIso8601String()}';
      if (_firedInThisMinute.contains(tag)) continue;
      _firedInThisMinute.add(tag);

      if (kDebugMode) {
        debugPrint(
            '[ReminderService] firing reminder "${reminder.title}" (id=$id) at $now');
      }
      await _showWindowsNotification(reminder);

      // 时刻型提醒粒度为分钟，+1 分钟避开同一分钟重复命中；
      // interval 型直接从本次触发点推进（+1 分钟会让 1 分钟间隔跳拍）
      final following = _computeNextFire(
        reminder,
        reminder.repeat == RepeatType.interval
            ? fireAt
            : fireAt.add(const Duration(minutes: 1)),
      );
      if (following == null) {
        _nextFireAt.remove(id);
      } else {
        _nextFireAt[id] = following;
      }
    }

    // 去重标签只在同一触发点内有意义，清掉过期的避免集合无限增长
    _firedInThisMinute.removeWhere((tag) {
      final firedAt = DateTime.tryParse(tag.split('::').last);
      return firedAt == null ||
          now.difference(firedAt) > const Duration(minutes: 2);
    });

    if (_nextFireAt.isEmpty) {
      _tickTimer?.cancel();
      _tickTimer = null;
      if (kDebugMode) {
        debugPrint('[ReminderService] tick timer stopped (no pending)');
      }
    }
  }

  Future<void> _showWindowsNotification(Reminder reminder) async {
    try {
      final notification = LocalNotification(
        title: 'casual 助手',
        body: reminder.title,
      );
      await notification.show();
      if (kDebugMode) {
        debugPrint(
            '[ReminderService] Windows notification shown: ${reminder.title}');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ReminderService] Windows notification error: $e\n$st');
      }
    }
  }

  Future<void> _scheduleMobileReminder(Reminder reminder) async {
    final scheduledDate = tz.TZDateTime.from(reminder.time, tz.local);
    final now = tz.TZDateTime.now(tz.local);

    if (scheduledDate.isBefore(now) && reminder.repeat == RepeatType.none) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Reminder notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const linuxDetails = LinuxNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
    );

    final notificationId = reminder.id.hashCode;

    switch (reminder.repeat) {
      case RepeatType.none:
        await _mobilePlugin.zonedSchedule(
          notificationId,
          'casual 助手',
          reminder.title,
          scheduledDate,
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        break;

      case RepeatType.daily:
        await _mobilePlugin.zonedSchedule(
          notificationId,
          'casual 助手',
          reminder.title,
          _nextInstanceOfTime(scheduledDate.hour, scheduledDate.minute),
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        break;

      case RepeatType.weekly:
        await _mobilePlugin.zonedSchedule(
          notificationId,
          'casual 助手',
          reminder.title,
          _nextInstanceOfDayAndTime(
              scheduledDate.weekday, scheduledDate.hour, scheduledDate.minute),
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
        break;

      case RepeatType.weekdays:
        for (int day = DateTime.monday; day <= DateTime.friday; day++) {
          await _mobilePlugin.zonedSchedule(
            notificationId + day,
            'casual 助手',
            reminder.title,
            _nextInstanceOfDayAndTime(
                day, scheduledDate.hour, scheduledDate.minute),
            details,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
        break;

      case RepeatType.monthly:
        await _mobilePlugin.zonedSchedule(
          notificationId,
          'casual 助手',
          reminder.title,
          _nextInstanceOfMonthAndTime(
              scheduledDate.day, scheduledDate.hour, scheduledDate.minute),
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );
        break;

      case RepeatType.interval:
        final minutes = reminder.intervalMinutes ?? 0;
        // iOS 的 UNTimeIntervalNotificationTrigger 要求周期 >= 60 秒，
        // UI 层已限制最小 1 分钟，这里防御历史脏数据
        if (minutes <= 0) break;
        await _mobilePlugin.periodicallyShowWithDuration(
          notificationId,
          'casual 助手',
          reminder.title,
          Duration(minutes: minutes),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        break;

      case RepeatType.custom:
        break;
    }
  }

  DateTime? _computeNextFire(Reminder reminder, DateTime from) {
    final base = reminder.time;
    switch (reminder.repeat) {
      case RepeatType.none:
        return base.isAfter(from) ? base : null;

      case RepeatType.daily:
        var next = DateTime(
            from.year, from.month, from.day, base.hour, base.minute);
        if (!next.isAfter(from)) {
          next = next.add(const Duration(days: 1));
        }
        return next;

      case RepeatType.weekly:
        var next = DateTime(
            from.year, from.month, from.day, base.hour, base.minute);
        while (!next.isAfter(from) || next.weekday != base.weekday) {
          next = next.add(const Duration(days: 1));
        }
        return next;

      case RepeatType.weekdays:
        var next = DateTime(
            from.year, from.month, from.day, base.hour, base.minute);
        while (!next.isAfter(from) ||
            next.weekday == DateTime.saturday ||
            next.weekday == DateTime.sunday) {
          next = next.add(const Duration(days: 1));
        }
        return next;

      case RepeatType.monthly:
        var year = from.year;
        var month = from.month;
        var next =
            DateTime(year, month, base.day, base.hour, base.minute);
        if (!next.isAfter(from)) {
          month += 1;
          if (month > 12) {
            month = 1;
            year += 1;
          }
          next = DateTime(year, month, base.day, base.hour, base.minute);
        }
        return next;

      case RepeatType.interval:
        final minutes = reminder.intervalMinutes ?? 0;
        if (minutes <= 0) return null;
        final interval = Duration(minutes: minutes);
        // base 是计时锚点（保存/重新启用时刻），触发点为 base + k*interval；
        // 取严格晚于 from 的最近一个，应用重启后仍延续原节奏而不会立即补发
        if (base.isAfter(from)) return base.add(interval);
        final k =
            from.difference(base).inMicroseconds ~/ interval.inMicroseconds +
                1;
        return base.add(interval * k);

      case RepeatType.custom:
        return null;
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfDayAndTime(int day, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduledDate.weekday != day || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfMonthAndTime(int day, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        now.month == 12 ? now.year + 1 : now.year,
        now.month == 12 ? 1 : now.month + 1,
        day,
        hour,
        minute,
      );
    }
    return scheduledDate;
  }
}
