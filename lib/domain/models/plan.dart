import 'package:uuid/uuid.dart';

const Object _planUnset = Object();

/// 计划在未结束时由时间自动推导“未开始、进行中、已逾期”，这里只持久化用户明确选择的生命周期。
enum PlanLifecycle { active, completed, terminated }

/// 计划详情和筛选使用的即时状态。
enum PlanStatus { notStarted, inProgress, overdue, completed, terminated }

/// 步骤状态由完成时间和预计完成时间即时计算，不额外持久化易失状态。
enum PlanStepStatus { pending, overdue, completed }

/// 时间轴事件记录计划和步骤从创建到结束期间发生的关键业务动作。
enum PlanTimelineEventType {
  created,
  detailsUpdated,
  stepsUpdated,
  stepCompleted,
  stepReopened,
  progressUpdated,
  recordAdded,
  completed,
  terminated,
}

/// 2026-07-15 20:10:00（北京时间）：计划步骤承载预计时间、独立提醒和实际完成结果。
class PlanStep {
  final String id;
  final String title;
  final DateTime targetAt;
  final bool reminderEnabled;
  final int reminderMinutesBefore;
  final DateTime? completedAt;
  final String? completionNote;

  PlanStep({
    String? id,
    required this.title,
    required this.targetAt,
    this.reminderEnabled = true,
    this.reminderMinutesBefore = 0,
    this.completedAt,
    this.completionNote,
  }) : id = id ?? const Uuid().v4();

  /// 已完成优先于时间判断；未完成且达到预计时间后显示步骤逾期。
  PlanStepStatus statusAt(DateTime now) {
    if (completedAt != null) return PlanStepStatus.completed;
    if (!now.isBefore(targetAt)) return PlanStepStatus.overdue;
    return PlanStepStatus.pending;
  }

  /// 步骤提醒关闭时不生成调度时间，否则按预计完成时间向前偏移。
  DateTime? get reminderAt => reminderEnabled
      ? targetAt.subtract(Duration(minutes: reminderMinutesBefore))
      : null;

  /// 步骤完成时固定实际完成时间和可选说明，重复完成不产生新对象。
  PlanStep complete({String? note, DateTime? now}) {
    if (completedAt != null) return this;
    return copyWith(
      completedAt: now ?? DateTime.now(),
      completionNote: note?.trim(),
    );
  }

  /// 撤销完成会同时清除实际完成时间和完成说明，使步骤重新进入待完成或逾期状态。
  PlanStep reopen() {
    if (completedAt == null) return this;
    return copyWith(completedAt: null, completionNote: null);
  }

  /// 编辑器比较步骤业务字段时忽略对象身份，避免未修改表单也写入步骤变更事件。
  bool hasSameContent(PlanStep other) {
    return id == other.id &&
        title.trim() == other.title.trim() &&
        targetAt == other.targetAt &&
        reminderEnabled == other.reminderEnabled &&
        reminderMinutesBefore == other.reminderMinutesBefore &&
        completedAt == other.completedAt &&
        completionNote == other.completionNote;
  }

  /// 复制步骤时允许显式清空完成时间和说明。
  PlanStep copyWith({
    String? title,
    DateTime? targetAt,
    bool? reminderEnabled,
    int? reminderMinutesBefore,
    Object? completedAt = _planUnset,
    Object? completionNote = _planUnset,
  }) {
    return PlanStep(
      id: id,
      title: title ?? this.title,
      targetAt: targetAt ?? this.targetAt,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      completedAt: identical(completedAt, _planUnset)
          ? this.completedAt
          : completedAt as DateTime?,
      completionNote: identical(completionNote, _planUnset)
          ? this.completionNote
          : completionNote as String?,
    );
  }

  /// 将步骤完整业务状态转换为本地 JSON 数据。
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title.trim(),
      'targetAt': targetAt.toIso8601String(),
      'reminderEnabled': reminderEnabled,
      'reminderMinutesBefore': reminderMinutesBefore,
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      if (completionNote != null && completionNote!.trim().isNotEmpty)
        'completionNote': completionNote!.trim(),
    };
  }

  /// 从本地 JSON 恢复步骤，缺失提醒字段时使用关闭提醒的安全默认值。
  factory PlanStep.fromJson(Map<String, dynamic> json) {
    return PlanStep(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      targetAt: DateTime.parse(json['targetAt'] as String),
      reminderEnabled: json['reminderEnabled'] as bool? ?? true,
      reminderMinutesBefore:
          (json['reminderMinutesBefore'] as num?)?.toInt() ?? 0,
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      completionNote: json['completionNote'] as String?,
    );
  }
}

