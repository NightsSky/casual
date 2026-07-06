import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sync/sync_engine.dart';
import '../models/models.dart';
import '../providers/notes_provider.dart';
import '../providers/git_provider.dart';
import '../providers/search_provider.dart';
import '../services/note_window_service.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';
import '../ui/widgets/conflict_resolution_dialog.dart';
import '../utils/common_utils.dart';
import '../utils/markdown_utils.dart';

class NotesPage extends ConsumerStatefulWidget {
  final void Function(String noteId)? onOpenNote;

  /// 顶栏"新建笔记"入口的回调，为 null 时不显示按钮。
  /// 桌面布局由路由层传入；移动布局不传，使用悬浮按钮（见 main.dart _MobileNotesWithFab）。
  final void Function(NoteFormat format)? onCreateNote;

  const NotesPage({super.key, this.onOpenNote, this.onCreateNote});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(notesProvider);
    final gitState = ref.watch(gitProvider);
    final isDesktop = getScreenType(context) == ScreenType.desktop;

    return Column(
      children: [
        _buildHeader(context, gitState, isDesktop),
        if (gitState.syncError != null)
          _buildSyncBar(gitState.syncError!, isError: true)
        else if (gitState.config.lastSyncTime != null)
          _buildSyncBar(_syncStatusText(context, gitState)),
        _buildTagsBar(notesState),
        Expanded(
          child: notesState.sortedNotes.isEmpty
              ? _buildEmptyState(context)
              : _buildNoteList(context, notesState),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, GitState gitState, bool isDesktop) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        isDesktop
            ? AppSpacing.md
            : MediaQuery.of(context).padding.top + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.appTitle,
              style: const TextStyle(
                fontSize: AppFontSize.xxl,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          if (widget.onCreateNote != null) ...[
            _CreatePopup(onCreate: widget.onCreateNote!),
            const SizedBox(width: AppSpacing.sm),
          ],
          _ActionIcon(
            icon: gitState.isSyncing ? Icons.hourglass_empty : Icons.sync,
            onTap: () => _handleSync(),
          ),
          const SizedBox(width: AppSpacing.sm),
          _SortPopup(
            currentSort: ref.read(notesProvider).sortBy,
            onChanged: (sortBy) =>
                ref.read(notesProvider.notifier).setSortBy(sortBy),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncBar(String text, {bool isError = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      color: isError
          ? AppColors.error.withValues(alpha: 0.1)
          : AppColors.success.withValues(alpha: 0.1),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppFontSize.sm,
          color: isError ? AppColors.error : AppColors.success,
        ),
      ),
    );
  }

  Widget _buildTagsBar(NotesState state) {
    if (state.allTags.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: const Border(
            bottom: BorderSide(color: AppColors.borderColor, width: 0.5)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        children: [
          _TagChip(
            label: context.l10n.all,
            isActive: state.filterTag == null,
            onTap: () => ref.read(notesProvider.notifier).setFilterTag(null),
          ),
          ...state.allTags.map((tag) => _TagChip(
                label: tag,
                isActive: state.filterTag == tag,
                onTap: () => ref.read(notesProvider.notifier).setFilterTag(tag),
              )),
        ],
      ),
    );
  }

  Widget _buildNoteList(BuildContext context, NotesState state) {
    final detachedIds = ref.watch(externallyOpenNotesProvider);
    // 整个列表区域作为 DragTarget：在列表内松手视为取消拖拽，
    // 拖出列表（右侧编辑栏或应用窗口之外）松手才弹出独立窗口。
    return DragTarget<Note>(
      onWillAcceptWithDetails: (_) => true,
      builder: (context, _, __) => ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: state.sortedNotes.length,
        itemBuilder: (context, index) {
          final note = state.sortedNotes[index];
          return _buildDraggableCard(
              context, note, detachedIds.contains(note.id));
        },
      ),
    );
  }

  /// 仅 Windows 桌面的 txt/Markdown 笔记支持拖出为独立窗口
  /// （NoteWindowService.canDetach），其余平台直接返回原卡片，行为不变。
  Widget _buildDraggableCard(BuildContext context, Note note, bool isDetached) {
    final card = _NoteCard(
      note: note,
      isDetached: isDetached,
      onTap: () => widget.onOpenNote?.call(note.id),
      onLongPress: () => _showNoteActions(context, note),
      onSecondaryTapUp: NoteWindowService.canDetach(note)
          ? (details) =>
              _showNoteContextMenu(context, note, details.globalPosition)
          : null,
    );

    if (!NoteWindowService.canDetach(note)) return card;

    return Draggable<Note>(
      data: note,
      maxSimultaneousDrags: 1,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _NoteDragFeedback(note: note),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      onDragEnd: (details) {
        // 被列表 DragTarget 接住 = 在列表内松手，视为取消。
        if (!details.wasAccepted) {
          ref.read(noteWindowServiceProvider).openNoteWindow(note);
        }
      },
      child: card,
    );
  }

  /// 桌面右键菜单：拖拽之外更易发现的"在新窗口打开"入口。
  Future<void> _showNoteContextMenu(
      BuildContext context, Note note, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'openInWindow',
          child: Row(
            children: [
              const Icon(Icons.open_in_new,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text(context.l10n.openInNewWindow),
            ],
          ),
        ),
      ],
    );
    if (value == 'openInWindow') {
      ref.read(noteWindowServiceProvider).openNoteWindow(note);
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📝',
              style: TextStyle(fontSize: 48, color: Colors.grey.shade400)),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.l10n.noNotesYet,
            style: TextStyle(
                fontSize: AppFontSize.lg, color: Colors.grey.shade500),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.createFirstNote,
            style: TextStyle(
                fontSize: AppFontSize.sm, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  void _showNoteActions(BuildContext context, Note note) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionSheetItem(ctx, context.l10n.edit, () {
                Navigator.pop(ctx);
                widget.onOpenNote?.call(note.id);
              }),
              _buildActionSheetItem(ctx, context.l10n.pin, () {
                Navigator.pop(ctx);
              }),
              _buildActionSheetItem(ctx, context.l10n.delete, () {
                Navigator.pop(ctx);
                _confirmDelete(context, note);
              }, isDanger: true),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.bgSecondary,
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide.none,
                  ),
                  child: Text(context.l10n.cancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionSheetItem(
      BuildContext ctx, String text, VoidCallback onTap,
      {bool isDanger = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md, horizontal: AppSpacing.lg),
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppFontSize.base,
            color: isDanger ? AppColors.error : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Note note) {
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
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    ref.read(searchProvider.notifier).clearSearch();
    try {
      // v2 同步：删除只删本地，base 表保留作为墓碑，下次同步由引擎按规则 5/8
      // 传播到远端（本地删+远端改时会保守恢复，不静默丢另一端修改）。
      notesNotifier.deleteNote(id);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.deleteFailedMessage(e.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleSync() async {
    final gitNotifier = ref.read(gitProvider.notifier);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    if (!ref.read(gitProvider).config.isConfigured) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.configureGitPlatformInSettings)),
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

      final report = await gitNotifier.runSync();

      if (!mounted) return;
      // 同步进度弹窗挂在根导航器上，关闭时也必须使用根导航器，避免在 /notes 根页误弹空 go_router 分支页面栈。
      if (rootNavigator.canPop()) {
        rootNavigator.pop();
      }

      // 冲突裁决（§7.2）：逐篇弹窗二选一，批量落地后再触发一次同步推送。
      if (report.pendingConflicts.isNotEmpty) {
        final resolutions = await _handleConflicts(context, report.pendingConflicts);
        if (resolutions != null && resolutions.isNotEmpty) {
          await gitNotifier.resolveConflicts(resolutions);
          // 用户选了「保留本地」的篇目需推送覆盖远端，再同步一次。
          if (!mounted) return;
          await gitNotifier.runSync();
        }
      }

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text(l10n.syncSuccess),
            backgroundColor: report.failures.isEmpty
                ? AppColors.success
                : AppColors.warning),
      );
    } catch (e) {
      if (!mounted) return;
      // 同步失败同样只关闭进度弹窗，保留当前笔记列表页面，避免异常提示前路由栈被清空。
      if (rootNavigator.canPop()) {
        rootNavigator.pop();
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.syncFailedMessage(e.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// 逐篇弹冲突对话框收集裁决（doc/sync-design.md §7.2）。
  /// 用户可中途取消，返回已收集的部分裁决（引擎落地部分即可）。
  Future<List<ConflictResolution>?> _handleConflicts(
    BuildContext context,
    List<SyncConflict> conflicts,
  ) async {
    final resolutions = <ConflictResolution>[];
    for (var i = 0; i < conflicts.length; i++) {
      final conflict = conflicts[i];
      if (!mounted) return null;
      final choice = await showDialog<ConflictChoice>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ConflictResolutionDialog(
          conflict: conflict,
          currentIndex: i,
          totalCount: conflicts.length,
        ),
      );
      if (choice == null) {
        // 用户点了取消或按了返回键，中止后续冲突弹窗，返回已收集的部分。
        break;
      }
      resolutions.add(ConflictResolution(conflict: conflict, choice: choice));
    }
    return resolutions.isEmpty ? null : resolutions;
  }

  String _syncStatusText(BuildContext context, GitState gitState) {
    if (gitState.isSyncing) return context.l10n.syncInProgress;
    if (gitState.syncError != null) {
      return context.l10n.syncFailedMessage(gitState.syncError!);
    }
    if (gitState.config.lastSyncTime != null) {
      return context.l10n.lastSyncedAt(
        formatDate(
          gitState.config.lastSyncTime,
          locale: Localizations.localeOf(context).languageCode,
        ),
      );
    }
    return context.l10n.neverSynced;
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TagChip(
      {required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Material(
        color: isActive
            ? AppColors.primary
            : AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.round),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.round),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppFontSize.xs,
                color: isActive ? Colors.white : AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _SortPopup extends StatelessWidget {
  final String currentSort;
  final void Function(String) onChanged;

  const _SortPopup({required this.currentSort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [
      _SortOption('updatedAt', context.l10n.sortByUpdated),
      _SortOption('createdAt', context.l10n.sortByCreated),
      _SortOption('title', context.l10n.sortByTitle),
    ];

    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort, size: 20, color: AppColors.textSecondary),
      onSelected: onChanged,
      itemBuilder: (context) => options.map((opt) {
        return PopupMenuItem<String>(
          value: opt.value,
          child: Row(
            children: [
              Expanded(child: Text(opt.label)),
              if (currentSort == opt.value)
                const Icon(Icons.check, size: 16, color: AppColors.primary),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SortOption {
  final String value;
  final String label;
  const _SortOption(this.value, this.label);
}

/// 顶栏"新建笔记"按钮：点击弹出 TXT / Markdown 格式选择菜单。
class _CreatePopup extends StatelessWidget {
  final void Function(NoteFormat) onCreate;

  const _CreatePopup({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<NoteFormat>(
      icon: const Icon(Icons.add, size: 22, color: AppColors.primary),
      tooltip: context.l10n.newNote,
      onSelected: onCreate,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: NoteFormat.txt,
          child: Row(
            children: [
              Icon(Icons.description_outlined,
                  size: 16, color: AppColors.textSecondary),
              SizedBox(width: AppSpacing.sm),
              Text('TXT'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: NoteFormat.markdown,
          child: Row(
            children: [
              Icon(Icons.code, size: 16, color: AppColors.textSecondary),
              SizedBox(width: AppSpacing.sm),
              Text('Markdown'),
            ],
          ),
        ),
      ],
    );
  }
}

/// 拖出笔记时跟随指针的缩影卡片。
class _NoteDragFeedback extends StatelessWidget {
  final Note note;

  const _NoteDragFeedback({required this.note});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(AppRadius.md),
      color: AppColors.bgPrimary,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.description_outlined,
                size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                note.title.isEmpty ? context.l10n.untitledNote : note.title,
                style: const TextStyle(
                    fontSize: AppFontSize.base, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.open_in_new,
                size: 16, color: AppColors.textPlaceholder),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final void Function(TapUpDetails)? onSecondaryTapUp;

  /// 该笔记当前已拖出为独立窗口（仅 Windows 桌面），标题旁显示角标。
  final bool isDetached;

  const _NoteCard({
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.onSecondaryTapUp,
    this.isDetached = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTapUp: onSecondaryTapUp,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      style: const TextStyle(
                          fontSize: AppFontSize.lg,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isDetached)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: Tooltip(
                        message: context.l10n.noteDetachedTooltip,
                        child: const Icon(Icons.open_in_new,
                            size: 14, color: AppColors.primary),
                      ),
                    ),
                  if (note.syncStatus == SyncStatus.local)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(context.l10n.localStatus,
                          style: const TextStyle(
                              fontSize: AppFontSize.xs,
                              color: AppColors.warning)),
                    )
                  else if (note.syncStatus == SyncStatus.conflict)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(context.l10n.conflictStatus,
                          style: const TextStyle(
                              fontSize: AppFontSize.xs,
                              color: AppColors.error)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                note.content.isNotEmpty
                    ? stripMarkdown(note.content)
                    : context.l10n.noContent,
                style: const TextStyle(
                    fontSize: AppFontSize.sm,
                    color: AppColors.textSecondary,
                    height: 1.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (note.tags.isNotEmpty)
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        children: note.tags
                            .take(3)
                            .map((tag) => Text(
                                  '#$tag',
                                  style: const TextStyle(
                                      fontSize: AppFontSize.xs,
                                      color: AppColors.primary),
                                ))
                            .toList(),
                      ),
                    ),
                  Text(
                    formatTime(note.updatedAt,
                        locale: Localizations.localeOf(context).languageCode),
                    style: const TextStyle(
                        fontSize: AppFontSize.xs,
                        color: AppColors.textPlaceholder),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
