import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/models/note.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';
import '../utils/markdown_utils.dart';
import '../widgets/markdown_preview.dart';

enum _NoteWindowMarkdownMode { edit, split, preview }

/// 独立笔记窗口（仅 Windows 桌面）。
///
/// 运行在 desktop_multi_window 创建的子 Flutter 引擎中，与主窗口不共享
/// isolate 和任何内存状态。本窗口是"哑编辑器"：初始内容来自
/// createWindow 的 JSON 参数，之后的每次编辑都通过窗口间 method channel
/// 实时回传主窗口（windowId 0），由主窗口的 notesProvider 统一更新与持久化。
/// 子窗口自身绝不读写 SharedPreferences——两个引擎各持独立缓存，
/// 直接写会整表覆盖导致丢数据。
class NoteWindowApp extends StatelessWidget {
  const NoteWindowApp({
    super.key,
    required this.windowController,
    required this.arguments,
  });

  final WindowController windowController;
  final Map<String, dynamic> arguments;

  @override
  Widget build(BuildContext context) {
    final formatName = arguments['format'] as String?;
    final initialFormat = NoteFormat.values.firstWhere(
      (format) => format.name == formatName,
      orElse: () => NoteFormat.txt,
    );

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
      home: NoteWindowEditorPage(
        windowController: windowController,
        noteId: arguments['noteId'] as String? ?? '',
        initialTitle: arguments['title'] as String? ?? '',
        initialContent: arguments['content'] as String? ?? '',
        initialFormat: initialFormat,
      ),
    );
  }
}

/// 记事本风格的轻量编辑页：标题 + 正文 + 底部字数。
/// txt 与 Markdown 都在同一窗口内提供编辑/预览切换：
/// txt 预览为可选中纯文本，Markdown 预览为渲染结果，与主编辑器保持一致。
class NoteWindowEditorPage extends StatefulWidget {
  const NoteWindowEditorPage({
    super.key,
    required this.windowController,
    required this.noteId,
    required this.initialTitle,
    required this.initialContent,
    required this.initialFormat,
  });

  final WindowController windowController;
  final String noteId;
  final String initialTitle;
  final String initialContent;
  final NoteFormat initialFormat;

  @override
  State<NoteWindowEditorPage> createState() => _NoteWindowEditorPageState();
}

