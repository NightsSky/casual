import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../services/external_markdown_file_service.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';
import '../utils/front_matter.dart';
import '../widgets/markdown_preview.dart';

enum _ExternalMarkdownViewMode { edit, split, preview }

/// 用于直接查看和编辑电脑中已有 Markdown 文件的独立页面。
///
/// 它不创建应用笔记，也不写入 Git 同步队列；Windows 上的保存操作只会覆盖
/// 用户刚刚选择的原文件，因而不会修改 front matter 或转换文件格式。
class ExternalMarkdownPage extends StatefulWidget {
  const ExternalMarkdownPage({
    super.key,
    required this.file,
  });

  final ExternalMarkdownFile file;

  @override
  State<ExternalMarkdownPage> createState() => _ExternalMarkdownPageState();
}

class _ExternalMarkdownPageState extends State<ExternalMarkdownPage> {
  static const _splitMinWidth = 840.0;

  final _fileService = ExternalMarkdownFileService();
  late final TextEditingController _contentController;
  late final FocusNode _contentFocusNode;
  _ExternalMarkdownViewMode _viewMode = _ExternalMarkdownViewMode.split;
  bool _showToolbar = !Platform.isWindows;
  bool _isFocusMode = false;
  bool _isDirty = false;
  bool _isSaving = false;

  bool get _canSaveInPlace =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// 外部文件保存时保留完整原文；预览时隐藏 YAML front matter，
  /// 与常见 Markdown 工具的阅读体验一致。
  String get _previewContent => parseFrontMatter(_contentController.text).body;

