import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/models/plan.dart';
import '../providers/plan_provider.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';

enum _PlanFilter { all, active, overdue, completed, terminated }

enum _ReminderPreset { off, atDeadline, oneHour, oneDay, custom }

/// 2026-07-15 21:00:00（北京时间）：计划主页面在窄屏展示单列列表，在桌面宽屏展示列表与详情双栏。
class PlanPage extends ConsumerStatefulWidget {
  const PlanPage({super.key});

  @override
  ConsumerState<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends ConsumerState<PlanPage> {
  _PlanFilter _filter = _PlanFilter.all;
  String? _selectedPlanId;
  Timer? _statusRefreshTimer;

  /// 页面保持打开时每分钟刷新计划和步骤的即时状态。
  @override
  void initState() {
    super.initState();
    _statusRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// 释放状态刷新定时器。
  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    super.dispose();
  }

  /// 构建响应式计划工作区，布局只根据可用宽度切换。
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(planProvider);
    final now = DateTime.now();
    final plans = state.plans.where((plan) {
      final status = plan.statusAt(now);
      return switch (_filter) {
        _PlanFilter.all => true,
        _PlanFilter.active =>
          status == PlanStatus.notStarted || status == PlanStatus.inProgress,
        _PlanFilter.overdue => status == PlanStatus.overdue,
        _PlanFilter.completed => status == PlanStatus.completed,
        _PlanFilter.terminated => status == PlanStatus.terminated,
      };
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildFilters(context),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (state.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.error != null && state.plans.isEmpty) {
                    return _PlanLoadError(
                      message: state.error!,
                      onRetry: () =>
                          ref.read(planProvider.notifier).loadPlans(),
                    );
                  }
                  if (constraints.maxWidth >= AppBreakpoints.tablet) {
                    final selected = _selectedPlan(plans);
                    return Row(
                      children: [
                        SizedBox(
                          width: math.min(430, constraints.maxWidth * 0.4),
                          child: _PlanList(
                            plans: plans,
                            selectedPlanId: selected?.id,
                            onTap: (plan) {
                              setState(() => _selectedPlanId = plan.id);
                            },
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: selected == null
                              ? const _PlanSelectionEmpty()
                              : PlanDetailView(planId: selected.id),
                        ),
                      ],
                    );
                  }
                  return _PlanList(
                    plans: plans,
                    onTap: (plan) => _openMobileDetail(plan.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 页面标题区突出“新建计划”主操作，并说明多步骤时间轴的定位。
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.plan,
                  style: const TextStyle(
                    fontSize: AppFontSize.title,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.l10n.planPageSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFontSize.base,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          FilledButton.icon(
            key: const Key('create-plan-button'),
            onPressed: _createPlan,
            icon: const Icon(Icons.add, size: 19),
            label: Text(context.l10n.createPlan),
          ),
        ],
      ),
    );
  }

  /// 筛选栏覆盖计划整体生命周期，早期步骤逾期不会提前改变计划筛选归属。
  Widget _buildFilters(BuildContext context) {
    final labels = <_PlanFilter, String>{
      _PlanFilter.all: context.l10n.all,
      _PlanFilter.active: context.l10n.planFilterActive,
      _PlanFilter.overdue: context.l10n.planFilterOverdue,
      _PlanFilter.completed: context.l10n.planFilterCompleted,
      _PlanFilter.terminated: context.l10n.planFilterTerminated,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        children: labels.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: _filter == entry.key,
              onSelected: (_) => setState(() {
                _filter = entry.key;
                _selectedPlanId = null;
              }),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 桌面端优先保持已选计划；筛选后原计划不可见时展示列表第一项。
  Plan? _selectedPlan(List<Plan> plans) {
    if (plans.isEmpty) return null;
    for (final plan in plans) {
      if (plan.id == _selectedPlanId) return plan;
    }
    return plans.first;
  }

  /// 创建表单返回完整步骤草稿后，由领域模型统一校验并生成创建动态。
  Future<void> _createPlan() async {
    final draft = await _showPlanEditorDialog(context);
    if (draft == null || !mounted) return;
    final plan = Plan.create(
      title: draft.title,
      goal: draft.goal,
      startAt: draft.startAt,
      steps: draft.steps,
    );
    try {
      await ref.read(planProvider.notifier).createPlan(plan);
      if (!mounted) return;
      setState(() => _selectedPlanId = plan.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.planSaveSuccess)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.planOperationFailed('$error'))),
      );
    }
  }

  /// 窄屏使用标准页面导航打开详情。
  Future<void> _openMobileDetail(String planId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _MobilePlanDetailPage(planId: planId),
      ),
    );
  }
}

/// 2026-07-15 21:00:00（北京时间）：窄屏计划详情提供独立返回栏，正文与桌面详情复用同一组件。
class _MobilePlanDetailPage extends StatelessWidget {
  final String planId;

  const _MobilePlanDetailPage({required this.planId});

  /// 构建移动端详情容器。
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      appBar: AppBar(title: Text(context.l10n.plan)),
      body:
          SafeArea(child: PlanDetailView(planId: planId, popAfterDelete: true)),
    );
  }
}

