import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:casual/data/repositories/plans_repository.dart';
import 'package:casual/data/services/storage_service.dart';
import 'package:casual/domain/models/plan.dart';
import 'package:casual/domain/models/reminder.dart';
import 'package:casual/providers/plan_provider.dart';
import 'package:casual/services/reminder_service.dart';

class _FakePlanReminderService extends ReminderService {
  _FakePlanReminderService() : super(StorageService());

  final List<Reminder> scheduled = [];
  final List<String> cancelled = [];

  @override
  Future<void> scheduleReminder(Reminder reminder) async {
    scheduled.add(reminder);
  }

  @override
  Future<void> cancelReminder(String reminderId) async {
    cancelled.add(reminderId);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final now = DateTime(2026, 7, 15, 12);

  PlanStep step(
    String title,
    DateTime targetAt, {
    bool reminderEnabled = false,
    int reminderMinutesBefore = 0,
  }) {
    return PlanStep(
      title: title,
      targetAt: targetAt,
      reminderEnabled: reminderEnabled,
      reminderMinutesBefore: reminderMinutesBefore,
    );
  }

  test('new plan step defaults to an enabled deadline reminder', () {
    final newStep = PlanStep(
      title: '默认提醒步骤',
      targetAt: now.add(const Duration(days: 1)),
    );

    expect(newStep.reminderEnabled, isTrue);
    expect(newStep.reminderMinutesBefore, 0);
    expect(newStep.reminderAt, newStep.targetAt);
  });

  test('plan deadline and progress are derived from ordered steps', () {
    final plan = Plan.create(
      title: '实施项目',
      goal: '完成项目交付',
      startAt: now,
      steps: [
        step('完成项目创建', now.add(const Duration(days: 1))),
        step('开始实施', now.add(const Duration(days: 5))),
      ],
      now: now,
    );

    expect(plan.progress, 0);
    expect(plan.deadline, now.add(const Duration(days: 5)));
    expect(plan.nextStep?.title, '完成项目创建');
    expect(plan.statusAt(now.subtract(const Duration(hours: 1))),
        PlanStatus.notStarted);
    expect(
        plan.statusAt(now.add(const Duration(days: 2))), PlanStatus.inProgress);
  });

  test('steps can complete out of order and all steps auto-complete plan', () {
    var plan = Plan.create(
      title: '实施项目',
      goal: '完成项目交付',
      startAt: now,
      steps: [
        step('完成项目创建', now.add(const Duration(days: 1))),
        step('开始实施', now.add(const Duration(days: 5))),
      ],
      now: now,
    );

    plan = plan.completeStep(
      plan.steps[1].id,
      note: '实施已提前开始',
      now: now.add(const Duration(hours: 2)),
    );
    expect(plan.progress, 50);
    expect(plan.lifecycle, PlanLifecycle.active);
    expect(plan.steps[1].completionNote, '实施已提前开始');

    plan = plan.completeStep(
      plan.steps[0].id,
      now: now.add(const Duration(hours: 3)),
    );
    expect(plan.progress, 100);
    expect(plan.lifecycle, PlanLifecycle.completed);
    expect(
        plan.statusAt(now.add(const Duration(days: 20))), PlanStatus.completed);
    expect(
      plan.timeline.map((event) => event.type),
      [
        PlanTimelineEventType.created,
        PlanTimelineEventType.stepCompleted,
        PlanTimelineEventType.stepCompleted,
        PlanTimelineEventType.completed,
      ],
    );
  });

  test('reopening a step restores an auto-completed plan to active', () {
    var plan = Plan.create(
      title: '实施项目',
      goal: '完成项目交付',
      startAt: now,
      steps: [step('完成项目创建', now.add(const Duration(days: 1)))],
      now: now,
    );
    final stepId = plan.steps.single.id;

    plan = plan.completeStep(stepId, now: now.add(const Duration(hours: 1)));
    plan = plan.reopenStep(stepId, now: now.add(const Duration(hours: 2)));

    expect(plan.progress, 0);
    expect(plan.lifecycle, PlanLifecycle.active);
    expect(plan.endedAt, isNull);
    expect(plan.steps.single.completedAt, isNull);
    expect(plan.timeline.last.type, PlanTimelineEventType.stepReopened);
  });

  test('adding a step reopens a completed plan and last step cannot be removed',
      () {
    var plan = Plan.create(
      title: '实施项目',
      goal: '完成项目交付',
      startAt: now,
      steps: [step('完成项目创建', now.add(const Duration(days: 1)))],
      now: now,
    );
    plan = plan.completeStep(
      plan.steps.single.id,
      now: now.add(const Duration(hours: 1)),
    );

    plan = plan.addStep(
      step('开始实施', now.add(const Duration(days: 2))),
      now: now.add(const Duration(hours: 2)),
    );

    expect(plan.lifecycle, PlanLifecycle.active);
    expect(plan.progress, 50);
    expect(plan.endedAt, isNull);
    expect(() => plan.removeStep(plan.steps.first.id), returnsNormally);
    final singleStepPlan = Plan.create(
      title: '单步计划',
      goal: '保留执行路径',
      startAt: now,
      steps: [step('唯一步骤', now.add(const Duration(days: 1)))],
      now: now,
    );
    expect(
      () => singleStepPlan.removeStep(singleStepPlan.steps.single.id),
      throwsStateError,
    );
  });

  test('early step can be overdue while overall plan remains in progress', () {
    final plan = Plan.create(
      title: '实施项目',
      goal: '完成项目交付',
      startAt: now.subtract(const Duration(days: 2)),
      steps: [
        step('完成项目创建', now.subtract(const Duration(days: 1))),
        step('开始实施', now.add(const Duration(days: 2))),
      ],
      now: now.subtract(const Duration(days: 2)),
    );

    expect(plan.steps.first.statusAt(now), PlanStepStatus.overdue);
    expect(plan.statusAt(now), PlanStatus.inProgress);
    expect(plan.statusAt(now.add(const Duration(days: 3))), PlanStatus.overdue);
  });

  test('step validation rejects empty, pre-start and decreasing timelines', () {
    expect(
      () => Plan.create(
        title: '空计划',
        goal: '无步骤',
        startAt: now,
        steps: const [],
        now: now,
      ),
      throwsArgumentError,
    );
    expect(
      () => Plan.create(
        title: '错误时间',
        goal: '步骤早于开始',
        startAt: now,
        steps: [step('第一步', now.subtract(const Duration(minutes: 1)))],
        now: now,
      ),
      throwsArgumentError,
    );
    expect(
      () => Plan.create(
        title: '倒序时间',
        goal: '步骤时间倒序',
        startAt: now,
        steps: [
          step('第一步', now.add(const Duration(days: 2))),
          step('第二步', now.add(const Duration(days: 1))),
        ],
        now: now,
      ),
      throwsArgumentError,
    );
  });

  test('plans repository persists steps and completion results', () async {
    final repository = PlansRepository(StorageService());
    var plan = Plan.create(
      title: '实施项目',
      goal: '完成项目交付',
      startAt: now,
      steps: [
        step(
          '完成项目创建',
          now.add(const Duration(days: 1)),
          reminderEnabled: true,
          reminderMinutesBefore: 60,
        ),
        step('开始实施', now.add(const Duration(days: 5))),
      ],
      now: now,
    );
    plan = plan.completeStep(
      plan.steps.first.id,
      note: '项目仓库已创建',
      now: now.add(const Duration(hours: 1)),
    );

    await repository.savePlans([plan]);
    final restored = await repository.loadPlans();

    expect(restored, hasLength(1));
    expect(restored.single.steps, hasLength(2));
    expect(restored.single.progress, 50);
    expect(restored.single.steps.first.completionNote, '项目仓库已创建');
    expect(restored.single.steps.first.reminderMinutesBefore, 60);
  });

  test(
      'legacy single-deadline plan migrates to one step and keeps progress event',
      () {
    final legacy = <String, dynamic>{
      'id': 'legacy-plan',
      'title': '旧计划',
      'goal': '完成旧目标',
      'startAt': now.toIso8601String(),
      'deadline': now.add(const Duration(days: 3)).toIso8601String(),
      'reminderEnabled': true,
      'reminderMinutesBefore': 1440,
      'progress': 60,
      'lifecycle': 'active',
      'createdAt': now.toIso8601String(),
      'updatedAt': now.add(const Duration(hours: 1)).toIso8601String(),
      'timeline': <dynamic>[],
    };

    final migrated = Plan.fromJson(legacy);

    expect(migrated.steps, hasLength(1));
    expect(migrated.steps.single.id, 'legacy-plan-legacy-step');
    expect(migrated.steps.single.title, '完成旧目标');
    expect(migrated.steps.single.reminderEnabled, isTrue);
    expect(migrated.progress, 0);
    expect(migrated.timeline.single.type, PlanTimelineEventType.stepsUpdated);
    expect(migrated.timeline.single.progress, 60);
    expect(migrated.toJson().containsKey('steps'), isTrue);
    expect(migrated.toJson().containsKey('reminderEnabled'), isFalse);
  });

  test('loading legacy reminder cancels the old plan-level notification',
      () async {
    final current = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'gitnote_plans': jsonEncode([
        {
          'id': 'legacy-reminder-plan',
          'title': '旧提醒计划',
          'goal': '迁移提醒',
          'startAt': current.toIso8601String(),
          'deadline': current.add(const Duration(days: 2)).toIso8601String(),
          'reminderEnabled': true,
          'reminderMinutesBefore': 60,
          'progress': 0,
          'lifecycle': 'active',
          'createdAt': current.toIso8601String(),
          'updatedAt': current.toIso8601String(),
          'timeline': <dynamic>[],
        },
      ]),
    });
    final reminderService = _FakePlanReminderService();
    final notifier = PlanNotifier(
      PlansRepository(StorageService()),
      reminderService,
    );
    while (notifier.state.isLoading) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(reminderService.cancelled, contains('plan-legacy-reminder-plan'));
    expect(
      reminderService.scheduled.single.id,
      startsWith('plan-legacy-reminder-plan-step-'),
    );
    notifier.dispose();
  });

  test('step reminder in current minute is scheduled with a short buffer',
      () async {
    final reminderService = _FakePlanReminderService();
    final notifier = PlanNotifier(
      PlansRepository(StorageService()),
      reminderService,
    );
    while (notifier.state.isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    final current = DateTime.now();
    final selectedMinute = DateTime(
      current.year,
      current.month,
      current.day,
      current.hour,
      current.minute,
    );
    final plan = Plan.create(
      title: '当前分钟计划',
      goal: '验证马上提醒',
      startAt: selectedMinute.subtract(const Duration(minutes: 1)),
      steps: [
        PlanStep(
          title: '当前分钟步骤',
          targetAt: selectedMinute,
          reminderEnabled: true,
        ),
      ],
      now: current,
    );

    await notifier.createPlan(plan);

    expect(reminderService.scheduled, hasLength(1));
    final fireAt = reminderService.scheduled.single.time;
    expect(fireAt.isAfter(DateTime.now()), isTrue);
    expect(fireAt.difference(DateTime.now()).inSeconds, lessThanOrEqualTo(10));
    notifier.dispose();
  });

  test('windows plan step reminder reaches the alarm stream', () async {
    if (!Platform.isWindows) return;
    final reminderService = ReminderService(StorageService());
    final notifier = PlanNotifier(
      PlansRepository(StorageService()),
      reminderService,
    );
    while (notifier.state.isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    final current = DateTime.now();
    final alarmFuture = reminderService.windowsAlarmStream.first.timeout(
      const Duration(seconds: 8),
    );
    final plan = Plan.create(
      title: 'Windows 到期计划',
      goal: '验证步骤提醒弹出',
      startAt: current,
      steps: [
        PlanStep(
          title: '到期步骤',
          targetAt: current.add(const Duration(seconds: 1)),
          reminderEnabled: true,
        ),
      ],
      now: current,
    );

    try {
      await notifier.createPlan(plan);
      final fired = await alarmFuture;
      expect(fired.id, 'plan-${plan.id}-step-${plan.steps.single.id}');
      expect(fired.title, 'Windows 到期计划 · 到期步骤');
    } finally {
      notifier.dispose();
      reminderService.dispose();
    }
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('plan without step reminders does not initialize notification work',
      () async {
    final reminderService = _FakePlanReminderService();
    final notifier = PlanNotifier(
      PlansRepository(StorageService()),
      reminderService,
    );
    while (notifier.state.isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    final current = DateTime.now();
    final plan = Plan.create(
      title: '静默计划',
      goal: '不申请通知权限',
      startAt: current,
      steps: [
        step('静默步骤', current.add(const Duration(days: 2))),
      ],
      now: current,
    );

    await notifier.createPlan(plan);

    expect(reminderService.scheduled, isEmpty);
    expect(reminderService.cancelled, isEmpty);
    notifier.dispose();
  });

  test('notifier cancels removed steps and all reminders on termination',
      () async {
    final reminderService = _FakePlanReminderService();
    final notifier = PlanNotifier(
      PlansRepository(StorageService()),
      reminderService,
    );
    while (notifier.state.isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    final current = DateTime.now();
    final plan = Plan.create(
      title: '实施项目',
      goal: '完成项目交付',
      startAt: current,
      steps: [
        step(
          '完成项目创建',
          current.add(const Duration(days: 1)),
          reminderEnabled: true,
        ),
        step(
          '开始实施',
          current.add(const Duration(days: 2)),
          reminderEnabled: true,
        ),
      ],
      now: current,
    );
    await notifier.createPlan(plan);

    await notifier.removeStep(plan.id, plan.steps.first.id);
    expect(
      reminderService.cancelled,
      contains('plan-${plan.id}-step-${plan.steps.first.id}'),
    );

    await notifier.terminatePlan(plan.id, reason: '目标取消');
    expect(
      reminderService.cancelled,
      contains('plan-${plan.id}-step-${plan.steps.last.id}'),
    );
    notifier.dispose();
  });

  test('notifier schedules each step and syncs complete and reopen reminders',
      () async {
    final reminderService = _FakePlanReminderService();
    final notifier = PlanNotifier(
      PlansRepository(StorageService()),
      reminderService,
    );
    while (notifier.state.isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    final current = DateTime.now();
    final plan = Plan.create(
      title: '实施项目',
      goal: '完成项目交付',
      startAt: current,
      steps: [
        step(
          '完成项目创建',
          current.add(const Duration(days: 1)),
          reminderEnabled: true,
          reminderMinutesBefore: 60,
        ),
        step(
          '开始实施',
          current.add(const Duration(days: 2)),
          reminderEnabled: true,
          reminderMinutesBefore: 1440,
        ),
      ],
      now: current,
    );

    await notifier.createPlan(plan);
    expect(reminderService.scheduled, hasLength(2));
    expect(
      reminderService.scheduled.map((item) => item.id),
      containsAll([
        'plan-${plan.id}-step-${plan.steps[0].id}',
        'plan-${plan.id}-step-${plan.steps[1].id}',
      ]),
    );

    await notifier.completeStep(plan.id, plan.steps[1].id);
    expect(
      reminderService.cancelled,
      contains('plan-${plan.id}-step-${plan.steps[1].id}'),
    );

    await notifier.reopenStep(plan.id, plan.steps[1].id);
    expect(
      reminderService.scheduled
          .where((item) => item.id.endsWith(plan.steps[1].id))
          .length,
      greaterThanOrEqualTo(2),
    );
    notifier.dispose();
  });
}