class _NoteWindowEditorPageState extends State<NoteWindowEditorPage>
    with WindowListener {
  static const double _windowEditorMaxWidth = 920;
  static const double _windowPreviewMaxWidth = 820;

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final FocusNode _contentFocusNode;
  bool _mainWindowUnreachable = false;
  bool _isAlwaysOnTop = false;
  bool _isChangingAlwaysOnTop = false;
  bool _isMaximized = false;
  double _windowOpacity = 1.0;
  late bool _isPreview;
  late _NoteWindowMarkdownMode _markdownMode;

  // 独立窗口本身是 Windows 专属工作区，默认收起工具栏以优先保证分屏可用高度。
  bool _showMarkdownToolbar = false;

  static const double _minWindowOpacity = 0.35;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
    _contentFocusNode = FocusNode();
    // Markdown 独立窗口默认分屏，拖出笔记后仍可同时编辑源码和核对渲染结果；
    // txt 保留原有的只读预览默认值。
    _markdownMode = widget.initialFormat == NoteFormat.markdown
        ? _NoteWindowMarkdownMode.split
        : _NoteWindowMarkdownMode.preview;
    _isPreview = widget.initialFormat != NoteFormat.markdown;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_configureNativeWindow());
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _configureNativeWindow() async {
    try {
      await windowManager.ensureInitialized();
      // 独立笔记窗口已经在内容区显示笔记标题和窗口操作，
      // 这里隐藏 Windows 原生标题栏，避免顶部多出一条空白系统栏。
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      await windowManager.setTitle('');
      final isMaximized = await windowManager.isMaximized();
      if (mounted) {
        setState(() => _isMaximized = isMaximized);
      }
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('[NoteWindow] configure native window failed: $error');
      }
    } on MissingPluginException catch (error) {
      if (kDebugMode) {
        debugPrint('[NoteWindow] window plugin unavailable: $error');
      }
    }
  }

  /// 每次输入都全量回传主窗口，与主窗口编辑器"onChanged 即保存"的行为一致，
  /// 保证子窗口任何时刻被关闭（包括进程退出）都不丢失已输入内容。
  Future<void> _pushUpdate() async {
    setState(() {}); // 刷新底部字数
    try {
      await DesktopMultiWindow.invokeMethod(0, 'noteWindow.update', {
        'noteId': widget.noteId,
        'title': _titleController.text,
        'content': _contentController.text,
      });
      if (_mainWindowUnreachable && mounted) {
        setState(() => _mainWindowUnreachable = false);
      }
    } on PlatformException {
      // 主窗口不可达（正常情况下主窗口退出即整个进程退出，此为防御分支）。
      if (!_mainWindowUnreachable && mounted) {
        setState(() => _mainWindowUnreachable = true);
      }
    } on MissingPluginException {
      // 测试环境或插件未注册时不让输入链路崩溃，界面提示保存通道不可达。
      if (!_mainWindowUnreachable && mounted) {
        setState(() => _mainWindowUnreachable = true);
      }
    }
  }

  void _onTitleChanged(String _) {
    _pushUpdate();
  }

  void _requestContentFocus() {
    if (!mounted) return;
    // 仅预览态没有可编辑的正文 TextField；分屏的源码面板仍可接收焦点。
    if (_isPreview && _markdownMode != _NoteWindowMarkdownMode.split) return;
    _contentFocusNode.requestFocus();
  }

  void _toggleTxtPreviewMode() {
    setState(() => _isPreview = !_isPreview);
    if (!_isPreview) {
      // Windows 子窗口运行在独立 Flutter 引擎中，单靠 autofocus 偶尔拿不到
      // 可编辑控件焦点；切回编辑态后主动聚焦正文，保证输入法能绑定到 TextField。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestContentFocus();
      });
    }
  }

  /// Markdown 独立窗口提供与主编辑器一致的编辑、分屏和预览三态。
  void _setMarkdownMode(_NoteWindowMarkdownMode mode) {
    setState(() {
      _markdownMode = mode;
      _isPreview = mode == _NoteWindowMarkdownMode.preview;
    });
    if (mode != _NoteWindowMarkdownMode.preview) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestContentFocus();
      });
    }
  }

  Future<void> _toggleAlwaysOnTop() async {
    if (_isChangingAlwaysOnTop) return;

    final next = !_isAlwaysOnTop;
    setState(() {
      _isAlwaysOnTop = next;
      _isChangingAlwaysOnTop = true;
    });

    try {
      // 独立笔记窗口只在 Windows 桌面启用；子窗口原生侧仅注册 window_manager，
      // 这里直接切换当前子窗口 HWND 的 TopMost 状态，不影响主窗口层级。
      await windowManager.ensureInitialized();
      await windowManager.setAlwaysOnTop(next);
    } on PlatformException {
      if (mounted) setState(() => _isAlwaysOnTop = !next);
    } on MissingPluginException {
      if (mounted) setState(() => _isAlwaysOnTop = !next);
    } finally {
      if (mounted) setState(() => _isChangingAlwaysOnTop = false);
    }
  }

  Future<void> _minimizeWindow() async {
    try {
      await windowManager.ensureInitialized();
      await windowManager.minimize();
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('[NoteWindow] minimize failed: $error');
      }
    } on MissingPluginException catch (error) {
      if (kDebugMode) {
        debugPrint('[NoteWindow] minimize plugin unavailable: $error');
      }
    }
  }

  Future<void> _toggleMaximizeWindow() async {
    try {
      await windowManager.ensureInitialized();
      if (_isMaximized) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
      if (mounted) {
        setState(() => _isMaximized = !_isMaximized);
      }
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('[NoteWindow] toggle maximize failed: $error');
      }
    } on MissingPluginException catch (error) {
      if (kDebugMode) {
        debugPrint('[NoteWindow] toggle maximize plugin unavailable: $error');
      }
    }
  }

  Future<void> _closeWindow() async {
    try {
      await windowManager.ensureInitialized();
      await windowManager.close();
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('[NoteWindow] close failed: $error');
      }
    } on MissingPluginException catch (error) {
      if (kDebugMode) {
        debugPrint('[NoteWindow] close plugin unavailable: $error');
      }
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  void onWindowRestore() {
    if (mounted) setState(() => _isMaximized = false);
  }

  Future<void> _showOpacityDialog() async {
    var draftOpacity = _windowOpacity;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final percent = (draftOpacity * 100).round();

            return AlertDialog(
              title: Text(context.l10n.noteWindowOpacity),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.opacity,
                            size: 20, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          context.l10n.noteWindowOpacityValue(percent),
                          style: const TextStyle(
                            fontSize: AppFontSize.base,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: draftOpacity,
                      min: _minWindowOpacity,
                      max: 1,
                      divisions: 13,
                      label: context.l10n.noteWindowOpacityValue(percent),
                      onChanged: (value) {
                        setDialogState(() => draftOpacity = value);
                        setState(() => _windowOpacity = value);

                        // 透明度只调整当前独立笔记窗口，保留最低 35% 防止窗口过淡后难以找回。
                        windowManager.ensureInitialized().then((_) {
                          return windowManager.setOpacity(value);
                        }).catchError((_) {
                          // 测试环境或插件不可用时忽略，避免透明度面板影响编辑链路。
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.confirm),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wordCount =
        _contentController.text.replaceAll(RegExp(r'\s'), '').length;
    final isMarkdown = widget.initialFormat == NoteFormat.markdown;

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      body: Column(
        children: [
          if (_mainWindowUnreachable) _buildUnreachableBanner(context),
          _buildTitleField(context),
          const Divider(height: 1, thickness: 0.5),
          Expanded(
            child: isMarkdown
                ? (_markdownMode == _NoteWindowMarkdownMode.split
                    ? _buildMarkdownSplit(context)
                    : (_markdownMode == _NoteWindowMarkdownMode.preview
                        ? _buildMarkdownPreview(context)
                        : _buildMarkdownEditor(context)))
                : (_isPreview
                    ? _buildTxtPreview(context)
                    : _buildContentField(context)),
          ),
          _buildFooter(context, wordCount),
        ],
      ),
    );
  }

  Widget _buildUnreachableBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      color: AppColors.error.withValues(alpha: 0.1),
      child: Text(
        context.l10n.noteWindowUnreachable,
        style:
            const TextStyle(fontSize: AppFontSize.sm, color: AppColors.error),
      ),
    );
  }

  Widget _buildTitleField(BuildContext context) {
    // txt 无独立标题：标题从正文首行派生、只读展示（仍用于窗口辨识与拖动）；
    // md 保持可编辑，仅预览态只读。
    final isTxt = widget.initialFormat == NoteFormat.txt;
    final isTitleEditable = !isTxt && !_isPreview;
    final displayTitle =
        isTxt ? deriveTxtTitle(_contentController.text) : _titleController.text;
    final titleText =
        displayTitle.isEmpty ? context.l10n.untitledNote : displayTitle;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgTertiary,
        border: Border(
            bottom: BorderSide(color: AppColors.borderColor, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Tooltip(
            message: context.l10n.noteWindowMove,
            child: DragToMoveArea(
              child: Container(
                width: 28,
                height: 36,
                alignment: Alignment.centerLeft,
                child: const Icon(
                  Icons.drag_indicator,
                  size: 18,
                  color: AppColors.textPlaceholder,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: isTitleEditable
                ? TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: AppFontSize.xl,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                    decoration: InputDecoration(
                      hintText: context.l10n.enterTitle,
                      hintStyle: const TextStyle(
                        color: AppColors.textPlaceholder,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    cursorColor: AppColors.primary,
                    onChanged: _onTitleChanged,
                  )
                : DragToMoveArea(
                    child: SizedBox(
                      height: 36,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          titleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppFontSize.xl,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          if (isTxt)
            Tooltip(
              message: _isPreview ? context.l10n.edit : context.l10n.preview,
              child: IconButton(
                icon: Icon(
                  _isPreview ? Icons.edit_outlined : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: _toggleTxtPreviewMode,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  hoverColor: AppColors.primaryLight.withValues(alpha: 0.6),
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            )
          else ...[
            _buildMarkdownModeButton(context),
            Tooltip(
              message: _showMarkdownToolbar
                  ? context.l10n.hideMarkdownToolbar
                  : context.l10n.showMarkdownToolbar,
              child: IconButton(
                icon: Icon(
                  _showMarkdownToolbar
                      ? Icons.keyboard_hide_outlined
                      : Icons.format_align_left,
                  size: 19,
                ),
                onPressed: () => setState(
                    () => _showMarkdownToolbar = !_showMarkdownToolbar),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  hoverColor: AppColors.primaryLight.withValues(alpha: 0.6),
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ],
          Tooltip(
            message: _isAlwaysOnTop
                ? context.l10n.noteWindowUnpinFromTop
                : context.l10n.noteWindowPinToTop,
            child: IconButton(
              icon: Icon(
                _isAlwaysOnTop ? Icons.push_pin : Icons.push_pin_outlined,
                size: 20,
              ),
              onPressed: _isChangingAlwaysOnTop ? null : _toggleAlwaysOnTop,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                foregroundColor: _isAlwaysOnTop
                    ? AppColors.primary
                    : AppColors.textSecondary,
                hoverColor: AppColors.primaryLight.withValues(alpha: 0.6),
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
          Tooltip(
            message: context.l10n.noteWindowOpacity,
            child: IconButton(
              icon: const Icon(Icons.opacity, size: 20),
              onPressed: _showOpacityDialog,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                hoverColor: AppColors.primaryLight.withValues(alpha: 0.6),
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
          _buildWindowControls(context),
        ],
      ),
    );
  }

  /// 独立窗口用单个高亮图标标识当前 Markdown 视图，减少标题栏占用。
  Widget _buildMarkdownModeButton(BuildContext context) {
    final tooltip = switch (_markdownMode) {
      _NoteWindowMarkdownMode.edit => context.l10n.markdownEditOnly,
      _NoteWindowMarkdownMode.split => context.l10n.markdownSplitView,
      _NoteWindowMarkdownMode.preview => context.l10n.markdownPreviewOnly,
    };
    final icon = switch (_markdownMode) {
      _NoteWindowMarkdownMode.edit => Icons.edit_outlined,
      _NoteWindowMarkdownMode.split => Icons.vertical_split,
      _NoteWindowMarkdownMode.preview => Icons.visibility_outlined,
    };

    return Tooltip(
      message: tooltip,
      child: IconButton(
        key: const ValueKey('noteWindowMarkdownModeCycleButton'),
        icon: Icon(icon, size: 18),
        onPressed: _cycleMarkdownMode,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.65),
          minimumSize: const Size(34, 34),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }

  /// 独立窗口始终具备足够的 Markdown 工作区，因此固定循环三种完整视图。
  void _cycleMarkdownMode() {
    final nextMode = switch (_markdownMode) {
      _NoteWindowMarkdownMode.edit => _NoteWindowMarkdownMode.split,
      _NoteWindowMarkdownMode.split => _NoteWindowMarkdownMode.preview,
      _NoteWindowMarkdownMode.preview => _NoteWindowMarkdownMode.edit,
    };
    _setMarkdownMode(nextMode);
  }

  Widget _buildWindowControls(BuildContext context) {
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
                .withValues(alpha: 0.12),
            minimumSize: const Size(36, 36),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      );
    }

    // 原生标题栏隐藏后，窗口管理动作由内容标题行承接，
    // 保留最小化、最大化/还原和关闭这些桌面端基础操作。
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        control(
          tooltip: context.l10n.noteWindowMinimize,
          icon: Icons.minimize,
          onPressed: () => unawaited(_minimizeWindow()),
        ),
        control(
          tooltip: _isMaximized
              ? context.l10n.noteWindowRestore
              : context.l10n.noteWindowMaximize,
          icon: _isMaximized ? Icons.fullscreen_exit : Icons.fullscreen,
          onPressed: () => unawaited(_toggleMaximizeWindow()),
        ),
        control(
          tooltip: context.l10n.noteWindowClose,
          icon: Icons.close,
          onPressed: () => unawaited(_closeWindow()),
          isClose: true,
        ),
      ],
    );
  }

  Widget _buildContentField(BuildContext context) {
    return Container(
      color: AppColors.bgSecondary,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _windowEditorMaxWidth),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.bgTertiary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderColor, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: _contentController,
              focusNode: _contentFocusNode,
              maxLines: null,
              expands: true,
              autofocus: true,
              cursorColor: AppColors.primary,
              style: const TextStyle(
                fontSize: AppFontSize.base,
                height: 1.78,
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
          ),
        ),
      ),
    );
  }

  /// txt 预览：与主编辑器一致，用受限宽度的阅读纸张承载可选中的纯文本，
  /// 与编辑态共用同一份 _contentController，切回编辑不丢内容。
  Widget _buildTxtPreview(BuildContext context) {
    const bodyStyle = TextStyle(
      fontSize: AppFontSize.base,
      height: 1.85,
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w400,
    );

    return Container(
      color: AppColors.bgSecondary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= AppBreakpoints.tablet
              ? AppSpacing.xl
              : AppSpacing.md;
          final vertical = constraints.maxWidth < AppBreakpoints.mobile
              ? AppSpacing.md
              : AppSpacing.lg;
          final surfacePadding = constraints.maxWidth < AppBreakpoints.mobile
              ? AppSpacing.lg
              : AppSpacing.xl;
          final surfaceHeight = constraints.maxHeight > vertical * 2
              ? constraints.maxHeight - vertical * 2
              : 0.0;

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontal,
              vertical: vertical,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: _windowPreviewMaxWidth),
                child: SizedBox(
                  height: surfaceHeight,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(surfacePadding),
                    decoration: BoxDecoration(
                      color: AppColors.bgTertiary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.borderColor,
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.035),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _contentController.text,
                        style: bodyStyle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMarkdownEditor(BuildContext context) {
    return Column(
      children: [
        if (_showMarkdownToolbar) _buildMarkdownToolbar(context),
        Expanded(child: _buildContentField(context)),
      ],
    );
  }

  /// 拖出的 Windows 笔记窗口默认分屏：两个面板共享同一 controller，
  /// 输入经 IPC 回传主窗口，右侧随 State 刷新展示当前 Markdown 渲染结果。
  Widget _buildMarkdownSplit(BuildContext context) {
    return Container(
      color: AppColors.bgSecondary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isHorizontal = constraints.maxWidth >= 840;
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox.expand(
              child: isHorizontal
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildMarkdownSplitSource(context)),
                        const VerticalDivider(width: AppSpacing.md),
                        Expanded(child: _buildMarkdownSplitPreview()),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: _buildMarkdownSplitSource(context)),
                        const Divider(height: AppSpacing.md),
                        Expanded(child: _buildMarkdownSplitPreview()),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMarkdownSplitSource(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderColor, width: 0.8),
      ),
      child: Column(
        children: [
          if (_showMarkdownToolbar) _buildMarkdownToolbar(context),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                key: const ValueKey('noteWindowMarkdownSplitSource'),
                controller: _contentController,
                focusNode: _contentFocusNode,
                maxLines: null,
                expands: true,
                autofocus: true,
                cursorColor: AppColors.primary,
                style: const TextStyle(
                  fontSize: AppFontSize.base,
                  height: 1.72,
                  color: AppColors.textPrimary,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.startWriting,
                  hintStyle: const TextStyle(color: AppColors.textPlaceholder),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => _pushUpdate(),
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownSplitPreview() {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderColor, width: 0.8),
      ),
      child: MarkdownPreview(data: _contentController.text),
    );
  }

  Widget _buildMarkdownToolbar(BuildContext context) {
    Widget tool(IconData icon, String tooltip, String insertion) {
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xs),
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(icon, size: 18),
          onPressed: () => _insertMarkdownText(insertion),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            hoverColor: AppColors.primaryLight.withValues(alpha: 0.6),
            minimumSize: const Size(36, 36),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.bgTertiary,
        border: Border(
            bottom: BorderSide(color: AppColors.borderColor, width: 0.5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            tool(Icons.title, '标题', '## '),
            tool(Icons.format_bold, '加粗', '**粗体**'),
            tool(Icons.format_italic, '斜体', '*斜体*'),
            tool(Icons.format_quote, '引用', '\n> '),
            tool(Icons.format_list_bulleted, '列表', '\n- '),
            tool(Icons.check_box_outlined, '任务', '\n- [ ] '),
            tool(Icons.code, '代码块', '\n```\n代码\n```\n'),
            tool(Icons.link, '链接', '[链接文字](url)'),
            tool(Icons.image_outlined, '图片', '![图片描述](url)'),
            tool(Icons.horizontal_rule, '分隔线', '\n---\n'),
          ],
        ),
      ),
    );
  }

  void _insertMarkdownText(String text) {
    final selection = _contentController.selection;
    final currentText = _contentController.text;
    final start = selection.isValid ? selection.start : currentText.length;
    final end = selection.isValid ? selection.end : currentText.length;

    // Markdown 工具条只改正文源码，保存仍统一走主窗口 IPC，避免子窗口直接写本地缓存。
    _contentController.text = currentText.replaceRange(start, end, text);
    _contentController.selection =
        TextSelection.collapsed(offset: start + text.length);
    _pushUpdate();
  }

  Widget _buildMarkdownPreview(BuildContext context) {
    // Markdown 笔记拖出后仍由主窗口保存，这里只负责把当前正文渲染成可选中的预览。
    return Container(
      color: AppColors.bgSecondary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= AppBreakpoints.tablet
              ? AppSpacing.xl
              : AppSpacing.md;
          final vertical = constraints.maxWidth < AppBreakpoints.mobile
              ? AppSpacing.md
              : AppSpacing.lg;
          final surfacePadding = constraints.maxWidth < AppBreakpoints.mobile
              ? AppSpacing.lg
              : AppSpacing.xl;
          final surfaceHeight = constraints.maxHeight > vertical * 2
              ? constraints.maxHeight - vertical * 2
              : 0.0;

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontal,
              vertical: vertical,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: _windowPreviewMaxWidth),
                child: SizedBox(
                  height: surfaceHeight,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(surfacePadding),
                    decoration: BoxDecoration(
                      color: AppColors.bgTertiary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.borderColor,
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.035),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: MarkdownPreview(data: _contentController.text),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context, int wordCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      decoration: const BoxDecoration(
        color: AppColors.bgTertiary,
        border:
            Border(top: BorderSide(color: AppColors.borderColor, width: 0.5)),
      ),
      child: Text(
        context.l10n.noteWindowWordCount(wordCount),
        style: const TextStyle(
            fontSize: AppFontSize.xs, color: AppColors.textPlaceholder),
      ),
    );
  }
}
