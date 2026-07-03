import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// 关闭主窗口时的行为（仅 Windows 桌面端生效）。
enum WindowCloseAction {
  /// 每次弹窗询问
  ask,

  /// 最小化到系统托盘
  minimizeToTray,

  /// 直接退出程序
  exit;

  static WindowCloseAction fromName(String? name) {
    return WindowCloseAction.values.firstWhere(
      (action) => action.name == name,
      orElse: () => WindowCloseAction.ask,
    );
  }
}

/// Windows 桌面端窗口与系统托盘管理。
///
/// 仅支持 Windows 平台：其他平台（Android/iOS/Web）上所有方法均为空操作，
/// 调用方无需额外判断平台。
class WindowService with TrayListener {
  WindowService._();

  static final WindowService instance = WindowService._();

  static const _trayMenuKeyShow = 'show_window';
  static const _trayMenuKeyExit = 'exit_app';
  static const _pluginCallTimeout = Duration(milliseconds: 100);
  static const _processExitDeadline = Duration(milliseconds: 350);

  static bool get isDesktopWindows => !kIsWeb && Platform.isWindows;

  bool _initialized = false;
  bool _isExiting = false;

  /// 在 runApp 之前调用：接管关闭按钮，注册托盘事件监听。
  Future<void> init() async {
    if (!isDesktopWindows || _initialized) return;
    _initialized = true;

    await windowManager.ensureInitialized();
    // 拦截关闭按钮，由 WindowCloseHandler 决定最小化到托盘还是退出。
    await windowManager.setPreventClose(true);
    trayManager.addListener(this);
  }

  /// 创建托盘图标与右键菜单。菜单文案依赖 l10n，由 UI 层传入。
  Future<void> setupTray({
    required String showWindowLabel,
    required String exitLabel,
  }) async {
    if (!isDesktopWindows) return;

    await trayManager.setIcon('assets/tray_icon.ico');
    await trayManager.setToolTip('GitNote');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: _trayMenuKeyShow, label: showWindowLabel),
          MenuItem.separator(),
          MenuItem(key: _trayMenuKeyExit, label: exitLabel),
        ],
      ),
    );
  }

  /// 隐藏主窗口到系统托盘。
  ///
  /// 注意：不要调用 setSkipTaskbar —— window_manager 0.5.x 的 Windows 实现中，
  /// 其内部 taskbar COM 指针仅在 waitUntilReadyToShow() 里初始化，本项目未走该
  /// 流程，调用会触发空指针崩溃。hide() 本身即可将窗口从任务栏移除。
  Future<void> hideToTray() async {
    if (!isDesktopWindows) return;
    await windowManager.hide();
  }

  /// 从托盘恢复并聚焦主窗口。
  Future<void> showWindow() async {
    if (!isDesktopWindows) return;
    await windowManager.show();
    await windowManager.focus();
  }

  /// 销毁托盘图标并真正退出程序。
  Future<void> exitApp() {
    if (!isDesktopWindows) return Future.value();
    if (_isExiting) return Future.value();
    _isExiting = true;
    trayManager.removeListener(this);

    var processExitStarted = false;
    void terminateProcess() {
      if (processExitStarted) return;
      processExitStarted = true;
      exit(0);
    }

    // 用户已经明确选择退出，窗口/托盘插件调用只作为退出前清理；
    // Windows 端 window_manager.destroy() 只是投递 PostQuitMessage，
    // 不能把进程退出完全依赖在消息循环响应上，否则会出现主界面长时间停留。
    Timer(_processExitDeadline, terminateProcess);
    unawaited(() async {
      await _waitForPluginCall(
        windowManager.setPreventClose(false),
        operation: 'allow window close',
      );
      await _waitForPluginCall(
        trayManager.destroy(),
        operation: 'destroy tray icon',
      );
      await _waitForPluginCall(
        windowManager.destroy(),
        operation: 'post native quit message',
      );
      terminateProcess();
    }());

    return Future.value();
  }

  Future<bool> _waitForPluginCall(
    Future<void> future, {
    required String operation,
    Duration timeout = _pluginCallTimeout,
  }) async {
    try {
      await future.timeout(timeout);
      return true;
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[WindowService] $operation timed out after $timeout');
      }
      return false;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[WindowService] $operation failed: $error\n$stackTrace');
      }
      return false;
    }
  }

  @override
  void onTrayIconMouseDown() {
    showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _trayMenuKeyShow:
        showWindow();
      case _trayMenuKeyExit:
        exitApp();
    }
  }
}
