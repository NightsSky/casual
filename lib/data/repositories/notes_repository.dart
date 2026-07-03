import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(storageService: ref.watch(storageServiceProvider));
});

class NotesRepository {
  const NotesRepository({required StorageService storageService})
      : _storageService = storageService;

  final StorageService _storageService;

  Future<List<Note>> loadNotes() => _storageService.loadNotes();

  Future<void> saveNotes(List<Note> notes) => _storageService.saveNotes(notes);
}