  String get _imageDirectory {
    final directory = '${path.dirname(widget.file.path)}${path.separator}';
    // flutter_markdown_plus 会将 imageDirectory 与相对 URI 直接拼接，
    // 因此必须传入 file:/// URI，而不是 Windows 的 C:\\ 路径字符串。
    return Uri.file(directory, windows: Platform.isWindows).toString();
  }

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.file.content);
    _contentFocusNode = FocusNode();
    if (!_canSaveInPlace) {
      // 移动端打开第三方文件时使用预览优先，避免只读源码框让用户误解为可保存。
      _viewMode = _ExternalMarkdownViewMode.preview;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
      },
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: !_isDirty,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop || !_isDirty) return;
            _requestClose();
          },
          child: Scaffold(
            backgroundColor: AppColors.bgSecondary,
            body: _isFocusMode
                ? _buildFocusWorkspace()
                : Column(
                    children: [
                      _buildHeader(),
                      if (!_canSaveInPlace) _buildReadOnlyNotice(),
                      Expanded(child: _buildWorkspace()),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final fileName = path.basename(widget.file.path);
    final wide = MediaQuery.sizeOf(context).width >= _splitMinWidth;

    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.bgTertiary,
          border: Border(
            bottom: BorderSide(color: AppColors.borderColor, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Tooltip(
              message: MaterialLocalizations.of(context).backButtonTooltip,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: _requestClose,
                visualDensity: VisualDensity.compact,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppFontSize.base,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.file.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppFontSize.xs,
                      color: AppColors.textPlaceholder,
                    ),
                  ),
                ],
              ),
            ),
            _buildModeButton(wide),
            if (_canSaveInPlace)
              Tooltip(
                message: _showToolbar
                    ? context.l10n.hideMarkdownToolbar
                    : context.l10n.showMarkdownToolbar,
                child: IconButton(
                  icon: Icon(
                    _showToolbar
                        ? Icons.keyboard_hide_outlined
                        : Icons.format_align_left,
                    size: 19,
                  ),
                  onPressed: () => setState(() => _showToolbar = !_showToolbar),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (_canSaveInPlace)
              Tooltip(
                message: context.l10n.saveMarkdownFile,
                child: IconButton(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.save_outlined,
                          size: 20,
                          color: _isDirty
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                  onPressed: _isSaving || !_isDirty ? null : _save,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            Tooltip(
              message: context.l10n.enterMarkdownFocus,
              child: IconButton(
                icon: const Icon(Icons.fullscreen, size: 20),
                onPressed: () => setState(() => _isFocusMode = true),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 移动端文件选择得到的授权通常只读或不可回写，因此保留原文预览，
  /// 避免用户误以为修改会稳定保存回第三方文件位置。
  Widget _buildReadOnlyNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.warning.withValues(alpha: 0.12),
      child: Text(
        context.l10n.externalMarkdownReadOnly,
        style: const TextStyle(
          fontSize: AppFontSize.sm,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildFocusWorkspace() {
    final wide = MediaQuery.sizeOf(context).width >= _splitMinWidth;
    return Stack(
      children: [
        Positioned.fill(child: _buildWorkspace()),
        Positioned(
          top: AppSpacing.md,
          right: AppSpacing.md,
          child: SafeArea(
            child: Material(
              color: AppColors.bgTertiary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeButton(wide),
                    if (_canSaveInPlace)
                      Tooltip(
                        message: context.l10n.saveMarkdownFile,
                        child: IconButton(
                          icon: const Icon(Icons.save_outlined, size: 19),
                          onPressed: _isSaving || !_isDirty ? null : _save,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    Tooltip(
                      message: context.l10n.exitMarkdownFocus,
                      child: IconButton(
                        icon: const Icon(Icons.fullscreen_exit, size: 19),
                        onPressed: () => setState(() => _isFocusMode = false),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 外部 Markdown 与应用内编辑器共用单按钮切换方式，图标始终表示当前视图。
  Widget _buildModeButton(bool allowSplit) {
    final visibleMode =
        !allowSplit && _viewMode == _ExternalMarkdownViewMode.split
            ? _ExternalMarkdownViewMode.edit
            : _viewMode;
    final tooltip = switch (visibleMode) {
      _ExternalMarkdownViewMode.edit => context.l10n.markdownEditOnly,
      _ExternalMarkdownViewMode.split => context.l10n.markdownSplitView,
      _ExternalMarkdownViewMode.preview => context.l10n.markdownPreviewOnly,
    };
    final icon = switch (visibleMode) {
      _ExternalMarkdownViewMode.edit => Icons.edit_outlined,
      _ExternalMarkdownViewMode.split => Icons.vertical_split,
      _ExternalMarkdownViewMode.preview => Icons.visibility_outlined,
    };

    return Tooltip(
      message: tooltip,
      child: IconButton(
        key: const ValueKey('externalMarkdownModeCycleButton'),
        icon: Icon(icon, size: 18),
        onPressed: _canSaveInPlace
            ? () => _cycleViewMode(allowSplit, visibleMode)
            : null,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.primary,
          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.65),
          disabledBackgroundColor:
              AppColors.primaryLight.withValues(alpha: 0.65),
          minimumSize: const Size(34, 34),
        ),
      ),
    );
  }

  /// 只在当前宽度可承载双面板时进入分屏，移动窄屏在编辑和预览之间循环。
  void _cycleViewMode(
    bool allowSplit,
    _ExternalMarkdownViewMode visibleMode,
  ) {
    final nextMode = switch (visibleMode) {
      _ExternalMarkdownViewMode.edit when allowSplit =>
        _ExternalMarkdownViewMode.split,
      _ExternalMarkdownViewMode.edit => _ExternalMarkdownViewMode.preview,
      _ExternalMarkdownViewMode.split => _ExternalMarkdownViewMode.preview,
      _ExternalMarkdownViewMode.preview => _ExternalMarkdownViewMode.edit,
    };
    _setViewMode(nextMode);
  }

  void _setViewMode(_ExternalMarkdownViewMode mode) {
    if (!_canSaveInPlace && mode != _ExternalMarkdownViewMode.preview) {
      return;
    }
    setState(() => _viewMode = mode);
    if (mode != _ExternalMarkdownViewMode.preview) {
      _contentFocusNode.requestFocus();
    }
  }

  Widget _buildWorkspace() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final supportsSplit = constraints.maxWidth >= _splitMinWidth;
        final mode = supportsSplit
            ? _viewMode
            : _viewMode == _ExternalMarkdownViewMode.split
                ? _ExternalMarkdownViewMode.edit
                : _viewMode;

        if (mode == _ExternalMarkdownViewMode.preview) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _buildPreviewPanel(),
          );
        }
        if (mode == _ExternalMarkdownViewMode.edit) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _buildEditorPanel(),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox.expand(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildEditorPanel()),
                const VerticalDivider(width: AppSpacing.lg),
                Expanded(child: _buildPreviewPanel()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditorPanel() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderColor, width: 0.8),
      ),
      child: Column(
        children: [
          if (_canSaveInPlace && _showToolbar) _buildToolbar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _contentController,
                focusNode: _contentFocusNode,
                readOnly: !_canSaveInPlace,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                cursorColor: AppColors.primary,
                style: const TextStyle(
                  fontSize: AppFontSize.base,
                  height: 1.72,
                  fontFamily: 'monospace',
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.externalMarkdownContentHint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => setState(() => _isDirty = true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel() {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderColor, width: 0.8),
      ),
      child: MarkdownPreview(
        data: _previewContent,
        imageDirectory: _imageDirectory,
      ),
    );
  }

  Widget _buildToolbar() {
    const tools = [
      _ExternalTool(Icons.title, '标题', '## '),
      _ExternalTool(Icons.format_bold, '加粗', '**粗体**'),
      _ExternalTool(Icons.format_italic, '斜体', '*斜体*'),
      _ExternalTool(Icons.format_list_bulleted, '列表', '\n- '),
      _ExternalTool(Icons.code, '代码块', '\n```\n代码\n```\n'),
      _ExternalTool(Icons.link, '链接', '[链接文字](url)'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(
          bottom: BorderSide(color: AppColors.borderColor, width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tools
              .map(
                (tool) => Tooltip(
                  message: tool.tooltip,
                  child: IconButton(
                    icon: Icon(tool.icon, size: 18),
                    onPressed: () => _insertMarkdownText(tool.insertion),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _insertMarkdownText(String text) {
    final selection = _contentController.selection;
    final currentText = _contentController.text;
    final start = selection.isValid ? selection.start : currentText.length;
    final end = selection.isValid ? selection.end : currentText.length;

    _contentController.text = currentText.replaceRange(start, end, text);
    _contentController.selection =
        TextSelection.collapsed(offset: start + text.length);
    _contentFocusNode.requestFocus();
    setState(() => _isDirty = true);
  }

  Future<void> _save() async {
    if (!_canSaveInPlace || !_isDirty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      // 只写入编辑器中的完整源文本，确保外部文档的 YAML front matter、换行和注释不被应用格式化。
      await _fileService.saveMarkdownFile(
        path: widget.file.path,
        content: _contentController.text,
      );
      if (!mounted) return;
      setState(() {
        _isDirty = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.externalMarkdownSaved)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(context.l10n.externalMarkdownSaveFailed(error.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _requestClose() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.discardUnsavedChangesTitle),
        content: Text(context.l10n.discardExternalMarkdownMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.continueEditing),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(context.l10n.discardChanges),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }
}

class _ExternalTool {
  const _ExternalTool(this.icon, this.tooltip, this.insertion);

  final IconData icon;
  final String tooltip;
  final String insertion;
}
