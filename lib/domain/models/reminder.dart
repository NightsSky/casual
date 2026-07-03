import 'package:uuid/uuid.dart';

enum RepeatType {
  none,
  daily,
  weekly,
  monthly,
  weekdays,
  interval,
  custom,
}

class Reminder {
  final String id;
  final String title;

  /// 时刻型提醒的触发时间；interval 型提醒的计时锚点（保存/重新启用时刻）
  final DateTime time;
  final RepeatType repeat;

  /// 仅 repeat == RepeatType.interval 时有效，间隔分钟数（>= 1）
  final int? intervalMinutes;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  Reminder({
    String? id,
    required this.title,
    required this.time,
    this.repeat = RepeatType.none,
    this.intervalMinutes,
    this.enabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Reminder copyWith({
    String? title,
    DateTime? time,
    RepeatType? repeat,
    int? intervalMinutes,
    bool? enabled,
    DateTime? updatedAt,
  }) {
    return Reminder(
      id: id,
      title: title ?? this.title,
      time: time ?? this.time,
      repeat: repeat ?? this.repeat,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// 单次提醒时间已过时，滚动到未来最近的同一时分（今天或明天）；
  /// 间隔提醒把计时锚点重置为当前时刻（下次触发 = 现在 + 间隔）。
  /// 其余重复提醒的触发时间由调度层按重复规则计算，无需处理。
  Reminder rescheduledIfExpired() {
    if (repeat == RepeatType.interval) {
      return copyWith(time: DateTime.now());
    }
    if (repeat != RepeatType.none) return this;
    final now = DateTime.now();
    if (time.isAfter(now)) return this;
    var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return copyWith(time: next);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'time': time.toIso8601String(),
      'repeat': repeat.name,
      if (intervalMinutes != null) 'intervalMinutes': intervalMinutes,
      'enabled': enabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      title: json['title'] as String,
      time: DateTime.parse(json['time'] as String),
      repeat: RepeatType.values.firstWhere(
        (e) => e.name == json['repeat'],
        orElse: () => RepeatType.none,
      ),
      intervalMinutes: json['intervalMinutes'] as int?,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
