import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/markdown_editor_focus_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/git_provider.dart';
import '../providers/search_provider.dart';
import '../services/note_window_service.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';
import '../utils/common_utils.dart';
import '../widgets/markdown_preview.dart';

enum _MarkdownViewMode { edit, split, preview }

class EditorPage extends ConsumerStatefulWidget {
  final String? noteId;
  final VoidCallback? onBack;
  final bool isNewNote;

  const EditorPage(
      {super.key, this.noteId, this.onBack, this.isNewNote = false});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  static const double _titleMaxWidth = 960;
  static const double _editorMaxWidth = 980;
  static const double _previewMaxWidth = 900;

  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late FocusNode _contentFocusNode;
  _MarkdownViewMode _markdownViewMode = _MarkdownViewMode.preview;

  // Windows 默认收起格式工具栏，给源码与实时预览留出更多垂直空间；
  // 仍可通过顶部工具按钮按需展开。
  bool _showMarkdownToolbar = !Platform.isWindows;

  // 缓存默认标题文案：dispose 阶段无法访问 context，需在此提前保存供空笔记判定使用。
  String? _untitledTitle;

  // 缓存笔记数据：dispose 阶段无法使用 ref.read，需在此提前保存。
  Note? _cachedNote;

  // 当前笔记是否已拖出为独立窗口（仅 Windows 桌面会为 true）。
  // build 时从 provider 刷新；dispose/_saveNote 等无法安全 watch 的地方读此缓存。
  bool _isDetached = false;

  Note? get _note => _cachedNote;

  bool get _isPreview => _markdownViewMode == _MarkdownViewMode.preview;

  bool get _isSplitPreview =>
      _markdownViewMode == _MarkdownViewMode.split &&
      _note?.format == NoteFormat.markdown;

