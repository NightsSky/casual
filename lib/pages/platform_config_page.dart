import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/git_provider.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';

/// 2026-07-15 12:40:41（北京时间）：
/// Git 平台连接信息从设置总览中拆出，在独立页面完成编辑、保存和连接验证。
class PlatformConfigPage extends ConsumerStatefulWidget {
  const PlatformConfigPage({super.key});

  @override
  ConsumerState<PlatformConfigPage> createState() => _PlatformConfigPageState();
}

class _PlatformConfigPageState extends ConsumerState<PlatformConfigPage> {
  late GitPlatform _platform;
  late final TextEditingController _tokenController;
  late final TextEditingController _ownerController;
  late final TextEditingController _repoController;
  late final TextEditingController _branchController;
  late final TextEditingController _notesDirController;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController();
    _ownerController = TextEditingController();
    _repoController = TextEditingController();
    _branchController = TextEditingController();
    _notesDirController = TextEditingController();

    // 页面打开时以已持久化的 Git 配置回填表单，避免拆页后丢失原设置页的编辑体验。
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Card(
                    child: Column(
                      children: [
                        _buildPickerItem(
                          context.l10n.platform,
                          _platformLabel,
                          _showPlatformPicker,
                        ),
                        const Divider(height: 1),
                        _buildInputItem(
                          context.l10n.accessToken,
                          _tokenController,
                          hint: context.l10n.enterToken,
                          obscure: true,
                        ),
                        const Divider(height: 1),
                        _buildInputItem(
                          context.l10n.ownerOrOrg,
                          _ownerController,
                          hint: context.l10n.ownerHint,
                        ),
                        const Divider(height: 1),
                        _buildInputItem(
                          context.l10n.repoName,
                          _repoController,
                          hint: context.l10n.repoHint,
                        ),
                        const Divider(height: 1),
                        _buildInputItem(
                          context.l10n.branch,
                          _branchController,
                          hint: context.l10n.branchHint,
                        ),
                        const Divider(height: 1),
                        _buildInputItem(
                          context.l10n.notesDirectory,
                          _notesDirController,
                          hint: context.l10n.notesDirectoryHint,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/settings/platform-config/token-help'),
                      icon: const Icon(Icons.help_outline, size: 20),
                      label: Text(context.l10n.tokenHelpButton),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _testConnection,
                      icon: Icon(
                        gitState.connected ? Icons.check : Icons.wifi_tethering,
                      ),
                      label: Text(
                        gitState.connected
                            ? context.l10n.connectedShort
                            : context.l10n.testConnection,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _saveSettings,
                      child: Text(context.l10n.saveConfig),
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

  /// 2026-07-15 12:40:41（北京时间）：独立配置页提供返回设置总览的明确入口。
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
                context.go('/settings');
              }
            },
          ),
          Expanded(
            child: Text(
              context.l10n.gitPlatformConfig,
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

  String get _platformLabel =>
      _platform == GitPlatform.github ? 'GitHub' : 'Gitee';

  Widget _buildPickerItem(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: AppFontSize.base)),
            const Spacer(),
            Text(
              '$value ›',
              style: const TextStyle(
                fontSize: AppFontSize.base,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputItem(
    String label,
    TextEditingController controller, {
    String? hint,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
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

  /// 2026-07-15 12:40:41（北京时间）：平台切换只更新当前表单，保存后才写入持久化配置。
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
              Text(
                context.l10n.choosePlatform,
                style: const TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.w600,
                ),
              ),
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

  /// 2026-07-15 12:40:41（北京时间）：保存完整平台与仓库定位信息，供仓库页同步流程共用。
  void _saveSettings() {
    ref
        .read(gitProvider.notifier)
        .setConfig(
          GitConfig(
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
          ),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.saved),
        backgroundColor: AppColors.success,
      ),
    );
  }

  /// 2026-07-15 12:40:41（北京时间）：连接测试前先保存表单，确保校验使用用户刚输入的配置。
  Future<void> _testConnection() async {
    _saveSettings();
    final success = await ref.read(gitProvider.notifier).testConnection();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? context.l10n.connectionSuccess
              : ref.read(gitProvider).syncError ??
                    context.l10n.connectionFailed,
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }
}