/// 2026-07-15 20:10:00（北京时间）：记录计划或步骤的一次业务动作，供执行动态按时间回放。
class PlanTimelineEvent {
  final String id;
  final PlanTimelineEventType type;
  final DateTime occurredAt;
  final String? note;
  final int? progress;
  final String? stepId;
  final String? stepTitle;

  PlanTimelineEvent({
    String? id,
    required this.type,
    required this.occurredAt,
    this.note,
    this.progress,
    this.stepId,
    this.stepTitle,
  }) : id = id ?? const Uuid().v4();

  /// 将执行动态转换为可持久化数据。
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'occurredAt': occurredAt.toIso8601String(),
      if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      if (progress != null) 'progress': progress,
      if (stepId != null) 'stepId': stepId,
      if (stepTitle != null && stepTitle!.trim().isNotEmpty)
        'stepTitle': stepTitle!.trim(),
    };
  }

  /// 从本地数据恢复执行动态，未知类型按普通执行记录处理，避免异常事件阻断整个计划读取。
  factory PlanTimelineEvent.fromJson(Map<String, dynamic> json) {
    return PlanTimelineEvent(
      id: json['id'] as String?,
      type: PlanTimelineEventType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => PlanTimelineEventType.recordAdded,
      ),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      note: json['note'] as String?,
      progress: (json['progress'] as num?)?.toInt(),
      stepId: json['stepId'] as String?,
      stepTitle: json['stepTitle'] as String?,
    );
  }
}

/// 2026-07-15 20:10:00（北京时间）：计划由唯一目标和有序步骤组成，进度与最终截止时间均由步骤派生。
class Plan {
  final String id;
  final String title;
  final String goal;
  final DateTime startAt;
  final List<PlanStep> steps;
  final PlanLifecycle lifecycle;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? endedAt;
  final List<PlanTimelineEvent> timeline;

