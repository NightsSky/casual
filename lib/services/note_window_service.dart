import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/note.dart';
import '../providers/notes_provider.dart';

/// 已在独立窗口中打开的笔记 id 集合（仅主窗口 isolate 有效）。
/// 列表页用它显示"已拖出"角标，编辑页用它进入只读保护，防止双端互相覆盖。
final externallyOpenNotesProvider = StateProvider<Set<String>>((ref) => {});

final noteWindowServiceProvider = Provider<NoteWindowService>((ref) {
  final service = NoteWindowService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// 独立笔记窗口管理（仅 Windows 桌面，主窗口 isolate 侧）。
///
/// 架构约定：主窗口是唯一数据权威。子窗口（见 pages/note_window_page.dart）
/// 通过 desktop_multi_window 的窗口间 method channel 把编辑内容实时发回本
/// 服务，由 notesProvider 统一走 updateNote（时间戳、同步状态、标签提取、
/// SharedPreferences 持久化）。
///
/// 子窗口被用户直接关闭时 Dart 侧收不到任何回调，因此用周期轮询
/// getAllSubWindowIds 对账（插件原生侧在窗口销毁时同步移除注册表，
/// 结果可靠）；对账同时负责把已被删除笔记的子窗口关掉。
class NoteWindowService {
  NoteWindowService(this._ref);

  final Ref _ref;

  /// noteId -> windowId
  final Map<String, int> _noteWindows = {};
  Timer? _reconcileTimer;
  bool _handlerInstalled = false;

  static const _windowSize = Size(520, 640);
  static const _reconcileInterval = Duration(seconds: 2);

  /// 多窗口功能仅 Windows 桌面开放。macOS/Linux 虽然插件支持，
  /// 但本项目未做适配验证（原生入口注册、窗口样式），暂不放开。
  static bool get isSupported => !kIsWeb && Platform.isWindows;

  /// 笔记是否支持拖出：Windows 桌面端的 txt 与 Markdown 都可打开独立窗口。
  static bool canDetach(Note note) =>
      isSupported &&
      (note.format == NoteFormat.txt || note.format == NoteFormat.markdown);

  /// 在独立窗口中打开笔记；若已打开则聚焦既有窗口（去重）。
  Future<void> openNoteWindow(Note note) async {
    if (!canDetach(note)) return;
    _ensureHandler();

    if (await _focusIfAlive(note.id)) return;

    final controller = await DesktopMultiWindow.createWindow(jsonEncode({
      'noteId': note.id,
      'title': note.title,
      'content': note.content,
      'format': note.format.name,
    }));
    // 多个窗口按打开顺序阶梯错开，避免完全重叠。
    final cascade = (_noteWindows.length % 5) * 32.0;
    await controller.setFrame(
      Offset(160 + cascade, 120 + cascade) & _windowSize,
    );
    await controller.setTitle(note.title.isEmpty ? 'GitNote' : note.title);
    await controller.show();

    _noteWindows[note.id] = controller.windowId;
    _syncOpenSet();
    _startReconcile();
  }

  /// 聚焦某笔记的独立窗口（若存在）。供编辑页只读横幅的"聚焦窗口"按钮使用。
  Future<void> focusNoteWindow(String noteId) async {
    await _focusIfAlive(noteId);
  }

  /// 窗口仍存活则前置显示并返回 true；已死则清理注册并返回 false。
  Future<bool> _focusIfAlive(String noteId) async {
    final windowId = _noteWindows[noteId];
    if (windowId == null) return false;

    final alive = await DesktopMultiWindow.getAllSubWindowIds();
    if (!alive.contains(windowId)) {
      _noteWindows.remove(noteId);
      _syncOpenSet();
      return false;
    }
    try {
      await WindowController.fromWindowId(windowId).show();
      return true;
    } on PlatformException {
      // show 与存活检查之间窗口刚好被关闭。
      _noteWindows.remove(noteId);
      _syncOpenSet();
      return false;
    }
  }

  /// 安装窗口间消息处理器。整个 isolate 只有一个全局 handler，
  /// 项目内约定由本服务独占，方法名以 noteWindow. 前缀命名空间隔离。
  void _ensureHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;

    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method == 'noteWindow.update') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final noteId = args['noteId'] as String?;
        if (noteId == null) return null;
        // 笔记若已在主窗口被删除，updateNote 找不到 id 返回 null，安全忽略。
        _ref.read(notesProvider.notifier).updateNote(
              noteId,
              title: args['title'] as String?,
              content: args['content'] as String?,
            );
      }
      return null;
    });
  }

  void _startReconcile() {
    _reconcileTimer ??= Timer.periodic(_reconcileInterval, (_) => _reconcile());
  }

  Future<void> _reconcile() async {
    if (_noteWindows.isEmpty) {
      _reconcileTimer?.cancel();
      _reconcileTimer = null;
      return;
    }

    // 1. 清理已被用户关闭的子窗口。
    final alive = (await DesktopMultiWindow.getAllSubWindowIds()).toSet();
    _noteWindows.removeWhere((_, windowId) => !alive.contains(windowId));

    // 2. 笔记已在主窗口被删除 → 关闭对应子窗口（注册表在下一轮对账移除）。
    final existingIds = _ref.read(notesProvider).notes.map((n) => n.id).toSet();
    for (final entry in _noteWindows.entries) {
      if (!existingIds.contains(entry.key)) {
        try {
          await WindowController.fromWindowId(entry.value).close();
        } on PlatformException {
          // 窗口恰好已被关闭，忽略。
        }
      }
    }

    _syncOpenSet();
  }

  void _syncOpenSet() {
    final next = _noteWindows.keys.toSet();
    final provider = _ref.read(externallyOpenNotesProvider.notifier);
    if (!setEquals(provider.state, next)) {
      provider.state = next;
    }
  }

  void dispose() {
    _reconcileTimer?.cancel();
    _reconcileTimer = null;
  }
}
