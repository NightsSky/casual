import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../domain/models/reminder.dart';
import '../widgets/reminder_alarm_panel.dart';

/// Windows 桌面端提醒弹窗子窗口管理。
///
/// 只负责创建轻量提醒窗口；主窗口是否隐藏、最小化或位于后台均不需要改变。
class ReminderAlarmWindowService {
  ReminderAlarmWindowService._();

  static const String windowKind = 'reminderAlarm';
  static const Size _windowSize = ReminderAlarmPanel.panelSize;
  static const double _screenMargin = 24;

  static bool get isSupported => !kIsWeb && Platform.isWindows;

  static bool isReminderAlarmArguments(Map<String, dynamic> arguments) {
    return arguments['kind'] == windowKind;
  }

  static Future<bool> show(Reminder reminder) async {
    if (!isSupported) return false;

    try {
      final controller = await DesktopMultiWindow.createWindow(jsonEncode({
        'kind': windowKind,
        'title': reminder.title,
      }));
      // desktop_multi_window 只负责创建子窗口；必须由主窗口 isolate 显式
      // show()，否则提醒事件已触发但用户看不到独立弹框。
      await controller.setFrame(await _resolveBottomRightFrame());
      await controller.setTitle('');
      await controller.show();
      return true;
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('[ReminderAlarmWindowService] create failed: $error');
      }
      return false;
    } on MissingPluginException catch (error) {
      if (kDebugMode) {
        debugPrint('[ReminderAlarmWindowService] plugin unavailable: $error');
      }
      return false;
    }
  }

  static Future<Rect> _resolveBottomRightFrame() async {
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      final visiblePosition = display.visiblePosition ?? Offset.zero;
      final visibleSize = display.visibleSize ?? display.size;
      final left = math.max(
        visiblePosition.dx + _screenMargin,
        visiblePosition.dx +
            visibleSize.width -
            _windowSize.width -
            _screenMargin,
      );
      final top = math.max(
        visiblePosition.dy + _screenMargin,
        visiblePosition.dy +
            visibleSize.height -
            _windowSize.height -
            _screenMargin,
      );
      return Rect.fromLTWH(left, top, _windowSize.width, _windowSize.height);
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('[ReminderAlarmWindowService] screen lookup failed: $error');
      }
      return Offset.zero & _windowSize;
    } on MissingPluginException catch (error) {
      if (kDebugMode) {
        debugPrint(
            '[ReminderAlarmWindowService] screen plugin unavailable: $error');
      }
      return Offset.zero & _windowSize;
    }
  }
}
