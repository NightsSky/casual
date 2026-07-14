import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../ui/core/extensions/build_context_l10n.dart';
import '../widgets/reminder_alarm_panel.dart';

/// Windows 桌面端提醒子窗口。
///
/// 主窗口保持隐藏或最小化状态时，提醒到点只展示这个轻量窗口，不恢复完整主界面。
class ReminderAlarmWindowApp extends StatelessWidget {
  const ReminderAlarmWindowApp({
    super.key,
    required this.arguments,
  });

  final Map<String, dynamic> arguments;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'casual',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
      ],
      home: ReminderAlarmWindowPage(
        message: arguments['title'] as String? ?? '',
      ),
    );
  }
}

class ReminderAlarmWindowPage extends StatefulWidget {
  const ReminderAlarmWindowPage({
    super.key,
    required this.message,
  });

  final String message;

  @override
  State<ReminderAlarmWindowPage> createState() =>
      _ReminderAlarmWindowPageState();
}

class _ReminderAlarmWindowPageState extends State<ReminderAlarmWindowPage> {
  static const Size _windowSize = ReminderAlarmPanel.panelSize;
  static const double _screenMargin = 24;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_configureWindow());
    });
  }

  Future<void> _configureWindow() async {
    try {
      await windowManager.ensureInitialized();
      await windowManager.setAsFrameless();
      await windowManager.waitUntilReadyToShow(
        const WindowOptions(
          size: _windowSize,
          minimumSize: _windowSize,
          maximumSize: _windowSize,
          alwaysOnTop: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: true,
          title: '',
        ),
      );
      await windowManager.setResizable(false);
      await windowManager.setMinimizable(false);
      await windowManager.setMaximizable(false);
      await windowManager.setHasShadow(true);
      await _moveToBottomRight();
      await windowManager.show(inactive: true);
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('[ReminderAlarmWindow] configure failed: $error');
      }
    } on MissingPluginException catch (error) {
      if (kDebugMode) {
        debugPrint('[ReminderAlarmWindow] window plugin unavailable: $error');
      }
    }
  }

  Future<void> _moveToBottomRight() async {
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

    // Windows 桌面提醒贴近系统通知习惯，显示在工作区右下角且避开任务栏。
    await windowManager.setBounds(
      Rect.fromLTWH(left, top, _windowSize.width, _windowSize.height),
    );
  }

  Future<void> _closeWindow() async {
    try {
      await windowManager.close();
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('[ReminderAlarmWindow] close failed: $error');
      }
    } on MissingPluginException catch (error) {
      if (kDebugMode) {
        debugPrint('[ReminderAlarmWindow] close plugin unavailable: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = widget.message.trim();
    final message =
        trimmed.isEmpty ? context.l10n.reminderAlarmDefaultBody : trimmed;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ReminderAlarmPanel(
          message: message,
          reminderTime: DateTime.now(),
          onLater: () => unawaited(_closeWindow()),
          onConfirm: () => unawaited(_closeWindow()),
        ),
      ),
    );
  }
}