/// 2026-07-15 21:00:00（北京时间）：计划列表使用惰性构建，适配大量历史计划并复用空状态。
class _PlanList extends StatelessWidget {
  final List<Plan> plans;
  final String? selectedPlanId;
  final ValueChanged<Plan> onTap;

  const _PlanList({
    required this.plans,
    required this.onTap,
    this.selectedPlanId,
  });

  /// 构建计划列表或引导创建的空状态。
  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) return const _PlanListEmpty();
    return ListView.builder(
      key: const Key('plan-list'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        return _PlanCard(
          plan: plan,
          selected: selectedPlanId == plan.id,
          onTap: () => onTap(plan),
        );
      },
    );
  }
}

/// 2026-07-15 21:00:00（北京时间）：列表卡片聚合整体状态、自动进度、下一步和最终截止时间。
class _PlanCard extends StatelessWidget {
  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard(
      {required this.plan, required this.onTap, this.selected = false});

  /// 构建可点击计划摘要卡片。
  @override
  Widget build(BuildContext context) {
    final status = plan.statusAt(DateTime.now());
    final completed =
        plan.steps.where((step) => step.completedAt != null).length;
    final dateFormat = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_Hm();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: selected ? AppColors.primaryLight : AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          key: Key('plan-card-${plan.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.borderColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: AppFontSize.lg,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _PlanStatusChip(status: status),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  plan.goal,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (plan.nextStep != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.arrow_forward_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          '${context.l10n.planNextStep}：${plan.nextStep!.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppFontSize.sm,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: plan.progress / 100,
                    minHeight: 7,
                    backgroundColor: AppColors.borderColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text(
                      '${plan.progress}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        context.l10n.planCompletedSteps(
                          completed,
                          plan.steps.length,
                        ),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppFontSize.sm,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        dateFormat.format(plan.deadline),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: AppFontSize.sm,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 2026-07-15 21:10:00（北京时间）：计划详情集中承载步骤时间轴、执行动态和生命周期操作。
class PlanDetailView extends ConsumerStatefulWidget {
  final String planId;
  final bool popAfterDelete;

  const PlanDetailView({
    super.key,
    required this.planId,
    this.popAfterDelete = false,
  });

  @override
  ConsumerState<PlanDetailView> createState() => _PlanDetailViewState();
}

class _PlanDetailViewState extends ConsumerState<PlanDetailView> {
  /// 根据计划最新快照构建详情，任何步骤操作完成后 Riverpod 会刷新同一页面。
  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(planProvider).plans;
    Plan? found;
    for (final item in plans) {
      if (item.id == widget.planId) {
        found = item;
        break;
      }
    }
    if (found == null) return const _PlanSelectionEmpty();
    final plan = found;

    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMMMd(locale).add_Hm();
    final status = plan.statusAt(DateTime.now());
    final events = [...plan.timeline]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return SingleChildScrollView(
      key: Key('plan-detail-${plan.id}'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.title,
                          style: const TextStyle(
                            fontSize: AppFontSize.xxl,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _PlanStatusChip(status: status),
                      ],
                    ),
                  ),
                  if (plan.lifecycle != PlanLifecycle.terminated)
                    IconButton(
                      key: const Key('edit-plan-button'),
                      tooltip: context.l10n.planEdit,
                      onPressed: () => _editPlan(plan),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                plan.goal,
                style: const TextStyle(
                  fontSize: AppFontSize.lg,
                  height: 1.55,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildOverview(context, plan, status, dateFormat),
              const SizedBox(height: AppSpacing.xl),
              if (plan.isActive) _buildActions(context, plan),
              if (plan.isActive) const SizedBox(height: AppSpacing.xl),
              _SectionTitle(
                icon: Icons.account_tree_outlined,
                title: context.l10n.planSteps,
              ),
              const SizedBox(height: AppSpacing.lg),
              ...List.generate(plan.steps.length, (index) {
                return _PlanStepTimelineItem(
                  plan: plan,
                  step: plan.steps[index],
                  index: index,
                  dateFormat: dateFormat,
                  isLast: index == plan.steps.length - 1,
                  onComplete: () => _completeStep(plan, plan.steps[index]),
                  onReopen: () => _reopenStep(plan, plan.steps[index]),
                );
              }),
              const SizedBox(height: AppSpacing.lg),
              _SectionTitle(
                icon: Icons.history_outlined,
                title: context.l10n.planActivity,
              ),
              const SizedBox(height: AppSpacing.lg),
              ...List.generate(events.length, (index) {
                return _TimelineItem(
                  event: events[index],
                  dateFormat: dateFormat,
                  isLast: index == events.length - 1,
                );
              }),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('delete-plan-button'),
                  onPressed: () => _deletePlan(plan),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(context.l10n.planDelete),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 概览区展示自动进度、起止时间、下一步和完成步数。
  Widget _buildOverview(
    BuildContext context,
    Plan plan,
    PlanStatus status,
    DateFormat dateFormat,
  ) {
    final completed =
        plan.steps.where((step) => step.completedAt != null).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.planOverview,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: AppFontSize.lg,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: plan.progress / 100,
                    minHeight: 10,
                    backgroundColor: AppColors.borderColor,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${plan.progress}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.planCompletedSteps(completed, plan.steps.length),
            style: const TextStyle(
              fontSize: AppFontSize.sm,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.md,
            children: [
              _OverviewValue(
                icon: Icons.play_circle_outline,
                label: context.l10n.planStartAt,
                value: dateFormat.format(plan.startAt),
              ),
              _OverviewValue(
                icon: Icons.flag_outlined,
                label: context.l10n.planFinalDeadline,
                value: dateFormat.format(plan.deadline),
              ),
              _OverviewValue(
                icon: Icons.arrow_forward_outlined,
                label: context.l10n.planNextStep,
                value: plan.nextStep?.title ?? context.l10n.planNoNextStep,
              ),
              _OverviewValue(
                icon: Icons.hourglass_bottom_outlined,
                label: context.l10n.planProgress,
                value: _deadlineSummary(context, plan, status),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 计划级操作只保留自由记录和终止，进度与完成状态完全由步骤驱动。
  Widget _buildActions(BuildContext context, Plan plan) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        OutlinedButton.icon(
          key: const Key('add-plan-record-button'),
          onPressed: () => _addRecord(plan),
          icon: const Icon(Icons.add_comment_outlined, size: 18),
          label: Text(context.l10n.planAddRecord),
        ),
        TextButton.icon(
          key: const Key('terminate-plan-button'),
          onPressed: () => _terminatePlan(plan),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          icon: const Icon(Icons.stop_circle_outlined, size: 18),
          label: Text(context.l10n.planTerminate),
        ),
      ],
    );
  }

  /// 编辑表单可调整完整步骤集合，保存后由状态层同步逐步骤提醒。
  Future<void> _editPlan(Plan plan) async {
    final draft = await _showPlanEditorDialog(context, existing: plan);
    if (draft == null || !mounted) return;
    await _runMutation(() {
      return ref.read(planProvider.notifier).updatePlanDetails(
            id: plan.id,
            title: draft.title,
            goal: draft.goal,
            startAt: draft.startAt,
            steps: draft.steps,
          );
    });
  }

  /// 完成步骤时允许填写该步骤的完成说明，并支持跳过前序步骤直接操作。
  Future<void> _completeStep(Plan plan, PlanStep step) async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) => _StepCompletionDialog(step: step),
    );
    if (note == null || !mounted) return;
    await _runMutation(
      () => ref.read(planProvider.notifier).completeStep(
            plan.id,
            step.id,
            note: note,
          ),
    );
  }

  /// 撤销步骤完成状态前进行确认，操作后自动恢复计划进度和提醒。
  Future<void> _reopenStep(Plan plan, PlanStep step) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.planReopenStep),
            content: Text(context.l10n.planConfirmReopenStep),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.confirm),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await _runMutation(
      () => ref.read(planProvider.notifier).reopenStep(plan.id, step.id),
    );
  }

  /// 执行记录不能为空，写入后作为计划级动态展示。
  Future<void> _addRecord(Plan plan) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const _RecordDialog(),
    );
    if (result == null || !mounted) return;
    await _runMutation(
      () => ref.read(planProvider.notifier).addRecord(plan.id, result),
    );
  }

  /// 终止计划保留步骤状态和历史，原因会写入执行动态。
  Future<void> _terminatePlan(Plan plan) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _PlanNoteConfirmDialog(
        title: context.l10n.planTerminate,
        message: context.l10n.planConfirmTerminate,
        hint: context.l10n.planTerminationReason,
        confirmLabel: context.l10n.planTerminate,
        destructive: true,
      ),
    );
    if (result == null || !mounted) return;
    await _runMutation(
      () => ref.read(planProvider.notifier).terminatePlan(
            plan.id,
            reason: result,
          ),
    );
  }

  /// 删除属于不可恢复操作，必须二次确认；移动端删除后退出失效详情页。
  Future<void> _deletePlan(Plan plan) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.planDelete),
            content: Text(context.l10n.planConfirmDelete(plan.title)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.delete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final success = await _runMutation(
      () => ref.read(planProvider.notifier).deletePlan(plan.id),
      successMessage: context.l10n.planDeleteSuccess,
    );
    if (success && mounted && widget.popAfterDelete) {
      Navigator.of(context).pop();
    }
  }

  /// 统一处理计划操作的成功提示和异常兜底。
  Future<bool> _runMutation(
    Future<void> Function() mutation, {
    String? successMessage,
  }) async {
    try {
      await mutation();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage ?? context.l10n.planSaveSuccess)),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.planOperationFailed('$error'))),
      );
      return false;
    }
  }
}

