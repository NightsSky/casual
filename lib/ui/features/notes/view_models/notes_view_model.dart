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

  /// 删除笔记，并在已同步（有 filePath）时先删除远程文件，避免下次同步又被拉回来。
  /// [deleteRemote] 由上层注入（git 层），返回后再移除本地。远程删除失败会抛出异常，
  /// 此时本地保留，交由调用方提示用户。
  Future<void> deleteNoteWithRemote(
    String id, {
    required Future<void> Function(String filePath, String? sha) deleteRemote,
  }) async {
    final index = state.notes.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final note = state.notes[index];
    final filePath = note.filePath;
    if (filePath != null && filePath.isNotEmpty) {
      await deleteRemote(filePath, note.sha);
    }
    deleteNote(id);
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

  /// 批量删除，逐条尝试删除远程；远程删除失败的笔记会保留在本地并收集到返回列表中。
  /// 返回删除失败（远程报错）的笔记标题，供调用方提示。
  Future<List<String>> deleteNotesWithRemote(
    Set<String> ids, {
    required Future<void> Function(String filePath, String? sha) deleteRemote,
  }) async {
    final failed = <String>[];
    for (final id in ids) {
      final note = state.notes.cast<Note?>().firstWhere(
            (n) => n?.id == id,
            orElse: () => null,
          );
      if (note == null) continue;
      try {
        await deleteNoteWithRemote(id, deleteRemote: deleteRemote);
      } catch (_) {
        failed.add(note.title);
      }
    }
    return failed;
  }

  void setCurrentNote(String id) {
    state = state.copyWith(currentNoteId: id);
  }

  void markSynced(String id, String filePath, {String? sha}) {
    final index = state.notes.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final newNotes = List<Note>.from(state.notes);
    newNotes[index] = newNotes[index].copyWith(
      syncStatus: SyncStatus.synced,
      syncedAt: DateTime.now(),
      filePath: filePath,
      sha: sha ?? newNotes[index].sha,
    );
    state = state.copyWith(notes: newNotes);
    _saveToCache();
  }

  void markConflict(String id) {
    final index = state.notes.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final newNotes = List<Note>.from(state.notes);
    newNotes[index] = newNotes[index].copyWith(syncStatus: SyncStatus.conflict);
    state = state.copyWith(notes: newNotes);
    _saveToCache();
  }

  Note importNote(Note noteData) {
    // 优先按 filePath 查找，次选按 title+content 去重。
    var existing = state.notes.indexWhere((n) =>
        n.filePath != null &&
        n.filePath!.isNotEmpty &&
        n.filePath == noteData.filePath);

    // 若 filePath 不匹配，尝试内容去重（标题+内容一致视为同一笔记）。
    if (existing == -1) {
      existing = state.notes.indexWhere((n) =>
          n.title == noteData.title &&
          n.content.trim() == noteData.content.trim());
    }

    if (existing != -1) {
      final localNote = state.notes[existing];
      final remoteChanged = localNote.title != noteData.title ||
          localNote.content.trim() != noteData.content.trim();

      // 本地仍有未同步编辑时，远程内容只要不一致就进入冲突态，
      // 避免 Git 平台未返回可靠更新时间时误把本地刚写的内容覆盖掉。
      if (localNote.syncStatus == SyncStatus.local && remoteChanged) {
        final index = state.notes.indexWhere((n) => n.id == localNote.id);
        if (index != -1) {
          final newNotes = List<Note>.from(state.notes);
          newNotes[index] = newNotes[index].copyWith(
            syncStatus: SyncStatus.conflict,
            // 保留 sha/filePath，方便后续手动解决冲突后推送。
            sha: noteData.sha,
            filePath: noteData.filePath,
          );
          state = state.copyWith(notes: newNotes);
          _saveToCache();
          return newNotes[index];
        }
      }

      // 远程时间更新 → 覆盖本地；本地更新 → 标记冲突。
      final localNewer = localNote.updatedAt.isAfter(noteData.updatedAt);

      if (localNewer && localNote.syncStatus == SyncStatus.local) {
        // 本地未同步版本更新，标记冲突。
        final index = state.notes.indexWhere((n) => n.id == localNote.id);
        if (index != -1) {
          final newNotes = List<Note>.from(state.notes);
          newNotes[index] = newNotes[index].copyWith(
            syncStatus: SyncStatus.conflict,
            // 保留 sha/filePath，方便后续手动解决冲突后推送。
            sha: noteData.sha,
            filePath: noteData.filePath,
          );
          state = state.copyWith(notes: newNotes);
          _saveToCache();
          return newNotes[index];
        }
      }

      // 远程更新或本地已同步 → 覆盖。
      final updated = updateNote(
        localNote.id,
        title: noteData.title,
        content: noteData.content,
        tags: noteData.tags,
      );
      if (updated == null) return noteData;

      // updateNote 会把状态标记为 local，这里回写远程同步信息（sha/filePath/synced）。
      final index = state.notes.indexWhere((n) => n.id == updated.id);
      if (index == -1) return updated;
      final newNotes = List<Note>.from(state.notes);
      newNotes[index] = newNotes[index].copyWith(
        sha: noteData.sha,
        filePath: noteData.filePath,
        syncStatus: SyncStatus.synced,
        syncedAt: DateTime.now(),
      );
      state = state.copyWith(notes: newNotes);
      _saveToCache();
      return newNotes[index];
    }

    // 新笔记。
    final note = Note(
      id: generateId(),
      title: noteData.title,
      content: noteData.content,
      tags: noteData.tags,
      category: noteData.category,
      format: noteData.format,
      createdAt: noteData.createdAt,
      updatedAt: noteData.updatedAt,
      syncedAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
      filePath: noteData.filePath,
      sha: noteData.sha,
    );
    state = state.copyWith(notes: [note, ...state.notes]);
    _saveToCache();
    return note;
  }

  void setSortBy(String sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  void setFilterTag(String? tag) {
    state = tag == null
        ? state.copyWith(clearFilterTag: true)
        : state.copyWith(filterTag: tag);
  }

  void _saveToCache() {
    _repository.saveNotes(state.notes);
  }
}

final notesProvider = StateNotifierProvider<NotesNotifier, NotesState>((ref) {
  return NotesNotifier(ref.watch(notesRepositoryProvider));
});
