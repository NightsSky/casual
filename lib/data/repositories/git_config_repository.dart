import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import '../services/storage_service.dart';
import 'notes_repository.dart';

final gitConfigRepositoryProvider = Provider<GitConfigRepository>((ref) {
  return GitConfigRepository(storageService: ref.watch(storageServiceProvider));
});

class GitConfigRepository {
  const GitConfigRepository({required StorageService storageService})
      : _storageService = storageService;

  final StorageService _storageService;

  Future<GitConfig> loadConfig() => _storageService.loadGitConfig();

  Future<void> saveConfig(GitConfig config) =>
      _storageService.saveGitConfig(config);

  Future<void> clearAll() => _storageService.clearAll();
}
