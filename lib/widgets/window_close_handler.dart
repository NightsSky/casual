import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/window_provider.dart';
import '../services/window_service.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';

/// 监听 Windows 桌面端主窗口的关闭事件。
///
/// 点击关闭按钮时，根据用户偏好执行：弹窗询问（默认）、最小化到系统托盘或退出。
/// 非 Windows 平台上此组件不注册任何监听，直接透传 child。
class WindowCloseHandler extends ConsumerStatefulWidget {
  const WindowCloseHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WindowCloseHandler> createState() => _WindowCloseHandlerState();
}

class _WindowCloseHandlerState extends ConsumerState<WindowCloseHandler>
    with WindowListener {
  bool _dialogVisible = false;
  bool _trayInitialized = false;

  @override
  void initState() {
    super.initState();
    if (WindowService.isDesktopWindows) {
      windowManager.addListener(this);
      // 提前实例化 Provider，触发偏好异步加载，避免首次点击关闭时读到默认值。
      ref.read(windowCloseActionProvider);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 托盘菜单文案依赖 l10n，须在拿到 context 后初始化，仅执行一次。
    if (WindowService.isDesktopWindows && !_trayInitialized) {
      _trayInitialized = true;
      WindowService.instance.setupTray(
        showWindowLabel: context.l10n.trayShowWindow,
        exitLabel: context.l10n.trayExit,
      );
    }
  }

  @override
  void dispose() {
    if (WindowService.isDesktopWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (!mounted || _dialogVisible) return;

    switch (ref.read(windowCloseActionProvider)) {
      case WindowCloseAction.minimizeToTray:
        await WindowService.instance.hideToTray();
      case WindowCloseAction.exit:
        await WindowService.instance.exitApp();
      case WindowCloseAction.ask:
        await _showCloseDialog();
    }
  }

  Future<void> _showCloseDialog() async {
    _dialogVisible = true;
    final result = await showDialog<_CloseDialogResult>(
      context: context,
      builder: (ctx) => const _CloseConfirmDialog(),
    );
    _dialogVisible = false;

    if (result == null) return;

    if (result.remember) {
      await ref
          .read(windowCloseActionProvider.notifier)
          .setAction(result.action);
    }

    switch (result.action) {
      case WindowCloseAction.minimizeToTray:
        await WindowService.instance.hideToTray();
      case WindowCloseAction.exit:
        await WindowService.instance.exitApp();
      case WindowCloseAction.ask:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _CloseDialogResult {
  const _CloseDialogResult({required this.action, required this.remember});

  final WindowCloseAction action;
  final bool remember;
}

/// 微信风格的关闭确认弹窗：单选"最小化到托盘 / 退出"，可勾选"不再询问"。
class _CloseConfirmDialog extends StatefulWidget {
  const _CloseConfirmDialog();

  @override
  State<_CloseConfirmDialog> createState() => _CloseConfirmDialogState();
}

class _CloseConfirmDialogState extends State<_CloseConfirmDialog> {
  WindowCloseAction _selected = WindowCloseAction.minimizeToTray;
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.closeDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.closeDialogMessage,
              style: const TextStyle(fontSize: AppFontSize.base)),
          const SizedBox(height: AppSpacing.sm),
          _buildOption(
            l10n.closeActionMinimize,
            Icons.arrow_downward,
            WindowCloseAction.minimizeToTray,
          ),
          _buildOption(
            l10n.closeActionExit,
            Icons.power_settings_new,
            WindowCloseAction.exit,
          ),
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            onTap: () => setState(() => _remember = !_remember),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    _remember
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 20,
                    color: _remember
                        ? AppColors.primary
                        : AppColors.textPlaceholder,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.closeDialogRemember,
                      style: const TextStyle(
                        fontSize: AppFontSize.sm,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _CloseDialogResult(action: _selected, remember: _remember),
          ),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }

  Widget _buildOption(String label, IconData icon, WindowCloseAction action) {
    final isSelected = _selected == action;

    return InkWell(
      onTap: () => setState(() => _selected = action),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color:
                  isSelected ? AppColors.primary : AppColors.textPlaceholder,
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: const TextStyle(fontSize: AppFontSize.base)),
          ],
        ),
      ),
    );
  }
}