/// 2026-07-15 21:10:00（北京时间）：章节标题统一步骤时间轴和执行动态的视觉层级。
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  /// 构建带图标的详情章节标题。
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: const TextStyle(
            fontSize: AppFontSize.xl,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// 2026-07-15 21:10:00（北京时间）：概览字段组件保证桌面和移动端换行时保持一致结构。
class _OverviewValue extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _OverviewValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  /// 构建单个概览字段。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2026-07-15 21:20:00（北京时间）：步骤节点按计划顺序连接，展示预计时间、提醒、完成结果和操作。
class _PlanStepTimelineItem extends StatelessWidget {
  final Plan plan;
  final PlanStep step;
  final int index;
  final DateFormat dateFormat;
  final bool isLast;
  final VoidCallback onComplete;
  final VoidCallback onReopen;

  const _PlanStepTimelineItem({
    required this.plan,
    required this.step,
    required this.index,
    required this.dateFormat,
    required this.isLast,
    required this.onComplete,
    required this.onReopen,
  });

  /// 构建一个步骤时间轴节点，步骤顺序与预计时间保持一致。
  @override
  Widget build(BuildContext context) {
    final status = step.statusAt(DateTime.now());
    final completed = status == PlanStepStatus.completed;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _stepStatusColor(status),
                    shape: BoxShape.circle,
                  ),
                  child: completed
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: AppFontSize.sm,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.borderColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.bgTertiary,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: status == PlanStepStatus.overdue
                      ? AppColors.error.withValues(alpha: 0.45)
                      : AppColors.borderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.planStepNumber(index + 1),
                              style: const TextStyle(
                                fontSize: AppFontSize.sm,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              step.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: AppFontSize.lg,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _PlanStepStatusChip(status: status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _InlineInfo(
                        icon: Icons.schedule_outlined,
                        text: dateFormat.format(step.targetAt),
                      ),
                      _InlineInfo(
                        icon: step.reminderEnabled
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        text: _stepReminderLabel(context, step),
                      ),
                    ],
                  ),
                  if (step.completedAt != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      context.l10n.planStepCompletedAt(
                        dateFormat.format(step.completedAt!),
                      ),
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: AppFontSize.sm,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (step.completionNote != null &&
                        step.completionNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.bgSecondary,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(
                          step.completionNote!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (plan.lifecycle != PlanLifecycle.terminated) ...[
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerRight,
                      child: completed
                          ? TextButton.icon(
                              key: Key('reopen-plan-step-${step.id}'),
                              onPressed: onReopen,
                              icon: const Icon(Icons.undo, size: 18),
                              label: Text(context.l10n.planReopenStep),
                            )
                          : FilledButton.icon(
                              key: Key('complete-plan-step-${step.id}'),
                              onPressed: onComplete,
                              icon: const Icon(Icons.check, size: 18),
                              label: Text(context.l10n.planCompleteStep),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2026-07-15 21:20:00（北京时间）：行内信息组件用于步骤预计时间和提醒方式。
class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineInfo({required this.icon, required this.text});

  /// 构建紧凑图标文字组合。
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppFontSize.sm,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 2026-07-15 21:20:00（北京时间）：执行动态节点记录创建、编辑、步骤动作、自由记录和终止历史。
class _TimelineItem extends StatelessWidget {
  final PlanTimelineEvent event;
  final DateFormat dateFormat;
  final bool isLast;

  const _TimelineItem({
    required this.event,
    required this.dateFormat,
    required this.isLast,
  });

  /// 构建单个执行动态节点，最后一个节点不向下延伸连接线。
  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: _eventColor(event.type),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bgTertiary, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.borderColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _eventTitle(context, event),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    dateFormat.format(event.occurredAt),
                    style: const TextStyle(
                      fontSize: AppFontSize.sm,
                      color: AppColors.textPlaceholder,
                    ),
                  ),
                  if (event.note != null && event.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.bgTertiary,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: Text(
                        event.note!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 完成、终止和步骤恢复使用不同颜色帮助识别关键状态变化。
  Color _eventColor(PlanTimelineEventType type) {
    return switch (type) {
      PlanTimelineEventType.completed ||
      PlanTimelineEventType.stepCompleted =>
        AppColors.success,
      PlanTimelineEventType.terminated => AppColors.error,
      PlanTimelineEventType.stepReopened => AppColors.warning,
      _ => AppColors.textSecondary,
    };
  }

  /// 将动态类型和步骤快照映射为当前语言的业务标题。
  String _eventTitle(BuildContext context, PlanTimelineEvent event) {
    return switch (event.type) {
      PlanTimelineEventType.created => context.l10n.planTimelineCreated,
      PlanTimelineEventType.detailsUpdated =>
        context.l10n.planTimelineDetailsUpdated,
      PlanTimelineEventType.stepsUpdated => event.progress == null
          ? context.l10n.planTimelineStepsUpdated
          : context.l10n.planTimelineLegacyProgress(event.progress!),
      PlanTimelineEventType.stepCompleted =>
        context.l10n.planTimelineStepCompleted(
          event.stepTitle ?? context.l10n.planStepTitle,
        ),
      PlanTimelineEventType.stepReopened =>
        context.l10n.planTimelineStepReopened(
          event.stepTitle ?? context.l10n.planStepTitle,
        ),
      PlanTimelineEventType.progressUpdated =>
        context.l10n.planTimelineProgress(event.progress ?? 0),
      PlanTimelineEventType.recordAdded => context.l10n.planTimelineRecord,
      PlanTimelineEventType.completed => context.l10n.planTimelineCompleted,
      PlanTimelineEventType.terminated => context.l10n.planTimelineTerminated,
    };
  }
}

/// 2026-07-15 21:20:00（北京时间）：整体状态标签同时使用颜色和文字表达。
class _PlanStatusChip extends StatelessWidget {
  final PlanStatus status;

  const _PlanStatusChip({required this.status});

  /// 构建计划整体状态标签。
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PlanStatus.notStarted => AppColors.textSecondary,
      PlanStatus.inProgress => AppColors.primary,
      PlanStatus.overdue => AppColors.error,
      PlanStatus.completed => AppColors.success,
      PlanStatus.terminated => AppColors.textPlaceholder,
    };
    return _StatusBadge(
      label: _statusLabel(context, status),
      color: color,
    );
  }
}

/// 2026-07-15 21:20:00（北京时间）：步骤状态标签区分待完成、局部逾期和已完成。
class _PlanStepStatusChip extends StatelessWidget {
  final PlanStepStatus status;

  const _PlanStepStatusChip({required this.status});

  /// 构建步骤即时状态标签。
  @override
  Widget build(BuildContext context) {
    final color = _stepStatusColor(status);
    final label = switch (status) {
      PlanStepStatus.pending => context.l10n.planStepStatusPending,
      PlanStepStatus.overdue => context.l10n.planStepStatusOverdue,
      PlanStepStatus.completed => context.l10n.planStepStatusCompleted,
    };
    return _StatusBadge(label: label, color: color);
  }
}

/// 2026-07-15 21:20:00（北京时间）：通用状态徽标保持计划和步骤状态视觉一致。
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  /// 构建紧凑状态徽标。
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: AppFontSize.sm,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 2026-07-15 21:30:00（北京时间）：无计划时给出明确创建引导。
class _PlanListEmpty extends StatelessWidget {
  const _PlanListEmpty();

  /// 构建计划列表空状态。
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_note_outlined,
              size: 56,
              color: AppColors.textPlaceholder,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.planNoPlansYet,
              style: const TextStyle(
                fontSize: AppFontSize.xl,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.l10n.planCreateFirst,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2026-07-15 21:30:00（北京时间）：桌面双栏没有可选项时展示轻量占位。
class _PlanSelectionEmpty extends StatelessWidget {
  const _PlanSelectionEmpty();

  /// 构建详情选择占位。
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timeline,
            size: 48,
            color: AppColors.textPlaceholder,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.planSelectPrompt,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 2026-07-15 21:30:00（北京时间）：计划加载失败时保留重试入口。
class _PlanLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PlanLoadError({required this.message, required this.onRetry});

  /// 构建加载错误与重试操作。
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 44),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.planOperationFailed(message),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      ),
    );
  }
}

/// 将计划整体状态映射为当前语言名称。
String _statusLabel(BuildContext context, PlanStatus status) {
  return switch (status) {
    PlanStatus.notStarted => context.l10n.planStatusNotStarted,
    PlanStatus.inProgress => context.l10n.planStatusInProgress,
    PlanStatus.overdue => context.l10n.planStatusOverdue,
    PlanStatus.completed => context.l10n.planStatusCompleted,
    PlanStatus.terminated => context.l10n.planStatusTerminated,
  };
}

/// 计算整体最终截止摘要；早期步骤逾期不改变该摘要的整体口径。
String _deadlineSummary(BuildContext context, Plan plan, PlanStatus status) {
  if (status == PlanStatus.completed || status == PlanStatus.terminated) {
    return _statusLabel(context, status);
  }
  final difference = plan.deadline.difference(DateTime.now());
  if (difference.isNegative) {
    final days = math.max(1, (-difference.inMinutes / 1440).ceil());
    return context.l10n.planOverdueDays(days);
  }
  if (difference.inMinutes < 60) return context.l10n.planDueSoon;
  if (difference.inHours < 24) {
    return context.l10n.planRemainingHours(difference.inHours);
  }
  return context.l10n.planRemainingDays((difference.inHours / 24).ceil());
}

/// 步骤状态使用稳定颜色，确保局部逾期不会与整体状态混淆。
Color _stepStatusColor(PlanStepStatus status) {
  return switch (status) {
    PlanStepStatus.pending => AppColors.primary,
    PlanStepStatus.overdue => AppColors.error,
    PlanStepStatus.completed => AppColors.success,
  };
}

/// 将步骤独立提醒提前量映射为用户可读文本。
String _stepReminderLabel(BuildContext context, PlanStep step) {
  if (!step.reminderEnabled) return context.l10n.planReminderOff;
  return switch (step.reminderMinutesBefore) {
    0 => context.l10n.planReminderAtDeadline,
    60 => context.l10n.planReminderOneHourBefore,
    1440 => context.l10n.planReminderOneDayBefore,
    _ => '${step.reminderMinutesBefore} '
        '${context.l10n.reminderIntervalMinutesLabel}',
  };
}

/// 计划编辑表单返回的纯数据草稿，领域动态由 Plan.create 或 updatePlan 生成。
class _PlanDraft {
  final String title;
  final String goal;
  final DateTime startAt;
  final List<PlanStep> steps;

  const _PlanDraft({
    required this.title,
    required this.goal,
    required this.startAt,
    required this.steps,
  });
}

/// 2026-07-15 21:40:00（北京时间）：步骤编辑状态保存控制器、提醒预设和逐项校验错误。
class _StepEditorData {
  final String id;
  final TextEditingController titleController;
  final TextEditingController customMinutesController;
  DateTime targetAt;
  _ReminderPreset reminderPreset;
  final DateTime? completedAt;
  final String? completionNote;
  String? titleError;
  String? timeError;
  String? reminderError;

  _StepEditorData({
    required this.id,
    required this.titleController,
    required this.customMinutesController,
    required this.targetAt,
    required this.reminderPreset,
    this.completedAt,
    this.completionNote,
  });

  /// 新增步骤默认关闭提醒并安排在给定预计时间。
  factory _StepEditorData.create(DateTime targetAt) {
    final draftStep = PlanStep(title: '', targetAt: targetAt);
    return _StepEditorData(
      id: draftStep.id,
      titleController: TextEditingController(),
      customMinutesController: TextEditingController(text: '30'),
      targetAt: targetAt,
      // 与助手新建提醒保持一致：新增步骤默认在截止时提醒，用户仍可显式改为“不提醒”。
      reminderPreset: _ReminderPreset.atDeadline,
    );
  }

  /// 从已有步骤恢复编辑状态，同时保留完成时间和完成说明。
  factory _StepEditorData.fromStep(PlanStep step) {
    final preset = !step.reminderEnabled
        ? _ReminderPreset.off
        : switch (step.reminderMinutesBefore) {
            0 => _ReminderPreset.atDeadline,
            60 => _ReminderPreset.oneHour,
            1440 => _ReminderPreset.oneDay,
            _ => _ReminderPreset.custom,
          };
    return _StepEditorData(
      id: step.id,
      titleController: TextEditingController(text: step.title),
      customMinutesController: TextEditingController(
        text: preset == _ReminderPreset.custom
            ? '${step.reminderMinutesBefore}'
            : '30',
      ),
      targetAt: step.targetAt,
      reminderPreset: preset,
      completedAt: step.completedAt,
      completionNote: step.completionNote,
    );
  }

  /// 将已校验的编辑状态转换为领域步骤。
  PlanStep toPlanStep() {
    final reminderEnabled = reminderPreset != _ReminderPreset.off;
    final minutes = switch (reminderPreset) {
      _ReminderPreset.off || _ReminderPreset.atDeadline => 0,
      _ReminderPreset.oneHour => 60,
      _ReminderPreset.oneDay => 1440,
      _ReminderPreset.custom => int.parse(customMinutesController.text.trim()),
    };
    return PlanStep(
      id: id,
      title: titleController.text.trim(),
      targetAt: targetAt,
      reminderEnabled: reminderEnabled,
      reminderMinutesBefore: minutes,
      completedAt: completedAt,
      completionNote: completionNote,
    );
  }

  /// 释放步骤输入控制器。
  void dispose() {
    titleController.dispose();
    customMinutesController.dispose();
  }
}

/// 2026-07-15 21:40:00（北京时间）：打开创建或编辑多步骤计划表单，并在取消时返回 null。
Future<_PlanDraft?> _showPlanEditorDialog(
  BuildContext context, {
  Plan? existing,
}) {
  return showDialog<_PlanDraft>(
    context: context,
    builder: (context) => _PlanEditorDialog(existing: existing),
  );
}

/// 2026-07-15 21:40:00（北京时间）：计划编辑器集中管理有序步骤、独立提醒和时间顺序校验。
class _PlanEditorDialog extends StatefulWidget {
  final Plan? existing;

  const _PlanEditorDialog({this.existing});

  @override
  State<_PlanEditorDialog> createState() => _PlanEditorDialogState();
}

class _PlanEditorDialogState extends State<_PlanEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _goalController;
  late DateTime _startAt;
  late final List<_StepEditorData> _steps;

  /// 新计划默认提供一个步骤；编辑时恢复原有顺序、提醒和完成结果。
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _goalController = TextEditingController(text: existing?.goal ?? '');
    _startAt = existing?.startAt ?? now;
    _steps = existing == null
        ? [_StepEditorData.create(now.add(const Duration(days: 1)))]
        : existing.steps.map(_StepEditorData.fromStep).toList();
  }

  /// 释放计划与全部步骤输入控制器。
  @override
  void dispose() {
    _titleController.dispose();
    _goalController.dispose();
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  /// 构建可滚动多步骤表单，步骤列表支持显式拖动手柄调整顺序。
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMMMd(locale).add_Hm();
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? context.l10n.createPlan
            : context.l10n.planEdit,
      ),
      content: SizedBox(
        width: math.min(680, MediaQuery.sizeOf(context).width),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    key: const Key('plan-title-field'),
                    controller: _titleController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: context.l10n.planTitleLabel,
                      hintText: context.l10n.planTitleHint,
                      prefixIcon: const Icon(Icons.event_note_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? context.l10n.planValidateTitle
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    key: const Key('plan-goal-field'),
                    controller: _goalController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: context.l10n.planGoalLabel,
                      hintText: context.l10n.planGoalHint,
                      alignLabelWithHint: true,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 52),
                        child: Icon(Icons.flag_outlined),
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? context.l10n.planValidateGoal
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DateTimeField(
                    key: const Key('plan-start-time-field'),
                    label: context.l10n.planStartAt,
                    value: dateFormat.format(_startAt),
                    icon: Icons.play_circle_outline,
                    onTap: _selectStartTime,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.planSteps,
                          style: const TextStyle(
                            fontSize: AppFontSize.xl,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        context.l10n.planReorderStep,
                        style: const TextStyle(
                          fontSize: AppFontSize.sm,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _steps.length,
                    onReorderItem: _reorderSteps,
                    itemBuilder: (context, index) {
                      return _buildStepEditor(
                        context,
                        index,
                        dateFormat,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    key: const Key('add-plan-step-button'),
                    onPressed: _addStep,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.l10n.planAddStep),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton.icon(
          key: const Key('save-plan-button'),
          onPressed: _save,
          icon: const Icon(Icons.check, size: 18),
          label: Text(context.l10n.save),
        ),
      ],
    );
  }

  /// 构建一个可重排步骤编辑卡片，完成中的步骤仍保留原完成结果。
  Widget _buildStepEditor(
    BuildContext context,
    int index,
    DateFormat dateFormat,
  ) {
    final step = _steps[index];
    return Container(
      key: ValueKey(step.id),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Tooltip(
                  message: context.l10n.planReorderStep,
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: Icon(
                      Icons.drag_handle,
                      color: AppColors.textPlaceholder,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  context.l10n.planStepNumber(index + 1),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (step.completedAt != null)
                const Icon(
                  Icons.check_circle,
                  size: 20,
                  color: AppColors.success,
                ),
              IconButton(
                key: Key('remove-plan-step-$index'),
                tooltip: context.l10n.planRemoveStep,
                onPressed: _steps.length == 1 ? null : () => _removeStep(index),
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: Key('plan-step-title-field-$index'),
            controller: step.titleController,
            decoration: InputDecoration(
              labelText: context.l10n.planStepTitle,
              hintText: context.l10n.planStepTitleHint,
              errorText: step.titleError,
              prefixIcon: const Icon(Icons.checklist_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _DateTimeField(
            key: Key('plan-step-target-field-$index'),
            label: context.l10n.planStepTarget,
            value: dateFormat.format(step.targetAt),
            icon: Icons.schedule_outlined,
            errorText: step.timeError,
            onTap: () => _selectStepTime(index),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<_ReminderPreset>(
            key: Key('plan-step-reminder-field-$index'),
            initialValue: step.reminderPreset,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.l10n.planReminder,
              prefixIcon: const Icon(Icons.notifications_outlined),
            ),
            items: [
              DropdownMenuItem(
                value: _ReminderPreset.off,
                child: Text(context.l10n.planReminderOff),
              ),
              DropdownMenuItem(
                value: _ReminderPreset.atDeadline,
                child: Text(context.l10n.planReminderAtDeadline),
              ),
              DropdownMenuItem(
                value: _ReminderPreset.oneHour,
                child: Text(context.l10n.planReminderOneHourBefore),
              ),
              DropdownMenuItem(
                value: _ReminderPreset.oneDay,
                child: Text(context.l10n.planReminderOneDayBefore),
              ),
              DropdownMenuItem(
                value: _ReminderPreset.custom,
                child: Text(context.l10n.planReminderCustom),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  step.reminderPreset = value;
                  step.reminderError = null;
                });
              }
            },
          ),
          if (step.reminderPreset == _ReminderPreset.custom) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: Key('plan-step-reminder-minutes-field-$index'),
              controller: step.customMinutesController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.planReminderMinutes,
                hintText: context.l10n.planReminderMinutesHint,
                errorText: step.reminderError,
                prefixIcon: const Icon(Icons.timer_outlined),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 新增步骤默认安排在最后一步一天后，保证初始时间顺序合法。
  void _addStep() {
    final target = _steps.isEmpty
        ? _startAt.add(const Duration(days: 1))
        : _steps.last.targetAt.add(const Duration(days: 1));
    setState(() => _steps.add(_StepEditorData.create(target)));
  }

  /// 删除指定步骤并释放控制器，最后一个步骤由按钮禁用保护。
  void _removeStep(int index) {
    final removed = _steps.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  /// 调整步骤展示顺序，时间关系在保存时统一校验而不自动修改用户时间。
  void _reorderSteps(int oldIndex, int newIndex) {
    setState(() {
      final item = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, item);
      for (final step in _steps) {
        step.timeError = null;
      }
    });
  }

  /// 选择计划开始日期和时间，用户取消任一步时保留原值。
  Future<void> _selectStartTime() async {
    final selected = await _pickDateTime(_startAt);
    if (selected == null || !mounted) return;
    setState(() {
      _startAt = selected;
      for (final step in _steps) {
        step.timeError = null;
      }
    });
  }

  /// 选择指定步骤预计完成时间，并清除该步骤上次时间错误。
  Future<void> _selectStepTime(int index) async {
    final selected = await _pickDateTime(_steps[index].targetAt);
    if (selected == null || !mounted) return;
    setState(() {
      _steps[index].targetAt = selected;
      _steps[index].timeError = null;
    });
  }

  /// 日期和时间分两步选择，返回精确到分钟的本地时间。
  Future<DateTime?> _pickDateTime(DateTime current) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  /// 保存前校验步骤标题、提醒范围、开始时间和非递减顺序，错误贴近对应步骤展示。
  void _save() {
    final formValid = _formKey.currentState?.validate() ?? false;
    var stepsValid = _steps.isNotEmpty;
    DateTime? previousTarget;

    setState(() {
      for (final step in _steps) {
        step.titleError = null;
        step.timeError = null;
        step.reminderError = null;

        if (step.titleController.text.trim().isEmpty) {
          step.titleError = context.l10n.planValidateStepTitle;
          stepsValid = false;
        }
        if (step.targetAt.isBefore(_startAt)) {
          step.timeError = context.l10n.planValidateStepBeforeStart;
          stepsValid = false;
        } else if (previousTarget != null &&
            step.targetAt.isBefore(previousTarget!)) {
          step.timeError = context.l10n.planValidateStepOrder;
          stepsValid = false;
        }
        if (step.reminderPreset == _ReminderPreset.custom) {
          final minutes = int.tryParse(
            step.customMinutesController.text.trim(),
          );
          if (minutes == null || minutes < 1 || minutes > 525600) {
            step.reminderError = context.l10n.planValidateReminder;
            stepsValid = false;
          }
        }
        previousTarget = step.targetAt;
      }
    });

    if (!formValid || !stepsValid) return;
    Navigator.of(context).pop(
      _PlanDraft(
        title: _titleController.text.trim(),
        goal: _goalController.text.trim(),
        startAt: _startAt,
        steps: _steps.map((step) => step.toPlanStep()).toList(),
      ),
    );
  }
}

/// 2026-07-15 21:50:00（北京时间）：日期时间字段使用整行点击区域并支持贴近字段的错误提示。
class _DateTimeField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? errorText;
  final VoidCallback onTap;

  const _DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.errorText,
  });

  /// 构建带边框的日期时间选择入口。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.round),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.round),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: errorText == null
                      ? AppColors.borderColor
                      : AppColors.error,
                ),
                borderRadius: BorderRadius.circular(AppRadius.round),
              ),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: AppFontSize.sm,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: const TextStyle(color: AppColors.textPrimary),
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
        ),
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: AppFontSize.sm,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 2026-07-15 22:00:00（北京时间）：完成步骤弹窗收集该步骤独有的完成说明。
class _StepCompletionDialog extends StatefulWidget {
  final PlanStep step;

  const _StepCompletionDialog({required this.step});

  @override
  State<_StepCompletionDialog> createState() => _StepCompletionDialogState();
}

class _StepCompletionDialogState extends State<_StepCompletionDialog> {
  final _controller = TextEditingController();

  /// 释放完成说明输入控制器。
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 构建步骤完成确认，空说明以空字符串返回以区别于取消。
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.planCompleteStep),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.step.title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const Key('plan-step-completion-note-field'),
              controller: _controller,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: context.l10n.planStepCompletionNote,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-complete-plan-step-button'),
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(context.l10n.planCompleteStep),
        ),
      ],
    );
  }
}

