import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/git_provider.dart';
import '../providers/update_provider.dart';
import '../providers/window_provider.dart';
import '../services/storage_service.dart';
import '../services/window_service.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';
import '../widgets/update_dialog.dart';

/// 2026-07-15 12:40:41（北京时间）：
/// 设置页作为配置总览，仓库管理与 Git 平台配置通过独立二级页面承载。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _autoSync = false;
  bool _autoPush = false;
  String _appVersion = '';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = info.version);
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDesktop = getScreenType(context) == ScreenType.desktop;

    return Column(
      children: [
        _buildHeader(context, isDesktop),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _buildSectionTitle(context.l10n.repositorySettings),
              _buildRepositorySettingsEntries(context),
              const SizedBox(height: AppSpacing.xl),
              _buildSectionTitle(context.l10n.syncSettings),
              _buildSyncSettings(context),
              const SizedBox(height: AppSpacing.xl),
              // 窗口设置仅 Windows 桌面端可见（关闭按钮行为 / 系统托盘）
              if (WindowService.isDesktopWindows) ...[
                _buildSectionTitle(context.l10n.windowSettings),
                _buildWindowSettings(context),
                const SizedBox(height: AppSpacing.xl),
              ],
              _buildSectionTitle(context.l10n.about),
              _buildAboutSection(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
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
              offset: const Offset(0, 1)),
        ],
      ),
      child: Text(context.l10n.settings,
          style: const TextStyle(
              fontSize: AppFontSize.xxl, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding:
          const EdgeInsets.only(left: AppSpacing.md, bottom: AppSpacing.sm),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: AppFontSize.sm,
          fontWeight: FontWeight.w600,
          color: AppColors.textPlaceholder,
        ),
      ),
    );
  }

  /// 2026-07-15 12:40:41（北京时间）：
  /// 仓库运行状态与平台凭据分开进入各自页面，设置总览不再承载完整 Git 表单。
  Widget _buildRepositorySettingsEntries(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.sync, color: AppColors.primary),
            title: Text(context.l10n.repositoryManagement),
            subtitle: Text(context.l10n.repositoryManagementDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/repository'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.account_tree_outlined,
                color: AppColors.primary),
            title: Text(context.l10n.gitPlatformConfig),
            subtitle: Text(context.l10n.gitPlatformConfigDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/platform-config'),
          ),
        ],
      ),
    );
  }
  Widget _buildPickerItem(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: AppFontSize.base)),
            const Spacer(),
            Text('$value ›',
                style: const TextStyle(
                    fontSize: AppFontSize.base, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSettings(BuildContext context) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: Text(context.l10n.autoSync,
                style: const TextStyle(fontSize: AppFontSize.base)),
            subtitle: Text(context.l10n.autoSyncDescription,
                style: const TextStyle(fontSize: AppFontSize.xs)),
            value: _autoSync,
            onChanged: (v) => setState(() => _autoSync = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: Text(context.l10n.autoPush,
                style: const TextStyle(fontSize: AppFontSize.base)),
            subtitle: Text(context.l10n.autoPushDescription,
                style: const TextStyle(fontSize: AppFontSize.xs)),
            value: _autoPush,
            onChanged: (v) => setState(() => _autoPush = v),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowSettings(BuildContext context) {
    final action = ref.watch(windowCloseActionProvider);
    return Card(
      child: _buildPickerItem(
        context.l10n.closeButtonAction,
        _closeActionLabel(action),
        () => _showCloseActionPicker(),
      ),
    );
  }

  String _closeActionLabel(WindowCloseAction action) {
    return switch (action) {
      WindowCloseAction.ask => context.l10n.closeActionAsk,
      WindowCloseAction.minimizeToTray => context.l10n.closeActionMinimize,
      WindowCloseAction.exit => context.l10n.closeActionExit,
    };
  }

  /// 2026-07-15 12:40:41（北京时间）：Windows 关闭行为仍在设置总览内就地选择并持久化。
  void _showCloseActionPicker() {
    final current = ref.read(windowCloseActionProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.closeButtonAction,
                  style: const TextStyle(
                      fontSize: AppFontSize.lg, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.md),
              for (final action in WindowCloseAction.values)
                ListTile(
                  leading: Icon(switch (action) {
                    WindowCloseAction.ask => Icons.help_outline,
                    WindowCloseAction.minimizeToTray => Icons.arrow_downward,
                    WindowCloseAction.exit => Icons.power_settings_new,
                  }),
                  title: Text(_closeActionLabel(action)),
                  trailing: current == action
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    ref
                        .read(windowCloseActionProvider.notifier)
                        .setAction(action);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              children: [
                Text(context.l10n.version,
                    style: const TextStyle(fontSize: AppFontSize.base)),
                const Spacer(),
                Text(_appVersion.isEmpty ? '—' : 'v$_appVersion',
                    style: const TextStyle(
                        fontSize: AppFontSize.base,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Divider(height: 1),
          InkWell(
            onTap: _checkingUpdate ? null : _checkForUpdate,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Text(context.l10n.checkForUpdate,
                      style: const TextStyle(fontSize: AppFontSize.base)),
                  const Spacer(),
                  if (_checkingUpdate)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Text('›',
                        style: TextStyle(
                            fontSize: AppFontSize.base,
                            color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          InkWell(
            onTap: () => _clearAllData(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                children: [
                  Text(context.l10n.clearAllData,
                      style: const TextStyle(
                          fontSize: AppFontSize.base, color: AppColors.error)),
                  const Spacer(),
                  const Text('›',
                      style: TextStyle(
                          fontSize: AppFontSize.base,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 手动检查更新：有新版本弹出更新对话框，已是最新则提示，出错给出错误信息。
  Future<void> _checkForUpdate() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _checkingUpdate = true);
    await ref.read(updateProvider.notifier).checkForUpdate();
    if (!mounted) return;
    setState(() => _checkingUpdate = false);

    final state = ref.read(updateProvider);
    switch (state.phase) {
      case UpdatePhase.available:
        await showUpdateDialog(context, ref);
      case UpdatePhase.upToDate:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.upToDate)),
        );
      case UpdatePhase.error:
        messenger.showSnackBar(
          SnackBar(
            content: Text(state.errorMessage ?? l10n.updateCheckFailed),
            backgroundColor: AppColors.error,
          ),
        );
      default:
        break;
    }
  }


  /// 2026-07-15 12:40:41（北京时间）：清除数据同时移除 Git 配置，避免独立配置页残留旧连接信息。
  void _clearAllData(BuildContext context) {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.warning),
        content: Text(l10n.clearAllConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () async {
              final dialogNavigator = Navigator.of(ctx);
              ref.read(gitProvider.notifier).clearConfig();
              await StorageService().clearAll();
              dialogNavigator.pop();
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                    content: Text(l10n.cleared),
                    backgroundColor: AppColors.success),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
  }
}
