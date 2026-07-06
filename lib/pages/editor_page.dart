import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import '../models/models.dart';
import '../providers/notes_provider.dart';
import '../providers/git_provider.dart';
import '../providers/search_provider.dart';
import '../services/note_window_service.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';
import '../utils/common_utils.dart';

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
  bool _isPreview = false;

  // 缓存默认标题文案：dispose 阶段无法访问 context，需在此提前保存供空笔记判定使用。
  String? _untitledTitle;

  // 缓存笔记数据：dispose 阶段无法使用 ref.read，需在此提前保存。
  Note? _cachedNote;

  // 当前笔记是否已拖出为独立窗口（仅 Windows 桌面会为 true）。
  // build 时从 provider 刷新；dispose/_saveNote 等无法安全 watch 的地方读此缓存。
  bool _isDetached = false;

  Note? get _note => _cachedNote;

  double _pageHorizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppBreakpoints.desktop) return AppSpacing.xxl;
    if (width >= AppBreakpoints.tablet) return AppSpacing.xl;
    return AppSpacing.lg;
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
      if (note != null) {
        // 新建笔记时直接进入编辑模式，否则进入预览模式（txt 和 markdown 都一样）
        _isPreview = !widget.isNewNote;
      }
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
    if (!_discardIfEmpty()) {
      _saveNote();
    }
    widget.onBack?.call();
  }

  @override
  Widget build(BuildContext context) {
    final wordCount =
        _contentController.text.replaceAll(RegExp(r'\s'), '').length;
    final isDesktop = getScreenType(context) == ScreenType.desktop;

    // 独立窗口并发保护（仅 Windows 桌面）：笔记拖出期间本编辑器只读，
    // 独立窗口的编辑经主窗口 provider 回流后实时镜像到这里。
    _isDetached = widget.noteId != null &&
        ref.watch(externallyOpenNotesProvider).contains(widget.noteId);
    ref.listen<NotesState>(notesProvider, (prev, next) {
      if (!_isDetached || widget.noteId == null) return;
      final note = next.notes
          .cast<Note?>()
          .firstWhere((n) => n?.id == widget.noteId, orElse: () => null);
      if (note == null) return;
      if (_titleController.text == note.title &&
          _contentController.text == note.content) {
        return;
      }
      setState(() {
        _cachedNote = note;
        _titleController.text = note.title;
        _contentController.text = note.content;
      });
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
      child: Column(
        children: [
          _buildNavbar(context, isDesktop),
          if (_isDetached) _buildDetachedBanner(context),
          _buildTitleInput(context, isDesktop),
          _buildTagsRow(),
          Expanded(child: _isPreview ? _buildPreview() : _buildEditor()),
          _buildFooter(wordCount),
        ],
      ),
    );
  }

  /// 只读提示横幅：笔记正在独立窗口中编辑。
  Widget _buildDetachedBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      color: AppColors.warning.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.open_in_new, size: 14, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.l10n.noteDetachedBanner,
              style: const TextStyle(
                  fontSize: AppFontSize.sm, color: AppColors.warning),
            ),
          ),
          TextButton(
            onPressed: () => ref
                .read(noteWindowServiceProvider)
                .focusNoteWindow(widget.noteId!),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            child: Text(context.l10n.focusNoteWindow,
                style: const TextStyle(fontSize: AppFontSize.sm)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavbar(BuildContext context, bool isDesktop) {
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
              _note?.title ?? context.l10n.newNote,
              style: const TextStyle(
                  fontSize: AppFontSize.base, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _isPreview = !_isPreview),
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
              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.55),
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
        ],
      ),
    );
  }

  Widget _buildTitleInput(BuildContext context, bool isDesktop) {
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
                        if (isMarkdown) _buildToolbar(),
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

    const h1Style = TextStyle(
      fontSize: AppFontSize.title,
      fontWeight: FontWeight.w600,
      height: 1.28,
      color: AppColors.textPrimary,
      fontFamily: 'serif',
    );
    const h2Style = TextStyle(
      fontSize: AppFontSize.xxl,
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: AppColors.textPrimary,
      fontFamily: 'serif',
    );
    const h3Style = TextStyle(
      fontSize: AppFontSize.xl,
      fontWeight: FontWeight.w600,
      height: 1.45,
      color: AppColors.textPrimary,
    );
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
                        ? Markdown(
                            data: _contentController.text,
                            selectable: true,
                            padding: EdgeInsets.zero,
                            builders: {
                              'h1': _HeadingBackgroundBuilder(
                                textStyle: h1Style,
                                backgroundColor: AppColors.primaryLight
                                    .withValues(alpha: 0.72),
                                accentWidth: 4,
                              ),
                              'h2': _HeadingBackgroundBuilder(
                                textStyle: h2Style,
                                backgroundColor: AppColors.primaryLight
                                    .withValues(alpha: 0.48),
                                accentWidth: 3,
                              ),
                              'h3': _HeadingBackgroundBuilder(
                                textStyle: h3Style,
                                backgroundColor: AppColors.primaryLight
                                    .withValues(alpha: 0.28),
                                accentWidth: 3,
                              ),
                            },
                            styleSheet: MarkdownStyleSheet(
                              h1: h1Style,
                              h1Padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              h2: h2Style,
                              h2Padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                                bottom: AppSpacing.sm,
                              ),
                              h3: h3Style,
                              h3Padding:
                                  const EdgeInsets.only(top: AppSpacing.xs),
                              p: bodyStyle,
                              pPadding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              blockSpacing: AppSpacing.lg,
                              listIndent: AppSpacing.xl,
                              listBullet: const TextStyle(
                                fontSize: AppFontSize.base,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              listBulletPadding: const EdgeInsets.only(
                                right: AppSpacing.sm,
                              ),
                              code: const TextStyle(
                                fontSize: AppFontSize.sm,
                                backgroundColor: AppColors.primaryLight,
                                color: AppColors.primaryDark,
                                fontFamily: 'monospace',
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: AppColors.primaryLight
                                    .withValues(alpha: 0.5),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: AppColors.borderColor,
                                  width: 1,
                                ),
                              ),
                              codeblockPadding:
                                  const EdgeInsets.all(AppSpacing.lg),
                              blockquote: bodyStyle.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                              blockquotePadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.md,
                              ),
                              blockquoteDecoration: BoxDecoration(
                                border: const Border(
                                  left: BorderSide(
                                    color: AppColors.primary,
                                    width: 3,
                                  ),
                                ),
                                color: AppColors.primaryLight
                                    .withValues(alpha: 0.28),
                              ),
                              tableHead: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              tableBody: bodyStyle,
                              tableBorder: TableBorder.all(
                                color: AppColors.borderColor,
                                width: 0.7,
                              ),
                              tableCellsPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
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
                          )
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
      _isPreview = true;
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

/// 预览模式标题渲染：整行浅色背景 + 左侧主色竖条。
/// MarkdownStyleSheet 的 TextStyle.backgroundColor 只覆盖文字部分，
/// 无法实现整行背景，因此通过自定义 builder 接管 h1/h2/h3 的渲染。
/// 注意：标题内的行内格式（加粗、代码等）会按纯文本渲染。
class _HeadingBackgroundBuilder extends MarkdownElementBuilder {
  final TextStyle textStyle;
  final Color backgroundColor;
  final double accentWidth;

  _HeadingBackgroundBuilder({
    required this.textStyle,
    required this.backgroundColor,
    this.accentWidth = 4,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          left: BorderSide(color: AppColors.primary, width: accentWidth),
        ),
      ),
      child: Text(element.textContent, style: preferredStyle ?? textStyle),
    );
  }
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
