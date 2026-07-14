import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
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
  // 子窗口关闭请求需要先进入 Windows 消息队列；保留短暂兜底时间，避免插件异常时进程滞留。
  static const _processExitDeadline = Duration(milliseconds: 500);

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
    await trayManager.setToolTip('casual');
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

    // 退出前先关闭所有 desktop_multi_window 子窗口。txt 标签窗口常置顶且不出现在任务栏，
    // 若只销毁主窗口，子窗口可能继续占用 Flutter 引擎或留下悬浮窗口，导致退出不完整。
    // 关闭请求会先进入同一 Windows 消息队列，再投递主窗口的退出消息，保证子窗口先完成销毁。
    Timer(_processExitDeadline, terminateProcess);
    unawaited(() async {
      await _closeAllSubWindows();
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
    }());

    return Future.value();
  }

  /// 关闭当前进程创建的全部子窗口（笔记独立窗口、txt 标签和提醒弹窗）。
  ///
  /// 这里不依赖各业务服务自身的窗口登记表：提醒弹窗与标签窗口均由同一个多窗口
  /// 插件创建，直接读取原生注册表可覆盖所有窗口类型，也能处理登记尚未同步的窗口。
  Future<void> _closeAllSubWindows() async {
    try {
      final windowIds = await DesktopMultiWindow.getAllSubWindowIds()
          .timeout(_pluginCallTimeout);
      await Future.wait([
        for (final windowId in windowIds)
          _waitForPluginCall(
            WindowController.fromWindowId(windowId).close(),
            operation: 'close sub window $windowId',
          ),
      ]);
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint(
          '[WindowService] enumerate sub windows timed out after '
          '$_pluginCallTimeout',
        );
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[WindowService] enumerate sub windows failed: $error\n$stackTrace',
        );
      }
    }
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