/// 2026-07-15 22:00:00（北京时间）：执行记录弹窗要求输入有效内容后才能写入动态。
class _RecordDialog extends StatefulWidget {
  const _RecordDialog();

  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  final _controller = TextEditingController();
  String? _error;

  /// 释放记录输入控制器。
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 构建计划级执行记录输入框。
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.planAddRecord),
      content: SizedBox(
        width: 460,
        child: TextField(
          key: const Key('plan-record-field'),
          controller: _controller,
          autofocus: true,
          minLines: 4,
          maxLines: 7,
          decoration: InputDecoration(
            hintText: context.l10n.planRecordHint,
            errorText: _error,
            alignLabelWithHint: true,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final note = _controller.text.trim();
            if (note.isEmpty) {
              setState(() => _error = context.l10n.planRecordRequired);
              return;
            }
            Navigator.of(context).pop(note);
          },
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

/// 2026-07-15 22:00:00（北京时间）：终止计划使用带说明输入的确认弹窗。
class _PlanNoteConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final String hint;
  final String confirmLabel;
  final bool destructive;

  const _PlanNoteConfirmDialog({
    required this.title,
    required this.message,
    required this.hint,
    required this.confirmLabel,
    this.destructive = false,
  });

  @override
  State<_PlanNoteConfirmDialog> createState() => _PlanNoteConfirmDialogState();
}

class _PlanNoteConfirmDialogState extends State<_PlanNoteConfirmDialog> {
  final _controller = TextEditingController();

  /// 释放说明输入控制器。
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 构建终止确认内容，确认时即使未填写原因也返回空字符串。
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(hintText: widget.hint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          style: widget.destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.error)
              : null,
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