  Plan({
    String? id,
    required this.title,
    required this.goal,
    required this.startAt,
    required List<PlanStep> steps,
    this.lifecycle = PlanLifecycle.active,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.endedAt,
    List<PlanTimelineEvent> timeline = const [],
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        steps = List.unmodifiable(steps),
        timeline = List.unmodifiable(timeline) {
    validateSteps(startAt: startAt, steps: steps);
  }

  /// 创建计划时要求至少一个合法步骤，并写入计划创建动态作为历史起点。
  factory Plan.create({
    required String title,
    required String goal,
    required DateTime startAt,
    required List<PlanStep> steps,
    DateTime? now,
  }) {
    final occurredAt = now ?? DateTime.now();
    return Plan(
      title: title.trim(),
      goal: goal.trim(),
      startAt: startAt,
      steps: steps,
      createdAt: occurredAt,
      updatedAt: occurredAt,
      timeline: [
        PlanTimelineEvent(
          type: PlanTimelineEventType.created,
          occurredAt: occurredAt,
        ),
      ],
    );
  }

  /// 整体进度按已完成步骤数量平均计算，所有步骤贡献相同权重。
  int get progress => (steps.where((step) => step.completedAt != null).length /
          steps.length *
          100)
      .round();

  /// 步骤时间已校验为递增，因此最后一步的预计完成时间就是计划最终截止时间。
  DateTime get deadline => steps.last.targetAt;

  /// 返回顺序中的第一个未完成步骤，用于卡片和详情概览展示下一步。
  PlanStep? get nextStep {
    for (final step in steps) {
      if (step.completedAt == null) return step;
    }
    return null;
  }

  /// 只有进行中的计划允许新增记录、完成步骤或终止；已完成计划可通过撤销步骤恢复。
  bool get isActive => lifecycle == PlanLifecycle.active;

  /// 已终止和已完成状态优先；早期步骤逾期只标记步骤，整体到最终截止时间后才逾期。
  PlanStatus statusAt(DateTime now) {
    if (lifecycle == PlanLifecycle.terminated) return PlanStatus.terminated;
    if (lifecycle == PlanLifecycle.completed) return PlanStatus.completed;
    if (now.isBefore(startAt)) return PlanStatus.notStarted;
    if (!now.isBefore(deadline)) return PlanStatus.overdue;
    return PlanStatus.inProgress;
  }

  /// 校验步骤标题、提醒范围、开始时间和时间轴顺序，领域层拒绝任何无法形成有效时间轴的数据。
  static void validateSteps({
    required DateTime startAt,
    required List<PlanStep> steps,
  }) {
    if (steps.isEmpty) {
      throw ArgumentError('A plan must contain at least one step.');
    }
    DateTime? previousTarget;
    for (final step in steps) {
      if (step.title.trim().isEmpty) {
        throw ArgumentError('Plan step title cannot be empty.');
      }
      if (step.targetAt.isBefore(startAt)) {
        throw ArgumentError('Plan step target cannot be before plan start.');
      }
      if (previousTarget != null && step.targetAt.isBefore(previousTarget)) {
        throw ArgumentError('Plan step targets must be nondecreasing.');
      }
      if (step.reminderEnabled &&
          (step.reminderMinutesBefore < 0 ||
              step.reminderMinutesBefore > 525600)) {
        throw ArgumentError('Plan step reminder minutes are invalid.');
      }
      previousTarget = step.targetAt;
    }
  }

  /// 编辑计划标题、目标、开始时间和完整步骤列表，并按真实变化写入相邻的业务动态。
  Plan updatePlan({
    required String title,
    required String goal,
    required DateTime startAt,
    required List<PlanStep> steps,
    DateTime? now,
  }) {
    if (lifecycle == PlanLifecycle.terminated) return this;
    validateSteps(startAt: startAt, steps: steps);
    final normalizedTitle = title.trim();
    final normalizedGoal = goal.trim();
    final detailsChanged = normalizedTitle != this.title ||
        normalizedGoal != this.goal ||
        startAt != this.startAt;
    final stepsChanged = !_haveSameSteps(this.steps, steps);
    if (!detailsChanged && !stepsChanged) return this;

    final occurredAt = now ?? DateTime.now();
    final allCompleted = steps.every((step) => step.completedAt != null);
    final nextLifecycle =
        allCompleted ? PlanLifecycle.completed : PlanLifecycle.active;
    final events = [...timeline];
    if (detailsChanged) {
      events.add(PlanTimelineEvent(
        type: PlanTimelineEventType.detailsUpdated,
        occurredAt: occurredAt,
      ));
    }
    if (stepsChanged) {
      events.add(PlanTimelineEvent(
        type: PlanTimelineEventType.stepsUpdated,
        occurredAt: occurredAt,
      ));
    }
    if (lifecycle != PlanLifecycle.completed &&
        nextLifecycle == PlanLifecycle.completed) {
      events.add(PlanTimelineEvent(
        type: PlanTimelineEventType.completed,
        occurredAt: occurredAt,
        progress: 100,
      ));
    }

    return Plan(
      id: id,
      title: normalizedTitle,
      goal: normalizedGoal,
      startAt: startAt,
      steps: steps,
      lifecycle: nextLifecycle,
      createdAt: createdAt,
      updatedAt: occurredAt,
      endedAt: nextLifecycle == PlanLifecycle.completed
          ? endedAt ?? occurredAt
          : null,
      timeline: events,
    );
  }

  /// 在计划末尾增加一个未完成步骤；已完成计划会自动恢复为进行中。
  Plan addStep(PlanStep step, {DateTime? now}) {
    return updatePlan(
      title: title,
      goal: goal,
      startAt: startAt,
      steps: [...steps, step],
      now: now,
    );
  }

  /// 更新指定步骤的标题、时间或提醒配置，并保持步骤原有位置。
  Plan updateStep(PlanStep updated, {DateTime? now}) {
    final index = steps.indexWhere((step) => step.id == updated.id);
    if (index < 0) throw StateError('Plan step not found: ${updated.id}');
    final nextSteps = [...steps]..[index] = updated;
    return updatePlan(
      title: title,
      goal: goal,
      startAt: startAt,
      steps: nextSteps,
      now: now,
    );
  }

  /// 删除指定步骤；最后一个步骤不可删除，避免计划失去执行路径。
  Plan removeStep(String stepId, {DateTime? now}) {
    if (steps.length == 1) {
      throw StateError('The last plan step cannot be removed.');
    }
    if (!steps.any((step) => step.id == stepId)) {
      throw StateError('Plan step not found: $stepId');
    }
    return updatePlan(
      title: title,
      goal: goal,
      startAt: startAt,
      steps: steps.where((step) => step.id != stepId).toList(),
      now: now,
    );
  }

  /// 根据步骤标识列表重排时间轴；保存前仍需满足新的时间顺序递增规则。
  Plan reorderSteps(List<String> orderedStepIds, {DateTime? now}) {
    if (orderedStepIds.length != steps.length ||
        orderedStepIds.toSet().length != steps.length) {
      throw ArgumentError('Reordered step ids do not match current steps.');
    }
    final byId = {for (final step in steps) step.id: step};
    final reordered = orderedStepIds.map((id) {
      final step = byId[id];
      if (step == null) throw StateError('Plan step not found: $id');
      return step;
    }).toList();
    return updatePlan(
      title: title,
      goal: goal,
      startAt: startAt,
      steps: reordered,
      now: now,
    );
  }

  /// 完成任意未完成步骤并写入步骤动态；最后一步完成时自动完成整个计划。
  Plan completeStep(String stepId, {String? note, DateTime? now}) {
    if (!isActive) return this;
    final index = steps.indexWhere((step) => step.id == stepId);
    if (index < 0) throw StateError('Plan step not found: $stepId');
    final current = steps[index];
    if (current.completedAt != null) return this;

    final occurredAt = now ?? DateTime.now();
    final completedStep = current.complete(note: note, now: occurredAt);
    final nextSteps = [...steps]..[index] = completedStep;
    final allCompleted = nextSteps.every((step) => step.completedAt != null);
    final events = [
      ...timeline,
      PlanTimelineEvent(
        type: PlanTimelineEventType.stepCompleted,
        occurredAt: occurredAt,
        stepId: current.id,
        stepTitle: current.title,
        note: note?.trim(),
      ),
      if (allCompleted)
        PlanTimelineEvent(
          type: PlanTimelineEventType.completed,
          occurredAt: occurredAt,
          progress: 100,
        ),
    ];

    return Plan(
      id: id,
      title: title,
      goal: goal,
      startAt: startAt,
      steps: nextSteps,
      lifecycle: allCompleted ? PlanLifecycle.completed : PlanLifecycle.active,
      createdAt: createdAt,
      updatedAt: occurredAt,
      endedAt: allCompleted ? occurredAt : null,
      timeline: events,
    );
  }

  /// 撤销已完成步骤并记录动态；自动完成的计划会恢复为进行中并清除结束时间。
  Plan reopenStep(String stepId, {DateTime? now}) {
    if (lifecycle == PlanLifecycle.terminated) return this;
    final index = steps.indexWhere((step) => step.id == stepId);
    if (index < 0) throw StateError('Plan step not found: $stepId');
    final current = steps[index];
    if (current.completedAt == null) return this;

    final occurredAt = now ?? DateTime.now();
    final nextSteps = [...steps]..[index] = current.reopen();
    return Plan(
      id: id,
      title: title,
      goal: goal,
      startAt: startAt,
      steps: nextSteps,
      lifecycle: PlanLifecycle.active,
      createdAt: createdAt,
      updatedAt: occurredAt,
      endedAt: null,
      timeline: [
        ...timeline,
        PlanTimelineEvent(
          type: PlanTimelineEventType.stepReopened,
          occurredAt: occurredAt,
          stepId: current.id,
          stepTitle: current.title,
        ),
      ],
    );
  }

  /// 添加计划级执行记录，不与具体步骤绑定，用于沉淀跨步骤问题和推进说明。
  Plan addRecord(String note, {DateTime? now}) {
    if (!isActive || note.trim().isEmpty) return this;
    final occurredAt = now ?? DateTime.now();
    return copyWith(
      updatedAt: occurredAt,
      timeline: [
        ...timeline,
        PlanTimelineEvent(
          type: PlanTimelineEventType.recordAdded,
          occurredAt: occurredAt,
          note: note.trim(),
        ),
      ],
    );
  }

  /// 终止计划保留步骤完成情况和全部历史，并停止后续所有步骤提醒。
  Plan terminate({String? reason, DateTime? now}) {
    if (!isActive) return this;
    final occurredAt = now ?? DateTime.now();
    return copyWith(
      lifecycle: PlanLifecycle.terminated,
      endedAt: occurredAt,
      updatedAt: occurredAt,
      timeline: [
        ...timeline,
        PlanTimelineEvent(
          type: PlanTimelineEventType.terminated,
          occurredAt: occurredAt,
          progress: progress,
          note: reason?.trim(),
        ),
      ],
    );
  }

  /// 复制计划时允许显式清空结束时间，并重新校验步骤时间轴。
  Plan copyWith({
    String? title,
    String? goal,
    DateTime? startAt,
    List<PlanStep>? steps,
    PlanLifecycle? lifecycle,
    DateTime? updatedAt,
    Object? endedAt = _planUnset,
    List<PlanTimelineEvent>? timeline,
  }) {
    return Plan(
      id: id,
      title: title ?? this.title,
      goal: goal ?? this.goal,
      startAt: startAt ?? this.startAt,
      steps: steps ?? this.steps,
      lifecycle: lifecycle ?? this.lifecycle,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      endedAt:
          identical(endedAt, _planUnset) ? this.endedAt : endedAt as DateTime?,
      timeline: timeline ?? this.timeline,
    );
  }

  /// 将计划和有序步骤转换为本地 JSON；进度与截止时间不重复持久化，避免派生值不一致。
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'goal': goal,
      'startAt': startAt.toIso8601String(),
      'steps': steps.map((step) => step.toJson()).toList(),
      'lifecycle': lifecycle.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
      'timeline': timeline.map((event) => event.toJson()).toList(),
    };
  }

