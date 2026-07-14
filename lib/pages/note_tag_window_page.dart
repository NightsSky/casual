import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';
import '../utils/markdown_utils.dart';

/// 标签模式子窗口（仅 Windows 桌面、仅 txt）。
///
/// 是独立笔记窗口的优化形态：默认呈现为贴屏幕右侧的折叠胶囊，只显示正文首行，
/// 可拖动移动；点击胶囊在原窗口内展开为可编辑的完整正文。与普通独立窗口一样，
/// 本窗口是"哑编辑器"——初始内容来自 createWindow 的 JSON 参数，每次编辑通过
/// 窗口间 method channel 回传主窗口（windowId 0）统一持久化，绝不直写本地存储。
class NoteTagWindowApp extends StatelessWidget {
  const NoteTagWindowApp({
    super.key,
    required this.windowController,
    required this.arguments,
  });

  final WindowController windowController;
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
      home: NoteTagWindowPage(
        noteId: arguments['noteId'] as String? ?? '',
        initialContent: arguments['content'] as String? ?? '',
      ),
    );
  }
}

class NoteTagWindowPage extends StatefulWidget {
  const NoteTagWindowPage({
    super.key,
    required this.noteId,
    required this.initialContent,
  });

  final String noteId;
  final String initialContent;

  @override
  State<NoteTagWindowPage> createState() => _NoteTagWindowPageState();
}

class _NoteTagWindowPageState extends State<NoteTagWindowPage> {
  // 折叠胶囊本体高度（可视部分）。
  static const double _capsuleHeight = 52;
  // 胶囊下方预留的透明区高度：给 Flutter Tooltip 与投影留出渲染空间。
  // 折叠窗口若只有胶囊本身大小，Overlay 会被窗口边界裁掉，悬浮提示与投影
  // 都显示不出来（展开态窗口够大所以正常）。
  static const double _capsuleTooltipGap = 56;
  // 折叠胶囊态窗口尺寸需与 NoteWindowService._tagWindowSize 保持一致，
  // 保证主窗口给出的初始贴边落点与子窗口自身的折叠尺寸吻合。
  static const Size _collapsedSize =
      Size(240, _capsuleHeight + _capsuleTooltipGap);
  static const Size _expandedSize = Size(300, 420);

