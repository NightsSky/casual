import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/models/note.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';

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
/// txt 保持纯文本编辑，Markdown 在同一窗口内提供编辑/预览切换。
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

class _NoteWindowEditorPageState extends State<NoteWindowEditorPage> {
  static const double _windowEditorMaxWidth = 920;
  static const double _windowPreviewMaxWidth = 820;

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _mainWindowUnreachable = false;
  bool _isAlwaysOnTop = false;
  bool _isChangingAlwaysOnTop = false;
  double _windowOpacity = 1.0;
  late bool _isPreview;

  static const double _minWindowOpacity = 0.35;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
    // Markdown 笔记打开独立窗口时先展示渲染结果，避免第一屏退化成 txt 源码编辑体验。
    _isPreview = widget.initialFormat == NoteFormat.markdown;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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

  void _onTitleChanged(String value) {
    // 同步原生窗口标题栏，让任务栏/Alt+Tab 里能认出这篇笔记。
    widget.windowController
        .setTitle(value.isEmpty ? context.l10n.untitledNote : value);
    _pushUpdate();
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
                ? (_isPreview
                    ? _buildMarkdownPreview(context)
                    : _buildMarkdownEditor(context))
                : _buildContentField(context),
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
          Expanded(
            child: TextField(
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
                filled: false,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              cursorColor: AppColors.primary,
              onChanged: _onTitleChanged,
            ),
          ),
          if (widget.initialFormat == NoteFormat.markdown)
            Tooltip(
              message: _isPreview ? context.l10n.edit : context.l10n.preview,
              child: IconButton(
                icon: Icon(
                  _isPreview ? Icons.edit_outlined : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _isPreview = !_isPreview),
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
        ],
      ),
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

  Widget _buildMarkdownEditor(BuildContext context) {
    return Column(
      children: [
        _buildMarkdownToolbar(context),
        Expanded(child: _buildContentField(context)),
      ],
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
                    child: Markdown(
                      data: _contentController.text,
                      selectable: true,
                      padding: EdgeInsets.zero,
                      styleSheet: MarkdownStyleSheet(
                        h1: const TextStyle(
                          fontSize: AppFontSize.xxl,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: AppColors.textPrimary,
                          fontFamily: 'serif',
                        ),
                        h1Padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        h2: const TextStyle(
                          fontSize: AppFontSize.xl,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: AppColors.textPrimary,
                          fontFamily: 'serif',
                        ),
                        h2Padding: const EdgeInsets.only(top: AppSpacing.xs),
                        h3: const TextStyle(
                          fontSize: AppFontSize.lg,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          color: AppColors.textPrimary,
                        ),
                        p: const TextStyle(
                          fontSize: AppFontSize.base,
                          height: 1.82,
                          color: AppColors.textSecondary,
                        ),
                        pPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        blockSpacing: AppSpacing.md,
                        listIndent: AppSpacing.xl,
                        listBullet: const TextStyle(
                          fontSize: AppFontSize.base,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        code: const TextStyle(
                          fontSize: AppFontSize.sm,
                          color: AppColors.primaryDark,
                          backgroundColor: AppColors.primaryLight,
                          fontFamily: 'monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.borderColor,
                            width: 1,
                          ),
                        ),
                        codeblockPadding: const EdgeInsets.all(AppSpacing.md),
                        blockquote: const TextStyle(
                          fontSize: AppFontSize.base,
                          height: 1.82,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                        blockquotePadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: const Border(
                            left: BorderSide(
                              color: AppColors.primary,
                              width: 3,
                            ),
                          ),
                          color: AppColors.primaryLight.withValues(alpha: 0.28),
                        ),
                        a: const TextStyle(
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                        horizontalRuleDecoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: AppColors.borderColor,
                              width: 1,
                            ),
                          ),
                        ),
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
