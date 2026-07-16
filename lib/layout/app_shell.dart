import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/markdown_editor_focus_provider.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';

/// 2026-07-15 12:40:41（北京时间）：主导航第三项由仓库调整为计划，仓库功能转入设置分支。
enum AppPage { notes, reminder, plan, settings, editor }

class AppShell extends ConsumerStatefulWidget {
  final AppPage currentPage;
  final Widget child;
  final void Function(AppPage)? onNavigate;

  const AppShell({
    super.key,
    required this.currentPage,
    required this.child,
    this.onNavigate,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final screenType = getScreenType(context);
    // Windows 可缩放窗口在 1024px 起保持桌面导航，Markdown 分屏才能在
    // 最小受支持桌面宽度下通过专注视图获得足够空间。
    final isDesktop = screenType == ScreenType.desktop ||
        (defaultTargetPlatform == TargetPlatform.windows &&
            MediaQuery.sizeOf(context).width >= 1024);
    final isEditorFocused = widget.currentPage == AppPage.editor &&
        ref.watch(markdownEditorFocusProvider);

    if (isDesktop) {
      return _buildDesktop(isEditorFocused);
    }
    return _buildMobile();
  }

  Widget _buildDesktop(bool isEditorFocused) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: isEditorFocused ? 0 : 240,
            child: isEditorFocused ? const SizedBox.shrink() : _buildSidebar(),
          ),
          SizedBox(
            width: isEditorFocused ? 0 : 1,
            child: const VerticalDivider(width: 1, thickness: 1),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  /// 2026-07-15 12:40:41（北京时间）：桌面侧栏展示计划入口，不再直接暴露仓库管理。
  Widget _buildSidebar() {
    final items = [
      _NavItem(
          icon: Icons.article_outlined,
          label: context.l10n.notes,
          page: AppPage.notes),
      _NavItem(
          icon: Icons.alarm_outlined,
          label: context.l10n.reminders,
          page: AppPage.reminder),
      _NavItem(
          icon: Icons.event_note_outlined,
          label: context.l10n.plan,
          page: AppPage.plan),
      _NavItem(
          icon: Icons.settings_outlined,
          label: context.l10n.settings,
          page: AppPage.settings),
    ];

    return Container(
      width: 240,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
            child: Row(
              children: [
                const Icon(Icons.note_alt_outlined,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'casual',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          ...items.map((item) => _DesktopNavItem(
                item: item,
                isSelected: widget.currentPage == item.page ||
                    (item.page == AppPage.notes &&
                        widget.currentPage == AppPage.editor),
                onTap: () => widget.onNavigate?.call(item.page),
              )),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text(
              'v0.1.0',
              style: TextStyle(
                  fontSize: AppFontSize.xs, color: AppColors.textPlaceholder),
            ),
          ),
        ],
      ),
    );
  }

  /// 2026-07-15 12:40:41（北京时间）：移动端底部导航第三项进入响应式计划工作区。
  Widget _buildMobile() {
    final isEditor = widget.currentPage == AppPage.editor;
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: isEditor
          ? null
          : Container(
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.borderColor, width: 0.5)),
              ),
              child: BottomNavigationBar(
                currentIndex: _tabIndex,
                onTap: (index) {
                  widget.onNavigate?.call([
                    AppPage.notes,
                    AppPage.reminder,
                    AppPage.plan,
                    AppPage.settings
                  ][index]);
                },
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.article_outlined),
                    activeIcon: const Icon(Icons.article),
                    label: context.l10n.notes,
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.alarm_outlined),
                    activeIcon: const Icon(Icons.alarm),
                    label: context.l10n.reminders,
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.event_note_outlined),
                    activeIcon: const Icon(Icons.event_note),
                    label: context.l10n.plan,
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.settings_outlined),
                    activeIcon: const Icon(Icons.settings),
                    label: context.l10n.settings,
                  ),
                ],
              ),
            ),
    );
  }

  int get _tabIndex {
    switch (widget.currentPage) {
      case AppPage.notes:
      case AppPage.editor:
        return 0;
      case AppPage.reminder:
        return 1;
      case AppPage.plan:
        return 2;
      case AppPage.settings:
        return 3;
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final AppPage page;
  const _NavItem({required this.icon, required this.label, required this.page});
}

class _DesktopNavItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _DesktopNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 1),
      child: Material(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  isSelected ? _activeIcon : item.icon,
                  size: 20,
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: AppFontSize.base,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData get _activeIcon {
    switch (item.icon) {
      case Icons.article_outlined:
        return Icons.article;
      case Icons.alarm_outlined:
        return Icons.alarm;
      case Icons.event_note_outlined:
        return Icons.event_note;
      case Icons.settings_outlined:
        return Icons.settings;
      default:
        return item.icon;
    }
  }
}