  double _pageHorizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppBreakpoints.desktop) return AppSpacing.xxl;
    if (width >= AppBreakpoints.tablet) return AppSpacing.xl;
    return AppSpacing.lg;
  }

  /// Windows 在 1024px 起按桌面工作区处理，满足可缩放窗口中的最小桌面体验；
  /// 其他平台仍使用应用既有断点，避免小屏触控布局被桌面控件挤压。
  bool _isDesktopWorkspace(BuildContext context) {
    return getScreenType(context) == ScreenType.desktop ||
        (Platform.isWindows && MediaQuery.sizeOf(context).width >= 1024);
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _contentFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.noteId != null) {
        ref.read(notesProvider.notifier).setCurrentNote(widget.noteId!);
      }
      _updateCachedNote();
      _loadNote();

      final note = _note;
      if (note == null || !mounted) return;
      setState(() {
        // Windows 宽屏默认同时展示 Markdown 源码和渲染结果；
        // 其他格式及窄屏仍沿用新建编辑、已有笔记预览的熟悉行为。
        _markdownViewMode =
            note.format == NoteFormat.markdown && _isDesktopWorkspace(context)
                ? _MarkdownViewMode.split
                : (widget.isNewNote
                    ? _MarkdownViewMode.edit
                    : _MarkdownViewMode.preview);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _untitledTitle = context.l10n.untitledNote;
  }

  void _updateCachedNote() {
    _cachedNote = ref.read(notesProvider).currentNote;
  }

  void _loadNote() {
    final note = _note;
    if (note != null) {
      _titleController.text = note.title;
      _contentController.text = note.content;
    }
  }

  @override
  void dispose() {
    // 兜底：任意方式离开编辑页（返回、桌面端切换笔记导致 State 重建、路由销毁）
    // 都在此清理未编辑过的空笔记，与 _handleBack 形成双保险。
    // dispose 处于销毁阶段，直接改 provider 会触发同屏 NotesPage 在此期间重建而报错，
    // 因此捕获 notifier 与 id 后用微任务延迟到当前帧之后执行删除。
    if (_shouldDiscard()) {
      final notifier = ref.read(notesProvider.notifier);
      final id = _note!.id;
      Future.microtask(() => notifier.deleteNote(id));
    }
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _saveNote() {
    // 笔记正被独立窗口编辑时本编辑器只读，不回写，
    // 防止旧的 controller 内容覆盖独立窗口刚写入的新内容。
    if (_isDetached) return;
    _updateCachedNote();
    final note = _note;
    if (note == null) return;

    final updated = ref.read(notesProvider.notifier).updateNote(
          note.id,
          title: _titleController.text,
          content: _contentController.text,
        );
    if (updated != null) {
      _cachedNote = updated;
      ref.read(searchProvider.notifier).search(ref.read(searchProvider).query);
    }
  }

  /// 判断当前是否是一条从未真正输入过内容的空笔记：正文为空，
  /// 且标题为空或仍是新建时的默认标题。不依赖 context，可在 dispose 中调用。
  bool _isEmptyNote() {
    if (_contentController.text.trim().isNotEmpty) return false;
    final title = _titleController.text.trim();
    return title.isEmpty || title == _untitledTitle;
  }

  /// 纯读判定：当前是否是"新建后从未真正输入内容、且从未同步过"的空笔记。
  /// 不修改任何状态，可安全用于 dispose 阶段。
  bool _shouldDiscard() {
    // 拖出到独立窗口的笔记内容以子窗口为准，本编辑器的 controller
    // 可能是旧快照，不能据此判定为空笔记而误删。
    if (_isDetached) return false;
    final note = _note;
    if (note == null) return false;
    final neverSynced = note.filePath == null || note.filePath!.isEmpty;
    return neverSynced && _isEmptyNote();
  }

  /// 若当前是空笔记则删除并返回 true（同步执行，供事件回调路径使用）。
  bool _discardIfEmpty() {
    if (!_shouldDiscard()) return false;
    ref.read(notesProvider.notifier).deleteNote(_note!.id);
    return true;
  }

  /// 返回时若是空笔记则丢弃，否则保存。
  void _handleBack() {
    // 从专注视图返回笔记列表前先恢复主界面导航，避免下次打开列表仍被隐藏。
    ref.read(markdownEditorFocusProvider.notifier).state = false;
    if (!_discardIfEmpty()) {
      _saveNote();
    }
    widget.onBack?.call();
  }

  @override
  Widget build(BuildContext context) {
    final wordCount =
        _contentController.text.replaceAll(RegExp(r'\s'), '').length;
    final isDesktop = _isDesktopWorkspace(context);
    final isFocusMode = ref.watch(markdownEditorFocusProvider);

    // 独立窗口并发保护（仅 Windows 桌面）：笔记拖出期间主窗口不再渲染标题输入区、
    // 标签、正文编辑器或预览，只保留只读占位和聚焦入口，避免双端同时操作同一笔记。
    _isDetached = widget.noteId != null &&
        ref.watch(externallyOpenNotesProvider).contains(widget.noteId);
    ref.listen<NotesState>(notesProvider, (prev, next) {
      if (!_isDetached || widget.noteId == null) return;
      final note = next.notes
          .cast<Note?>()
          .firstWhere((n) => n?.id == widget.noteId, orElse: () => null);
      if (note == null) return;
      _cachedNote = note;
    });
    ref.listen<Set<String>>(externallyOpenNotesProvider, (prev, next) {
      final id = widget.noteId;
      if (id == null) return;
      final wasDetached = prev?.contains(id) ?? false;
      if (wasDetached && !next.contains(id)) {
        // 独立窗口已关闭：把其写入的最新内容刷回本编辑器并解除只读。
        setState(() {
          _updateCachedNote();
          _loadNote();
        });
      }
    });

    // 拦截系统返回（物理返回键/侧滑手势），统一走 _handleBack，
    // 保证空笔记在任意返回方式下都会被清理。
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: isFocusMode
          ? _buildFocusWorkspace(context, isDesktop)
          : Column(
              children: [
                _buildNavbar(context, isDesktop, isDetached: _isDetached),
                if (_isDetached)
                  Expanded(child: _buildDetachedNotice(context))
                else ...[
                  _buildTitleInput(context, isDesktop),
                  _buildTagsRow(),
                  Expanded(child: _buildDocumentWorkspace()),
                  _buildFooter(wordCount),
                ],
              ],
            ),
    );
  }

  /// 专注视图只保留文档工作区和一组悬浮控制，配合路由层隐藏侧栏、笔记列表，
  /// 让编辑或预览真正占满应用内容区，而不混同于操作系统窗口最大化。
  Widget _buildFocusWorkspace(BuildContext context, bool isDesktop) {
    return Stack(
      children: [
        Positioned.fill(
          child: _isDetached
              ? _buildDetachedNotice(context)
              : _buildDocumentWorkspace(),
        ),
        if (!_isDetached)
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
                      if (_note?.format == NoteFormat.markdown)
                        _buildMarkdownModeButton(isDesktop),
                      if (_note?.format == NoteFormat.markdown && isDesktop)
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
                            onPressed: () => setState(() =>
                                _showMarkdownToolbar = !_showMarkdownToolbar),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      Tooltip(
                        message: context.l10n.exitMarkdownFocus,
                        child: IconButton(
                          icon: const Icon(Icons.fullscreen_exit, size: 19),
                          onPressed: () => ref
                              .read(markdownEditorFocusProvider.notifier)
                              .state = false,
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

  Widget _buildDocumentWorkspace() {
    if (_isSplitPreview) return _buildSplitEditor();
    return _isPreview ? _buildPreview() : _buildEditor();
  }

  /// 独立窗口只读占位：主窗口不展示任何可编辑或可预览的笔记内容，
  /// 只提供当前笔记已移交独立窗口的状态提示和聚焦入口。
  Widget _buildDetachedNotice(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.bgSecondary,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _pageHorizontalPadding(context),
            vertical: AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.open_in_new,
                size: 40,
                color: AppColors.warning.withValues(alpha: 0.88),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.l10n.noteDetachedBanner,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppFontSize.base,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => ref
                    .read(noteWindowServiceProvider)
                    .focusNoteWindow(widget.noteId!),
                icon: const Icon(Icons.filter_center_focus, size: 18),
                label: Text(context.l10n.focusNoteWindow),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavbar(BuildContext context, bool isDesktop,
      {bool isDetached = false}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        isDesktop
            ? AppSpacing.sm
            : MediaQuery.of(context).padding.top + AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgTertiary,
        border: Border(
            bottom: BorderSide(color: AppColors.borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Tooltip(
            message: MaterialLocalizations.of(context).backButtonTooltip,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: _handleBack,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                minimumSize: const Size(36, 36),
              ),
            ),
          ),
          Expanded(
            child: Text(
              // txt 无独立标题（派生自首行），空内容时派生为空串，
              // 与"未选中笔记"一并回退到「无标题」文案，避免导航栏留白。
              (_note?.title.isNotEmpty ?? false)
                  ? _note!.title
                  : context.l10n.untitledNote,
              style: const TextStyle(
                  fontSize: AppFontSize.base, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isDetached) ...[
            if (_note?.format == NoteFormat.markdown)
              _buildMarkdownModeButton(isDesktop)
            else
              TextButton.icon(
                onPressed: () => setState(() => _markdownViewMode = _isPreview
                    ? _MarkdownViewMode.edit
                    : _MarkdownViewMode.preview),
                icon: Icon(
                  _isPreview ? Icons.edit_outlined : Icons.visibility_outlined,
                  size: 18,
                ),
                label: Text(
                  _isPreview ? context.l10n.edit : context.l10n.preview,
                  style: const TextStyle(fontSize: AppFontSize.sm),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor:
                      AppColors.primaryLight.withValues(alpha: 0.55),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            if (_note?.format == NoteFormat.markdown && isDesktop)
              Tooltip(
                message: _showMarkdownToolbar
                    ? context.l10n.hideMarkdownToolbar
                    : context.l10n.showMarkdownToolbar,
                child: IconButton(
                  onPressed: () => setState(
                      () => _showMarkdownToolbar = !_showMarkdownToolbar),
                  icon: Icon(
                    _showMarkdownToolbar
                        ? Icons.keyboard_hide_outlined
                        : Icons.format_align_left,
                    size: 19,
                  ),
                  visualDensity: VisualDensity.compact,
                  color: AppColors.textSecondary,
                ),
              ),
            Tooltip(
              message: context.l10n.enterMarkdownFocus,
              child: IconButton(
                onPressed: () =>
                    ref.read(markdownEditorFocusProvider.notifier).state = true,
                icon: const Icon(Icons.fullscreen, size: 20),
                visualDensity: VisualDensity.compact,
                color: AppColors.textSecondary,
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_horiz,
                size: 20,
                color: AppColors.textSecondary,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                    value: 'sync', child: Text(context.l10n.syncToRemote)),
                PopupMenuItem(
                    value: 'tags', child: Text(context.l10n.manageTags)),
                PopupMenuItem(
                    value: 'export', child: Text(context.l10n.exportMarkdown)),
                if (_note?.format == NoteFormat.markdown)
                  const PopupMenuItem(
                      value: 'convertToTxt', child: Text('转换为 TXT')),
                if (_note?.format == NoteFormat.txt)
                  const PopupMenuItem(
                      value: 'convertToMarkdown', child: Text('转换为 Markdown')),
                PopupMenuItem(
                    value: 'delete',
                    child: Text(context.l10n.deleteNote,
                        style: const TextStyle(color: AppColors.error))),
              ],
              onSelected: (value) => _handleMenuAction(value),
            ),
          ] else
            const SizedBox(width: 36),
        ],
      ),
    );
  }

  /// 单个按钮用高亮图标表示当前 Markdown 视图，点击后循环到下一种可用视图。
  Widget _buildMarkdownModeButton(bool allowSplit) {
    final tooltip = switch (_markdownViewMode) {
      _MarkdownViewMode.edit => context.l10n.markdownEditOnly,
      _MarkdownViewMode.split => context.l10n.markdownSplitView,
      _MarkdownViewMode.preview => context.l10n.markdownPreviewOnly,
    };
    final icon = switch (_markdownViewMode) {
      _MarkdownViewMode.edit => Icons.edit_outlined,
      _MarkdownViewMode.split => Icons.vertical_split,
      _MarkdownViewMode.preview => Icons.visibility_outlined,
    };

    return Tooltip(
      message: tooltip,
      child: IconButton(
        key: const ValueKey('markdownModeCycleButton'),
        icon: Icon(icon, size: 18),
        onPressed: () => _cycleMarkdownViewMode(allowSplit),
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.65),
          minimumSize: const Size(34, 34),
        ),
      ),
    );
  }

  /// 桌面宽屏按“编辑 → 分屏 → 预览”循环；窄屏跳过无法正常展示的分屏视图。
  void _cycleMarkdownViewMode(bool allowSplit) {
    final nextMode = switch (_markdownViewMode) {
      _MarkdownViewMode.edit when allowSplit => _MarkdownViewMode.split,
      _MarkdownViewMode.edit => _MarkdownViewMode.preview,
      _MarkdownViewMode.split => _MarkdownViewMode.preview,
      _MarkdownViewMode.preview => _MarkdownViewMode.edit,
    };
    _setMarkdownViewMode(nextMode);
  }

  void _setMarkdownViewMode(_MarkdownViewMode mode) {
    setState(() => _markdownViewMode = mode);
    if (mode != _MarkdownViewMode.preview) {
      _contentFocusNode.requestFocus();
    }
  }

  Widget _buildTitleInput(BuildContext context, bool isDesktop) {
    // txt 笔记无独立标题（标题从正文首行派生），不展示标题输入区；
    // 导航栏中央仍显示派生标题用于辨识。
    if (_note?.format == NoteFormat.txt) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.bgTertiary,
        border: Border(
            bottom: BorderSide(color: AppColors.borderColor, width: 0.5)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _titleMaxWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _pageHorizontalPadding(context),
              vertical: isDesktop ? AppSpacing.lg : AppSpacing.md,
            ),
            child: _isPreview
                ? Text(
                    _titleController.text.isEmpty
                        ? context.l10n.untitledNote
                        : _titleController.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppFontSize.title,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: AppColors.textPrimary,
                      fontFamily: 'serif',
                    ),
                  )
                : TextField(
                    controller: _titleController,
                    readOnly: _isDetached,
                    style: const TextStyle(
                      fontSize: AppFontSize.title,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: AppColors.textPrimary,
                      fontFamily: 'serif',
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
                    onChanged: (_) => _saveNote(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagsRow() {
    final note = _note;
    final tags = note?.tags ?? [];

    if (tags.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.bgTertiary,
        border: Border(
            bottom: BorderSide(color: AppColors.borderColor, width: 0.5)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _titleMaxWidth),
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: _pageHorizontalPadding(context),
                vertical: AppSpacing.sm,
              ),
              children: [
                ...tags.map((tag) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Chip(
                        label: Text('#$tag',
                            style: const TextStyle(fontSize: AppFontSize.xs)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => _removeTag(tag),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        backgroundColor:
                            AppColors.primaryLight.withValues(alpha: 0.72),
                        labelStyle: const TextStyle(
                            color: AppColors.primary,
                            fontSize: AppFontSize.xs,
                            fontWeight: FontWeight.w600),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                    )),
                ActionChip(
                  label: Text(context.l10n.addTagButton,
                      style: const TextStyle(
                          fontSize: AppFontSize.xs,
                          color: AppColors.textPlaceholder)),
                  onPressed: _showAddTagDialog,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    // 实时从 provider 读取当前笔记
    final note = ref.watch(notesProvider).currentNote;
    final isMarkdown = note?.format == NoteFormat.markdown;

    return Container(
      color: AppColors.bgSecondary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = _pageHorizontalPadding(context);
          final vertical = constraints.maxWidth < AppBreakpoints.mobile
              ? AppSpacing.md
              : AppSpacing.lg;
          final panelHeight = constraints.maxHeight > vertical * 2
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
                constraints: const BoxConstraints(maxWidth: _editorMaxWidth),
                child: SizedBox(
                  height: panelHeight,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
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
                    child: Column(
                      children: [
                        if (isMarkdown && _showMarkdownToolbar) _buildToolbar(),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xl,
                              AppSpacing.lg,
                              AppSpacing.xl,
                              AppSpacing.xl,
                            ),
                            child: TextField(
                              controller: _contentController,
                              focusNode: _contentFocusNode,
                              readOnly: _isDetached,
                              maxLines: null,
                              expands: true,
                              cursorColor: AppColors.primary,
                              style: const TextStyle(
                                fontSize: AppFontSize.base,
                                height: 1.78,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: InputDecoration(
                                hintText: context.l10n.startWriting,
                                hintStyle: const TextStyle(
                                  color: AppColors.textPlaceholder,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                filled: false,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (_) => _saveNote(),
                              textAlignVertical: TextAlignVertical.top,
                            ),
                          ),
                        ),
                      ],
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

  /// 分屏中的两个面板使用同一份 controller：左侧编辑源文件，右侧立即按同一文本渲染。
  /// 当主窗口未进入专注视图而可用宽度较窄时改为上下排列，仍能同时查看两种结果。
  Widget _buildSplitEditor() {
    return Container(
      color: AppColors.bgSecondary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = _pageHorizontalPadding(context);
          final vertical = constraints.maxWidth < AppBreakpoints.mobile
              ? AppSpacing.md
              : AppSpacing.lg;
          final isHorizontal = constraints.maxWidth >= 840;

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontal,
              vertical: vertical,
            ),
            child: SizedBox.expand(
              child: isHorizontal
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildSplitSourcePanel()),
                        const VerticalDivider(width: AppSpacing.lg),
                        Expanded(child: _buildSplitPreviewPanel()),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: _buildSplitSourcePanel()),
                        const Divider(height: AppSpacing.lg),
                        Expanded(child: _buildSplitPreviewPanel()),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSplitSourcePanel() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderColor, width: 0.8),
      ),
      child: Column(
        children: [
          if (_showMarkdownToolbar) _buildToolbar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                key: const ValueKey('markdownSplitSourceEditor'),
                controller: _contentController,
                focusNode: _contentFocusNode,
                readOnly: _isDetached,
                maxLines: null,
                expands: true,
                cursorColor: AppColors.primary,
                textAlignVertical: TextAlignVertical.top,
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
                onChanged: (_) {
                  _saveNote();
                  // 分屏路径不依赖 notesProvider 的 watch 重建，正文变更后主动刷新右侧渲染，
                  // 保证源码输入的每一次修改都会立即反映在 Markdown 预览中。
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitPreviewPanel() {
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

  Widget _buildToolbar() {
    const tools = [
      _Tool(Icons.title, '标题', '## '),
      _Tool(Icons.format_bold, '加粗', '**粗体**'),
      _Tool(Icons.format_italic, '斜体', '*斜体*'),
      _Tool(Icons.strikethrough_s, '删除线', '~~删除线~~'),
      _Tool(Icons.format_quote, '引用', '\n> '),
      _Tool(Icons.format_list_bulleted, '列表', '\n- '),
      _Tool(Icons.check_box_outlined, '任务', '\n- [ ] '),
      _Tool(Icons.code, '代码块', '\n```\n代码\n```\n'),
      _Tool(Icons.link, '链接', '[链接文字](url)'),
      _Tool(Icons.image_outlined, '图片', '![图片描述](url)'),
      _Tool(Icons.horizontal_rule, '分隔线', '\n---\n'),
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
              .map((tool) => _ToolbarButton(
                    icon: tool.icon,
                    tooltip: tool.tooltip,
                    onTap: () => _insertText(tool.insertion),
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _insertText(String text) {
    final controller = _contentController;
    final selection = controller.selection;
    final currentText = controller.text;
    final start = selection.isValid ? selection.start : currentText.length;
    final end = selection.isValid ? selection.end : currentText.length;

    // Markdown 工具条插入内容后立即复用编辑保存链路，避免只更新输入框而未持久化。
    controller.text = currentText.replaceRange(start, end, text);
    controller.selection = TextSelection.collapsed(offset: start + text.length);

    _contentFocusNode.requestFocus();
    _saveNote();
    setState(() {});
  }

  Widget _buildPreview() {
    final note = ref.watch(notesProvider).currentNote;
    final isMarkdown = note?.format == NoteFormat.markdown;
    const bodyStyle = TextStyle(
      fontSize: AppFontSize.base,
      height: 1.85,
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w400,
    );

    // 预览模式统一使用受限宽度的阅读纸张，避免桌面端长行过宽影响阅读。
    return Container(
      color: AppColors.bgSecondary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = _pageHorizontalPadding(context);
          final vertical = constraints.maxWidth < AppBreakpoints.mobile
              ? AppSpacing.md
              : AppSpacing.xl;
          final surfacePadding = constraints.maxWidth < AppBreakpoints.mobile
              ? AppSpacing.lg
              : AppSpacing.xxl;
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
                constraints: const BoxConstraints(maxWidth: _previewMaxWidth),
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
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: isMarkdown
                        ? MarkdownPreview(data: _contentController.text)
                        : SingleChildScrollView(
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

  Widget _buildFooter(int wordCount) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgTertiary,
        border:
            Border(top: BorderSide(color: AppColors.borderColor, width: 0.5)),
      ),
      child: Text(
        context.l10n.wordCountFooter(
          wordCount,
          formatTime(_note?.updatedAt,
              locale: Localizations.localeOf(context).languageCode),
        ),
        style: const TextStyle(
            fontSize: AppFontSize.xs, color: AppColors.textPlaceholder),
      ),
    );
  }

  void _removeTag(String tag) {
    final note = _note;
    if (note == null) return;

    final tags = note.tags.where((t) => t != tag).toList();
    ref.read(notesProvider.notifier).updateNote(note.id, tags: tags);
  }

  void _showAddTagDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.addTag),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: context.l10n.enterTagName),
          onSubmitted: (value) {
            _addTag(value);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              _addTag(controller.text);
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.add),
          ),
        ],
      ),
    );
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;

    final note = _note;
    if (note == null) return;

    final tags = {...note.tags, trimmed}.toList();
    ref.read(notesProvider.notifier).updateNote(note.id, tags: tags);
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'sync':
        await _syncNote();
        break;
      case 'tags':
        _showAddTagDialog();
        break;
      case 'export':
        _exportNote();
        break;
      case 'convertToTxt':
        _convertFormat(NoteFormat.txt);
        break;
      case 'convertToMarkdown':
        _convertFormat(NoteFormat.markdown);
        break;
      case 'delete':
        _confirmDelete();
        break;
    }
  }

  Future<void> _syncNote() async {
    final note = _note;
    if (note == null) return;

    final gitNotifier = ref.read(gitProvider.notifier);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    if (!ref.read(gitProvider).config.isConfigured) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.configureGitFirst)),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      );

      _saveNote();
      // v2 同步无单条推送语义：整仓库一次原子会话，先落盘本地编辑再触发同步，
      // 引擎会把本笔记连同其他待同步变更一并处理（含冲突副本、删除传播）。
      final report = await gitNotifier.runSync();

      if (!mounted) return;
      // 单条笔记同步弹窗挂在根导航器上，关闭时只弹出进度弹窗，避免误关闭当前编辑页路由。
      if (rootNavigator.canPop()) {
        rootNavigator.pop();
      }

      messenger.showSnackBar(
        SnackBar(
            content: Text(report.summary()),
            backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      // 同步失败时仍保留编辑页，用户可以查看失败提示后继续修改或重试。
      if (rootNavigator.canPop()) {
        rootNavigator.pop();
      }
      messenger.showSnackBar(
        SnackBar(
            content: Text(l10n.syncFailedMessage(e.toString())),
            backgroundColor: AppColors.error),
      );
    }
  }

  void _exportNote() {
    if (_note == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.markdownReady)),
    );
  }

  void _convertFormat(NoteFormat newFormat) {
    final note = _note;
    if (note == null) return;

    ref.read(notesProvider.notifier).updateNote(
          note.id,
          format: newFormat,
        );

    // 格式转换后保持在预览模式
    setState(() {
      _markdownViewMode = _MarkdownViewMode.preview;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(newFormat == NoteFormat.txt
              ? '已转换为 TXT 格式'
              : '已转换为 Markdown 格式')),
    );
  }

  void _confirmDelete() {
    final note = _note;
    if (note == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.confirmDelete),
        content: Text(context.l10n.confirmDeleteNote(note.title)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.cancel)),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteNote(note.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNote(String id) async {
    final notesNotifier = ref.read(notesProvider.notifier);
    // v2 同步：删除只删本地，base 表保留作为墓碑，下次同步由引擎按规则 5/8
    // 传播到远端（本地删+远端改时会保守恢复，不静默丢另一端修改）。
    notesNotifier.deleteNote(id);
    if (!mounted) return;
    widget.onBack?.call();
  }
}

class _Tool {
  final IconData icon;
  final String tooltip;
  final String insertion;
  const _Tool(this.icon, this.tooltip, this.insertion);
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: 18),
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          backgroundColor: Colors.transparent,
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
}
