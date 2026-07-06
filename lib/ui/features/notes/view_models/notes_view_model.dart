import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/notes_repository.dart';
import '../../../../domain/models/models.dart';
import '../../../../utils/markdown_utils.dart';

class NotesState {
  final List<Note> notes;
  final String? currentNoteId;
  final String sortBy;
  final bool sortAsc;
  final String? filterTag;
  final String? filterCategory;
  final bool isLoading;

  const NotesState({
    this.notes = const [],
    this.currentNoteId,
    this.sortBy = 'updatedAt',
    this.sortAsc = false,
    this.filterTag,
    this.filterCategory,
    this.isLoading = false,
  });

  Note? get currentNote => notes
      .cast<Note?>()
      .firstWhere((n) => n?.id == currentNoteId, orElse: () => null);

  List<Note> get sortedNotes {
    var result = List<Note>.from(notes);

    if (filterTag != null) {
      result = result.where((n) => n.tags.contains(filterTag)).toList();
    }
    if (filterCategory != null) {
      result = result.where((n) => n.category == filterCategory).toList();
    }

    result.sort((a, b) {
      late int cmp;
      switch (sortBy) {
        case 'createdAt':
          cmp = a.createdAt.compareTo(b.createdAt);
          break;
        case 'title':
          cmp = a.title.compareTo(b.title);
          break;
        case 'updatedAt':
        default:
          cmp = a.updatedAt.compareTo(b.updatedAt);
          break;
      }
      return sortAsc ? cmp : -cmp;
    });

    return result;
  }

  List<String> get allTags {
    final tagSet = <String>{};
    for (final note in notes) {
      tagSet.addAll(note.tags);
    }
    return tagSet.toList()..sort();
  }

  List<String> get allCategories {
    final catSet = <String>{};
    for (final note in notes) {
      if (note.category.isNotEmpty) catSet.add(note.category);
    }
    return catSet.toList()..sort();
  }

  int get notesCount => notes.length;

