import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../providers/git_provider.dart';
import '../providers/window_provider.dart';
import '../services/storage_service.dart';
import '../services/window_service.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late GitPlatform _platform;
  late TextEditingController _tokenController;
  late TextEditingController _ownerController;
  late TextEditingController _repoController;
  late TextEditingController _branchController;
  late TextEditingController _notesDirController;
  bool _autoSync = false;
  bool _autoPush = false;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController();
    _ownerController = TextEditingController();
    _repoController = TextEditingController();
    _branchController = TextEditingController();
    _notesDirController = TextEditingController();
    _loadConfig();
  }

  void _loadConfig() {
    final config = ref.read(gitProvider).config;
    _platform = config.platform;
    _tokenController.text = config.token;
    _ownerController.text = config.owner;
    _repoController.text = config.repo;
    _branchController.text = config.branch;
    _notesDirController.text = config.notesDir;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _ownerController.dispose();
    _repoController.dispose();
    _branchController.dispose();
    _notesDirController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gitState = ref.watch(gitProvider);
    final isDesktop = getScreenType(context) == ScreenType.desktop;

    return Column(
      children: [
        _buildHeader(context, isDesktop),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _buildSectionTitle(context.l10n.gitPlatformConfig),
              _buildConfigGroup(context, gitState),
              const SizedBox(height: AppSpacing.sm),
              _buildTokenHelpButton(context),
              const SizedBox(height: AppSpacing.md),
              _buildActionButtons(context),
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

  Widget _buildConfigGroup(BuildContext context, GitState state) {
    return Card(
      child: Column(
        children: [
          _buildPickerItem(context.l10n.platform, _platformLabel,
              () => _showPlatformPicker()),
          const Divider(height: 1),
          _buildInputItem(context.l10n.accessToken, _tokenController,
              hint: context.l10n.enterToken, obscure: true),
          const Divider(height: 1),
          _buildInputItem(context.l10n.ownerOrOrg, _ownerController,
              hint: context.l10n.ownerHint),
          const Divider(height: 1),
          _buildInputItem(context.l10n.repoName, _repoController,
              hint: context.l10n.repoHint),
          const Divider(height: 1),
          _buildInputItem(context.l10n.branch, _branchController,
              hint: context.l10n.branchHint),
          const Divider(height: 1),
          _buildInputItem(context.l10n.notesDirectory, _notesDirController,
              hint: context.l10n.notesDirectoryHint),
        ],
      ),
    );
  }

  String get _platformLabel {
    return _platform == GitPlatform.github ? 'GitHub' : 'Gitee';
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

  Widget _buildInputItem(String label, TextEditingController controller,
      {String? hint, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: AppFontSize.base)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              style: const TextStyle(fontSize: AppFontSize.base),
              textAlign: TextAlign.end,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                hintStyle: const TextStyle(color: AppColors.textPlaceholder),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final gitState = ref.read(gitProvider);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _testConnection(),
            icon: Icon(gitState.connected ? Icons.check : Icons.wifi_tethering),
            label: Text(gitState.connected
                ? context.l10n.connectedShort
                : context.l10n.testConnection),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _saveSettings(),
            child: Text(context.l10n.saveConfig),
          ),
        ),
      ],
    );
  }

  Widget _buildTokenHelpButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => context.push('/settings/token-help'),
        icon: const Icon(Icons.help_outline, size: 20),
        label: Text(context.l10n.tokenHelpButton),
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
                const Text('0.1.0',
                    style: TextStyle(
                        fontSize: AppFontSize.base,
                        color: AppColors.textSecondary)),
              ],
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

  void _showPlatformPicker() {
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
              Text(context.l10n.choosePlatform,
                  style: const TextStyle(
                      fontSize: AppFontSize.lg, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('GitHub'),
                trailing: _platform == GitPlatform.github
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _platform = GitPlatform.github);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Gitee'),
                trailing: _platform == GitPlatform.gitee
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _platform = GitPlatform.gitee);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveSettings() {
    ref.read(gitProvider.notifier).setConfig(GitConfig(
          platform: _platform,
          token: _tokenController.text,
          owner: _ownerController.text,
          repo: _repoController.text,
          branch: _branchController.text.isNotEmpty
              ? _branchController.text
              : 'main',
          notesDir: _notesDirController.text.isNotEmpty
              ? _notesDirController.text
              : 'notes',
        ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(context.l10n.saved),
          backgroundColor: AppColors.success),
    );
  }

  Future<void> _testConnection() async {
    _saveSettings();
    final success = await ref.read(gitProvider.notifier).testConnection();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? context.l10n.connectionSuccess
              : ref.read(gitProvider).syncError ??
                  context.l10n.connectionFailed),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

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
