import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';

/// 2026-07-15 12:40:41（北京时间）：Token 帮助页隶属于独立 Git 平台配置流程。
class TokenHelpPage extends StatelessWidget {
  const TokenHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = getScreenType(context) == ScreenType.desktop;

    return Column(
      children: [
        _buildHeader(context, isDesktop),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Text(
                    context.l10n.tokenHelpIntro,
                    style: const TextStyle(
                      fontSize: AppFontSize.base,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _PlatformTokenCard(
                    icon: Icons.code,
                    title: context.l10n.githubTokenTitle,
                    steps: [
                      context.l10n.githubTokenStep1,
                      context.l10n.githubTokenStep2,
                      context.l10n.githubTokenStep3,
                      context.l10n.githubTokenStep4,
                      context.l10n.githubTokenStep5,
                    ],
                    tip: context.l10n.githubClassicTokenTip,
                    entrance: context.l10n.githubTokenOfficialEntrance,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _PlatformTokenCard(
                    icon: Icons.account_tree_outlined,
                    title: context.l10n.giteeTokenTitle,
                    steps: [
                      context.l10n.giteeTokenStep1,
                      context.l10n.giteeTokenStep2,
                      context.l10n.giteeTokenStep3,
                      context.l10n.giteeTokenStep4,
                      context.l10n.giteeTokenStep5,
                    ],
                    tip: context.l10n.giteeTokenTip,
                    entrance: context.l10n.giteeTokenOfficialEntrance,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.tokenSafetyTitle,
                                  style: const TextStyle(
                                    fontSize: AppFontSize.lg,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  context.l10n.tokenSafetyBody,
                                  style: const TextStyle(
                                    fontSize: AppFontSize.base,
                                    color: AppColors.textSecondary,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  context.l10n.tokenPasteTip,
                                  style: const TextStyle(
                                    fontSize: AppFontSize.base,
                                    color: AppColors.textSecondary,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        isDesktop
            ? AppSpacing.md
            : MediaQuery.of(context).padding.top + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/settings/platform-config');
              }
            },
          ),
          Expanded(
            child: Text(
              context.l10n.tokenHelpTitle,
              style: const TextStyle(
                fontSize: AppFontSize.xxl,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformTokenCard extends StatelessWidget {
  const _PlatformTokenCard({
    required this.icon,
    required this.title,
    required this.steps,
    required this.tip,
    required this.entrance,
  });

  final IconData icon;
  final String title;
  final List<String> steps;
  final String tip;
  final String entrance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: AppFontSize.lg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < steps.length; i++) ...[
              _TokenStep(index: i + 1, text: steps[i]),
              if (i != steps.length - 1) const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              tip,
              style: const TextStyle(
                fontSize: AppFontSize.sm,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              entrance,
              style: const TextStyle(
                fontSize: AppFontSize.sm,
                color: AppColors.primary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TokenStep extends StatelessWidget {
  const _TokenStep({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            index.toString(),
            style: const TextStyle(
              fontSize: AppFontSize.xs,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: AppFontSize.base,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