  NotesState copyWith({
    List<Note>? notes,
    String? currentNoteId,
    bool clearCurrentNoteId = false,
    String? sortBy,
    bool? sortAsc,
    String? filterTag,
    bool clearFilterTag = false,
    String? filterCategory,
    bool clearFilterCategory = false,
    bool? isLoading,
  }) {
    return NotesState(
      notes: notes ?? this.notes,
      currentNoteId:
          clearCurrentNoteId ? null : currentNoteId ?? this.currentNoteId,
      sortBy: sortBy ?? this.sortBy,
      sortAsc: sortAsc ?? this.sortAsc,
      filterTag: clearFilterTag ? null : filterTag ?? this.filterTag,
      filterCategory:
          clearFilterCategory ? null : filterCategory ?? this.filterCategory,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotesNotifier extends StateNotifier<NotesState> {
  NotesNotifier(this._repository) : super(const NotesState());

  final NotesRepository _repository;

  Future<void> loadFromCache() async {
    state = state.copyWith(isLoading: true);
    final notes = await _repository.loadNotes();
    state = state.copyWith(notes: notes, isLoading: false);
  }

  Note createNote({
    String title = '无标题笔记',
    String content = '',
    List<String>? tags,
    String category = '未分类',
    NoteFormat format = NoteFormat.txt,
  }) {
    final note = Note(
      id: generateId(),
      title: title,
      content: content,
      tags: tags ?? [],
      category: category,
      format: format,
    );
    state = state.copyWith(
      notes: [note, ...state.notes],
      currentNoteId: note.id,
    );
    _saveToCache();
    return note;
  }

  Note? updateNote(
    String id, {
    String? title,
    String? content,
    List<String>? tags,
    String? category,
    NoteFormat? format,
  }) {
    final index = state.notes.indexWhere((n) => n.id == id);
    if (index == -1) return null;

    var note = state.notes[index];
    var newTitle = title ?? note.title;
    var newContent = content ?? note.content;
    var newTags = tags ?? note.tags;

    // 仅在传入 content 时才提取标签，标题由调用方显式传入
    if (content != null) {
      final contentTags = extractTags(content);
      newTags = {
        ...note.tags.where((t) => !contentTags.contains(t)),
        ...contentTags,
      }.toList();
    }

    note = note.copyWith(
      title: newTitle,
      content: newContent,
      tags: newTags,
      category: category ?? note.category,
      format: format ?? note.format,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.local,
    );

    final newNotes = List<Note>.from(state.notes);
    newNotes[index] = note;
    state = state.copyWith(notes: newNotes);
    _saveToCache();
    return note;
  }

  void deleteNote(String id) {
    final newNotes = state.notes.where((n) => n.id != id).toList();
    var newCurrentId = state.currentNoteId;
    if (state.currentNoteId == id) {
      newCurrentId = newNotes.isNotEmpty ? newNotes.first.id : null;
    }
    state = state.copyWith(notes: newNotes, currentNoteId: newCurrentId);
    _saveToCache();
  }

  void deleteNotes(Set<String> ids) {
    final newNotes = state.notes.where((n) => !ids.contains(n.id)).toList();
    var newCurrentId = state.currentNoteId;
    if (newCurrentId != null && ids.contains(newCurrentId)) {
      newCurrentId = newNotes.isNotEmpty ? newNotes.first.id : null;
    }
    state = state.copyWith(notes: newNotes, currentNoteId: newCurrentId);
    _saveToCache();
  }

  void setCurrentNote(String id) {
    state = state.copyWith(currentNoteId: id);
  }

  void setSortBy(String sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  void setFilterTag(String? tag) {
    state = tag == null
        ? state.copyWith(clearFilterTag: true)
        : state.copyWith(filterTag: tag);
  }

  // ——— 同步引擎回写口（SyncNotesPort 适配所需的原子操作，doc/sync-design.md §8）———
  // 所有远端权威变更都经此流入内存状态并持久化，引擎不直写存储（多窗口不变量）。

  /// 当前全部笔记快照（引擎读取口，避免外部触碰 protected 的 state）。
  List<Note> snapshot() => state.notes;

  /// 按 id 覆盖或新增（远端权威内容落盘，[note] 已由引擎置好 synced 态）。
  void applyRemoteUpsert(Note note) {
    final index = state.notes.indexWhere((n) => n.id == note.id);
    final newNotes = List<Note>.from(state.notes);
    if (index == -1) {
      newNotes.insert(0, note);
    } else {
      newNotes[index] = note;
    }
    state = state.copyWith(notes: newNotes);
    _saveToCache();
  }

  /// 远端删除传播到本地。
  void applyRemoteDelete(String noteId) => deleteNote(noteId);

  /// 迁移对齐：以远端 id 改写本地笔记 id（§12 先迁移者胜）。
  void rewriteNoteId(String oldId, String newId) {
    final index = state.notes.indexWhere((n) => n.id == oldId);
    if (index == -1) return;
    final newNotes = List<Note>.from(state.notes);
    newNotes[index] = newNotes[index].copyWith(id: newId);
    state = state.copyWith(
      notes: newNotes,
      currentNoteId: state.currentNoteId == oldId ? newId : state.currentNoteId,
    );
    _saveToCache();
  }

  /// 推送成功回写：filePath + synced（blobSha 由 base 表持有，不再依赖 note.sha）。
  void markPushed(String noteId, String filePath) {
    final index = state.notes.indexWhere((n) => n.id == noteId);
    if (index == -1) return;
    final newNotes = List<Note>.from(state.notes);
    newNotes[index] = newNotes[index].copyWith(
      syncStatus: SyncStatus.synced,
      syncedAt: DateTime.now(),
      filePath: filePath,
    );
    state = state.copyWith(notes: newNotes);
    _saveToCache();
  }

  void _saveToCache() {
    _repository.saveNotes(state.notes);
  }
}

final notesProvider = StateNotifierProvider<NotesNotifier, NotesState>((ref) {
  return NotesNotifier(ref.watch(notesRepositoryProvider));
});
