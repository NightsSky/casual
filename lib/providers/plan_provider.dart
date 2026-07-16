import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/plans_repository.dart';
import '../data/services/storage_service.dart';
import '../domain/models/plan.dart';
import '../domain/models/reminder.dart';
import '../services/reminder_service.dart';
import 'reminder_provider.dart';

final plansRepositoryProvider = Provider<PlansRepository>((ref) {
  return PlansRepository(StorageService());
});

final planProvider = StateNotifierProvider<PlanNotifier, PlanState>((ref) {
  return PlanNotifier(
    ref.watch(plansRepositoryProvider),
    ref.watch(reminderServiceProvider),
  );
});

/// 2026-07-15 20:30:00（北京时间）：承载计划页面加载状态、计划快照和最近一次持久化错误。
class PlanState {
  final List<Plan> plans;
  final bool isLoading;
  final String? error;

  const PlanState({
    this.plans = const [],
    this.isLoading = false,
    this.error,
  });

  /// 复制页面状态，clearError 用于下一次成功操作后清除旧错误。
  PlanState copyWith({
    List<Plan>? plans,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return PlanState(
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// 2026-07-15 20:30:00（北京时间）：统一处理多步骤计划持久化、自动状态流转和逐步骤提醒调度。
class PlanNotifier extends StateNotifier<PlanState> {
  final PlansRepository _repository;
  final ReminderService _reminderService;

  PlanNotifier(this._repository, this._reminderService)
      : super(const PlanState(isLoading: true)) {
    loadPlans();
  }

  /// 应用启动时恢复本地计划，并重新注册所有仍有效的未完成步骤提醒。
  Future<void> loadPlans() async {
    try {
      final plans = await _repository.loadPlans();
      plans.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      state = state.copyWith(
        plans: plans,
        isLoading: false,
        clearError: true,
      );
      for (final plan in plans) {
        await _syncPlanRemindersSafely(
          current: plan,
          restoreExisting: true,
        );
      }
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  /// 新建计划先保存完整步骤快照，再为开启提醒的未完成步骤逐一注册通知。
  Future<void> createPlan(Plan plan) async {
    await _commit([plan, ...state.plans]);
    await _syncPlanRemindersSafely(current: plan);
  }

  /// 编辑计划标题、目标、开始时间和步骤集合，提醒按编辑前后差异同步取消或覆盖。
  Future<void> updatePlanDetails({
    required String id,
    required String title,
    required String goal,
    required DateTime startAt,
    required List<PlanStep> steps,
  }) async {
    final current = _planById(id);
    final updated = current.updatePlan(
      title: title,
      goal: goal,
      startAt: startAt,
      steps: steps,
    );
    await _replaceAndSync(current, updated);
  }

  /// 在计划末尾新增步骤；已完成计划会因新增未完成步骤自动恢复为进行中。
  Future<void> addStep(String planId, PlanStep step) async {
    final current = _planById(planId);
    await _replaceAndSync(current, current.addStep(step));
  }

  /// 更新指定步骤的标题、预计时间和提醒配置。
  Future<void> updateStep(String planId, PlanStep step) async {
    final current = _planById(planId);
    await _replaceAndSync(current, current.updateStep(step));
  }

  /// 删除指定步骤并取消对应提醒；领域层禁止删除计划的最后一步。
  Future<void> removeStep(String planId, String stepId) async {
    final current = _planById(planId);
    await _replaceAndSync(current, current.removeStep(stepId));
  }

  /// 按步骤标识顺序重排计划时间轴，时间不递增时由领域层拒绝保存。
  Future<void> reorderSteps(
    String planId,
    List<String> orderedStepIds,
  ) async {
    final current = _planById(planId);
    await _replaceAndSync(current, current.reorderSteps(orderedStepIds));
  }

  /// 完成任意步骤并取消该步骤提醒；全部完成时计划自动完成。
  Future<void> completeStep(
    String planId,
    String stepId, {
    String? note,
  }) async {
    final current = _planById(planId);
    await _replaceAndSync(
      current,
      current.completeStep(stepId, note: note),
    );
  }

  /// 撤销步骤完成状态；计划会恢复进行中，并在目标时间仍有效时重新注册提醒。
  Future<void> reopenStep(String planId, String stepId) async {
    final current = _planById(planId);
    await _replaceAndSync(current, current.reopenStep(stepId));
  }

  /// 添加计划级执行记录，不改变步骤完成情况和自动进度。
  Future<void> addRecord(String id, String note) async {
    final current = _planById(id);
    await _replaceAndSync(current, current.addRecord(note));
  }

  /// 终止计划时保留步骤历史，并取消该计划全部尚未触发的步骤提醒。
  Future<void> terminatePlan(String id, {String? reason}) async {
    final current = _planById(id);
    await _replaceAndSync(current, current.terminate(reason: reason));
  }

  /// 删除计划主体和全部步骤，同时取消所有曾开启的步骤提醒。
  Future<void> deletePlan(String id) async {
    final current = _planById(id);
    final plans = state.plans.where((plan) => plan.id != id).toList();
    await _commit(plans);
    await _cancelPlanRemindersSafely(current);
  }

  /// 用最新计划替换状态列表，未发生业务变化时不重复持久化或调度提醒。
  Future<void> _replaceAndSync(Plan previous, Plan updated) async {
    if (identical(previous, updated)) return;
    final plans = state.plans
        .map((plan) => plan.id == updated.id ? updated : plan)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _commit(plans);
    await _syncPlanRemindersSafely(previous: previous, current: updated);
  }

  /// 统一保存计划快照；持久化失败时保留旧内存状态并向页面暴露错误。
  Future<void> _commit(List<Plan> plans) async {
    try {
      await _repository.savePlans(plans);
      state = state.copyWith(plans: plans, clearError: true);
    } catch (error) {
      state = state.copyWith(error: error.toString());
      rethrow;
    }
  }

  /// 按标识获取计划，传入失效标识时明确报错，避免静默更新错误对象。
  Plan _planById(String id) {
    return state.plans.firstWhere(
      (plan) => plan.id == id,
      orElse: () => throw StateError('Plan not found: $id'),
    );
  }

  /// 根据编辑前后步骤状态取消失效提醒，并覆盖注册当前仍有效的独立步骤提醒。
  Future<void> _syncPlanRemindersSafely({
    Plan? previous,
    required Plan current,
    bool restoreExisting = false,
  }) async {
    try {
      final now = DateTime.now();
      final migratedFromLegacy = current.timeline.any(
        (event) => event.id == '${current.id}-legacy-migration',
      );
      if (restoreExisting &&
          migratedFromLegacy &&
          current.steps.any((step) => step.reminderEnabled)) {
        // 第一版计划使用 plan-{id} 作为整体提醒标识，迁移后先取消旧调度，避免与步骤提醒重复触发。
        await _reminderService.cancelReminder(
          _legacyPlanReminderId(current.id),
        );
      }
      final currentById = {
        for (final step in current.steps) step.id: step,
      };
      final previousSteps = previous?.steps ??
          (restoreExisting ? current.steps : const <PlanStep>[]);

      for (final oldStep in previousSteps) {
        if (!oldStep.reminderEnabled) continue;
        final currentStep = currentById[oldStep.id];
        final shouldCancel = currentStep == null ||
            current.lifecycle != PlanLifecycle.active ||
            currentStep.completedAt != null ||
            !currentStep.reminderEnabled ||
            _resolveStepFireAt(currentStep, now) == null;
        if (shouldCancel) {
          await _reminderService.cancelReminder(
            _stepReminderId(current.id, oldStep.id),
          );
        }
      }

      if (current.lifecycle != PlanLifecycle.active) return;
      for (final step in current.steps) {
        if (!step.reminderEnabled || step.completedAt != null) continue;
        final fireAt = _resolveStepFireAt(step, now);
        if (fireAt == null) continue;
        await _reminderService.scheduleReminder(
          Reminder(
            id: _stepReminderId(current.id, step.id),
            title: '${current.title} · ${step.title}',
            time: fireAt,
            repeat: RepeatType.none,
          ),
        );
      }
    } catch (error, stackTrace) {
      // 通知权限或平台调度失败不回滚已保存的计划，避免步骤编辑内容丢失。
      debugPrint('[PlanNotifier] failed to sync plan step reminders: '
          '$error\n$stackTrace');
    }
  }

  /// 计算步骤本次有效触发点；提前提醒已错过时降级到步骤到期，选择当前分钟时留出十秒调度缓冲。
  DateTime? _resolveStepFireAt(PlanStep step, DateTime now) {
    final targetInCurrentMinute = step.targetAt.year == now.year &&
        step.targetAt.month == now.month &&
        step.targetAt.day == now.day &&
        step.targetAt.hour == now.hour &&
        step.targetAt.minute == now.minute;
    if (targetInCurrentMinute) {
      return now.add(const Duration(seconds: 10));
    }
    if (!step.targetAt.isAfter(now)) return null;
    final reminderAt = step.reminderAt!;
    return reminderAt.isAfter(now) ? reminderAt : step.targetAt;
  }

  /// 删除计划后逐一取消曾开启提醒的步骤，单个取消失败不影响已经完成的数据删除。
  Future<void> _cancelPlanRemindersSafely(Plan plan) async {
    try {
      for (final step in plan.steps) {
        if (!step.reminderEnabled) continue;
        await _reminderService.cancelReminder(
          _stepReminderId(plan.id, step.id),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[PlanNotifier] failed to cancel deleted plan reminders: '
          '$error\n$stackTrace');
    }
  }

  /// 第一版计划整体提醒标识仅用于迁移时清理旧调度。
  String _legacyPlanReminderId(String planId) => 'plan-$planId';

  /// 步骤提醒使用计划和步骤双重标识，避免同一计划内多个通知互相覆盖。
  String _stepReminderId(String planId, String stepId) {
    return 'plan-$planId-step-$stepId';
  }
}