  /// 从新结构恢复步骤计划，并把第一版单截止时间计划无损迁移为单步骤计划。
  factory Plan.fromJson(Map<String, dynamic> json) {
    final planId = json['id'] as String;
    final createdAt = DateTime.parse(json['createdAt'] as String);
    final updatedAt = DateTime.parse(
      json['updatedAt'] as String? ?? createdAt.toIso8601String(),
    );
    final rawTimeline = json['timeline'] as List<dynamic>? ?? const [];
    final restoredTimeline = rawTimeline
        .map((item) => PlanTimelineEvent.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
    final parsedLifecycle = PlanLifecycle.values.firstWhere(
      (value) => value.name == json['lifecycle'],
      orElse: () => PlanLifecycle.active,
    );

    final rawSteps = json['steps'] as List<dynamic>?;
    late final List<PlanStep> restoredSteps;
    if (rawSteps != null && rawSteps.isNotEmpty) {
      restoredSteps = rawSteps
          .map((item) => PlanStep.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
    } else {
      final legacyProgress = (json['progress'] as num?)?.toInt() ?? 0;
      final legacyCompleted = parsedLifecycle == PlanLifecycle.completed;
      final legacyEndedAt = json['endedAt'] ?? json['completedAt'];
      final legacyStepTitle = (json['goal'] as String?)?.trim();
      restoredSteps = [
        PlanStep(
          id: '$planId-legacy-step',
          title: legacyStepTitle == null || legacyStepTitle.isEmpty
              ? json['title'] as String
              : legacyStepTitle,
          targetAt: DateTime.parse(json['deadline'] as String),
          reminderEnabled: json['reminderEnabled'] as bool? ?? false,
          reminderMinutesBefore:
              (json['reminderMinutesBefore'] as num?)?.toInt() ?? 0,
          completedAt: legacyCompleted
              ? DateTime.parse(
                  (legacyEndedAt ?? updatedAt.toIso8601String()) as String,
                )
              : null,
        ),
      ];
      restoredTimeline.add(
        PlanTimelineEvent(
          id: '$planId-legacy-migration',
          type: PlanTimelineEventType.stepsUpdated,
          occurredAt: updatedAt,
          progress: legacyProgress.clamp(0, 100),
        ),
      );
    }

    final allCompleted = restoredSteps.every(
      (step) => step.completedAt != null,
    );
    final lifecycle = parsedLifecycle == PlanLifecycle.terminated
        ? PlanLifecycle.terminated
        : allCompleted
            ? PlanLifecycle.completed
            : PlanLifecycle.active;
    final endedAtValue = json['endedAt'] ?? json['completedAt'];

    return Plan(
      id: planId,
      title: json['title'] as String,
      goal: json['goal'] as String? ?? '',
      startAt: DateTime.parse(json['startAt'] as String),
      steps: restoredSteps,
      lifecycle: lifecycle,
      createdAt: createdAt,
      updatedAt: updatedAt,
      endedAt: lifecycle == PlanLifecycle.active || endedAtValue == null
          ? null
          : DateTime.parse(endedAtValue as String),
      timeline: restoredTimeline.isEmpty
          ? [
              PlanTimelineEvent(
                type: PlanTimelineEventType.created,
                occurredAt: createdAt,
              ),
            ]
          : restoredTimeline,
    );
  }

  /// 比较两个有序步骤集合的业务内容和顺序。
  static bool _haveSameSteps(List<PlanStep> left, List<PlanStep> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!left[index].hasSameContent(right[index])) return false;
    }
    return true;
  }
}