  late final TextEditingController _contentController;
  late final FocusNode _contentFocusNode;
  bool _expanded = false;
  bool _mainWindowUnreachable = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);
    _contentFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_configureNativeWindow());
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _configureNativeWindow() async {
    try {
      await windowManager.ensureInitialized();
      // 胶囊便签为无边框圆角窗口，隐藏原生标题栏与系统按钮，背景透明以透出圆角。
      await windowManager.setAsFrameless();
      // 便签形态贴边常驻：常置顶避免切到别的应用后被遮住；不占用任务栏，
      // 与桌面便签的使用直觉一致（关闭仍走展开态的关闭按钮）。
      //
      // skipTaskbar / alwaysOnTop 必须经 waitUntilReadyToShow 作为初始窗口选项
      // 一次性设好：window_manager 的原生 setSkipTaskbar 依赖该阶段初始化的任务栏
      // COM 对象，子引擎若跳过它直接调 setSkipTaskbar 会访问未初始化对象而崩溃
      // （提醒弹窗 ReminderAlarmWindowPage 用的正是这条已验证可用的链路）。
      await windowManager.waitUntilReadyToShow(
        const WindowOptions(
          skipTaskbar: true,
          alwaysOnTop: true,
          backgroundColor: Colors.transparent,
          title: '',
        ),
      );
      await windowManager.setResizable(false);
      // 关闭原生窗口阴影：折叠窗口含下方透明区，系统阴影会沿整个窗口矩形描出
      // 一圈多余边框。胶囊本体与展开容器各自带 Flutter boxShadow，投影已足够。
      await windowManager.setHasShadow(false);
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('[NoteTagWindow] configure native window failed: $error');
      }
    } on MissingPluginException catch (error) {
      if (kDebugMode) {
        debugPrint('[NoteTagWindow] window plugin unavailable: $error');
      }
    }
  }

  /// 折叠 <-> 展开切换。展开时窗口纵向变大，并锚定当前右边缘向左扩展，
  /// 保持贴边便签的视觉位置不跳动；折叠时反向还原。
  Future<void> _toggleExpanded() async {
    final next = !_expanded;
    setState(() => _expanded = next);
    await _applyWindowSize(next);
    if (next) {
      // 子窗口独立引擎单靠 autofocus 偶尔拿不到焦点，展开后主动聚焦正文。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _contentFocusNode.requestFocus();
      });
    }
  }

  Future<void> _applyWindowSize(bool expanded) async {
    final size = expanded ? _expandedSize : _collapsedSize;
    try {
      await windowManager.ensureInitialized();
      final bounds = await windowManager.getBounds();
      // 锚定右边缘：新左边 = 原右边 - 新宽度，宽高按目标态设置。
      final right = bounds.left + bounds.width;
      final newLeft = right - size.width;
      await windowManager.setBounds(
        Rect.fromLTWH(newLeft, bounds.top, size.width, size.height),
      );
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('[NoteTagWindow] resize failed: $error');
      }
    } on MissingPluginException catch (error) {
      if (kDebugMode) {
        debugPrint('[NoteTagWindow] resize plugin unavailable: $error');
      }
    }
  }

  /// 每次输入全量回传主窗口，与普通独立窗口"onChanged 即保存"一致，
  /// 保证子窗口任何时刻被关闭都不丢失内容。txt 标题由主窗口按首行自行派生。
  Future<void> _pushUpdate() async {
    setState(() {}); // 刷新折叠态首行预览
    try {
      await DesktopMultiWindow.invokeMethod(0, 'noteWindow.update', {
        'noteId': widget.noteId,
        'content': _contentController.text,
      });
      if (_mainWindowUnreachable && mounted) {
        setState(() => _mainWindowUnreachable = false);
      }
    } on PlatformException {
      if (!_mainWindowUnreachable && mounted) {
        setState(() => _mainWindowUnreachable = true);
      }
    } on MissingPluginException {
      if (!_mainWindowUnreachable && mounted) {
        setState(() => _mainWindowUnreachable = true);
      }
    }
  }

  Future<void> _closeWindow() async {
    try {
      await windowManager.ensureInitialized();
      await windowManager.close();
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('[NoteTagWindow] close failed: $error');
      }
    } on MissingPluginException catch (error) {
      if (kDebugMode) {
        debugPrint('[NoteTagWindow] close plugin unavailable: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _expanded ? _buildExpanded(context) : _buildCollapsed(context),
    );
  }

  /// 折叠胶囊：整体可拖动移动窗口，右侧展开图标点击展开为完整正文。
  ///
  /// 拖动与点击分工到不同手势载体，避免相互抢占：胶囊主体用 DragToMoveArea
  /// 承接窗口拖动（按住任意位置即可移动），仅右侧展开按钮走点击手势。
  Widget _buildCollapsed(BuildContext context) {
    final firstLine = deriveTxtTitle(_contentController.text);
    final label = firstLine.isEmpty ? context.l10n.untitledNote : firstLine;

    // 胶囊贴窗口顶部右侧，下方 _capsuleTooltipGap 透明区专供 Tooltip 与投影落地。
    return Align(
      alignment: Alignment.topRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: _capsuleHeight,
          decoration: BoxDecoration(
            // 主色到深主色的斜向渐变，给扁平胶囊补一点体积感。
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(AppRadius.full),
            ),
            // 顶部细高光 + 底部投影，模拟贴边悬浮的柔和层次。
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 18,
                spreadRadius: -2,
                offset: const Offset(-3, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // 左侧竖向强调条替代拖动手柄图标：更轻，且暗示这是便签胶囊；
              // 拖动语义交由整块 DragToMoveArea 承接。
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // 主体（强调条右侧首行文字）整块作为拖动区，按住即可移动窗口。
              Expanded(
                child: Tooltip(
                  message: context.l10n.noteWindowMove,
                  child: DragToMoveArea(
                    child: SizedBox(
                      height: _capsuleHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppFontSize.sm,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // 展开按钮：半透明白色圆底承托图标，悬浮时加深，点击目标更明确。
              Tooltip(
                message: context.l10n.noteTagExpand,
                child: InkWell(
                  onTap: () => unawaited(_toggleExpanded()),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  hoverColor: Colors.white.withValues(alpha: 0.18),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.unfold_more,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 展开态：顶部操作行（拖动 + 折叠 + 关闭）+ 可编辑正文。
  Widget _buildExpanded(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (_mainWindowUnreachable) _buildUnreachableBanner(context),
          _buildExpandedHeader(context),
          const Divider(height: 1, thickness: 0.5),
          Expanded(child: _buildContentField(context)),
        ],
      ),
    );
  }

  Widget _buildUnreachableBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      color: AppColors.error.withValues(alpha: 0.1),
      child: Text(
        context.l10n.noteWindowUnreachable,
        style:
            const TextStyle(fontSize: AppFontSize.xs, color: AppColors.error),
      ),
    );
  }

  Widget _buildExpandedHeader(BuildContext context) {
    final firstLine = deriveTxtTitle(_contentController.text);
    final title = firstLine.isEmpty ? context.l10n.untitledNote : firstLine;

    Widget control({
      required String tooltip,
      required IconData icon,
      required VoidCallback onPressed,
      bool isClose = false,
    }) {
      return Tooltip(
        message: tooltip,
        child: IconButton(
          icon: Icon(icon, size: 18),
          onPressed: onPressed,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            foregroundColor:
                isClose ? AppColors.error : AppColors.textSecondary,
            hoverColor: (isClose ? AppColors.error : AppColors.primaryLight)
                .withValues(alpha: 0.14),
            minimumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      );
    }

    return Container(
      color: AppColors.bgTertiary,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Row(
        children: [
          Tooltip(
            message: context.l10n.noteWindowMove,
            child: DragToMoveArea(
              child: Container(
                width: 24,
                height: 32,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: AppColors.textPlaceholder,
                ),
              ),
            ),
          ),
          Expanded(
            child: DragToMoveArea(
              child: SizedBox(
                height: 32,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          control(
            tooltip: context.l10n.noteTagCollapse,
            icon: Icons.unfold_less,
            onPressed: () => unawaited(_toggleExpanded()),
          ),
          control(
            tooltip: context.l10n.noteWindowClose,
            icon: Icons.close,
            onPressed: () => unawaited(_closeWindow()),
            isClose: true,
          ),
        ],
      ),
    );
  }

  Widget _buildContentField(BuildContext context) {
    return Container(
      color: AppColors.bgTertiary,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: TextField(
        controller: _contentController,
        focusNode: _contentFocusNode,
        maxLines: null,
        expands: true,
        cursorColor: AppColors.primary,
        style: const TextStyle(
          fontSize: AppFontSize.base,
          height: 1.6,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: context.l10n.startWriting,
          hintStyle: const TextStyle(color: AppColors.textPlaceholder),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (_) => _pushUpdate(),
        textAlignVertical: TextAlignVertical.top,
      ),
    );
  }
}
