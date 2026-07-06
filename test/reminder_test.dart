import 'package:flutter_test/flutter_test.dart';

import 'package:casual/domain/models/reminder.dart';

void main() {
  test('single reminder in current minute is scheduled shortly', () {
    final now = DateTime(2026, 7, 3, 10, 40, 37);
    final reminder = Reminder(
      title: 'Test',
      time: DateTime(2026, 7, 3, 10, 40),
    );

    final rescheduled = reminder.rescheduledIfExpired(now: now);

    expect(rescheduled.time, now.add(const Duration(seconds: 10)));
  });

  test('expired single reminder before current minute is moved to tomorrow',
      () {
    final now = DateTime(2026, 7, 3, 10, 40, 37);
    final reminder = Reminder(
      title: 'Test',
      time: DateTime(2026, 7, 3, 10, 32),
    );

    final rescheduled = reminder.rescheduledIfExpired(now: now);

    expect(rescheduled.time, DateTime(2026, 7, 4, 10, 32));
  });
}
