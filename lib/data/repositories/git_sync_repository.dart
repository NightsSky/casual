import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import '../services/gitee_service.dart';
import '../services/github_service.dart';

final gitHubServiceProvider = Provider<GitHubService>((ref) {
  return GitHubService();
});

final giteeServiceProvider = Provider<GiteeService>((ref) {
  return GiteeService();
});

final gitSyncRepositoryProvider = Provider<GitSyncRepository>((ref) {
  return GitSyncRepository(
    gitHubService: ref.watch(gitHubServiceProvider),
    giteeService: ref.watch(giteeServiceProvider),
  );
});

class GitSyncRepository {
  const GitSyncRepository({
    required GitHubService gitHubService,
    required GiteeService giteeService,
  })  : _gitHubService = gitHubService,
        _giteeService = giteeService;

  final GitHubService _gitHubService;
  final GiteeService _giteeService;

  Future<bool> testConnection(GitConfig config) {
    if (config.platform == GitPlatform.github) {
      return _gitHubService.testConnection(config.token);
    }
    return _giteeService.testConnection(config.token);
  }

  Future<List<Note>> pullNotes(GitConfig config) async {
    late List<Map<String, dynamic>> files;
    if (config.platform == GitPlatform.github) {
      files = await _gitHubService.listFiles(
        owner: config.owner,
        repo: config.repo,
        branch: config.branch,
        token: config.token,
        path: config.notesDir,
      );
    } else {
      files = await _giteeService.listFiles(
        owner: config.owner,
        repo: config.repo,
        branch: config.branch,
        token: config.token,
        path: config.notesDir,
      );
    }

    final notes = <Note>[];
    for (final file in files) {
      final fileName = file['name'] as String;

      NoteFormat? format;
      String title;
      if (fileName.endsWith('.md')) {
        format = NoteFormat.markdown;
        title = fileName.replaceAll('.md', '');
      } else if (fileName.endsWith('.txt')) {
        format = NoteFormat.txt;
        title = fileName.replaceAll('.txt', '');
      } else {
        continue;
      }

      late String content;
      if (config.platform == GitPlatform.github) {
        content = await _gitHubService.getFileContent(
          owner: config.owner,
          repo: config.repo,
          path: file['path'] as String,
          token: config.token,
          branch: config.branch,
        );
      } else {
        content = await _giteeService.getFileContent(
          owner: config.owner,
          repo: config.repo,
          path: file['path'] as String,
          token: config.token,
          branch: config.branch,
        );
      }

      notes.add(Note(
        id: '',
        title: title,
        content: content,
        format: format,
        filePath: file['path'] as String?,
        sha: file['sha'] as String?,
        updatedAt: file['updated_at'] != null
            ? DateTime.tryParse(file['updated_at'] as String) ?? DateTime.now()
            : DateTime.now(),
        syncStatus: SyncStatus.synced,
      ));
    }

    return notes;
  }

  Future<Map<String, dynamic>?> pushNote(GitConfig config, Note note) async {
    final extension = note.format == NoteFormat.markdown ? 'md' : 'txt';
    final filePath = note.filePath != null && note.filePath!.isNotEmpty
        ? note.filePath!
        : '${config.notesDir}/${note.title}.$extension';

    // 推送前以远程当前 sha 为准补齐更新凭据，避免本地旧缓存缺 sha 时
    // Gitee/GitHub 把更新误判为创建同名文件；若远程已被其他端改动则中止。
    final remoteSha = config.platform == GitPlatform.github
        ? await _gitHubService.getFileSha(
            owner: config.owner,
            repo: config.repo,
            path: filePath,
            token: config.token,
            branch: config.branch,
          )
        : await _giteeService.getFileSha(
            owner: config.owner,
            repo: config.repo,
            path: filePath,
            token: config.token,
            branch: config.branch,
          );
    final localSha = note.sha;
    if (remoteSha != null &&
        localSha != null &&
        localSha.isNotEmpty &&
        remoteSha != localSha) {
      throw Exception('远程文件已被修改，请先同步');
    }
    final effectiveSha = remoteSha;

    late Map<String, dynamic> result;
    if (config.platform == GitPlatform.github) {
      result = await _gitHubService.createOrUpdateFile(
        owner: config.owner,
        repo: config.repo,
        path: filePath,
        content: note.content,
        message: 'Update note: ${note.title}',
        token: config.token,
        branch: config.branch,
        sha: effectiveSha,
      );
    } else {
      result = await _giteeService.createOrUpdateFile(
        owner: config.owner,
        repo: config.repo,
        path: filePath,
        content: note.content,
        message: 'Update note: ${note.title}',
        token: config.token,
        branch: config.branch,
        sha: effectiveSha,
      );
    }

    return {
      'filePath': filePath,
      'sha': result['content']?['sha'],
    };
  }

  Future<void> deleteRemoteNote(
    GitConfig config, {
    required String filePath,
    String? sha,
  }) async {
    // 本地缓存可能缺 sha（旧数据或从列表导入未带 sha），删除前先向远程补一次。
    var effectiveSha = sha;
    if (effectiveSha == null || effectiveSha.isEmpty) {
      effectiveSha = config.platform == GitPlatform.github
          ? await _gitHubService.getFileSha(
              owner: config.owner,
              repo: config.repo,
              path: filePath,
              token: config.token,
              branch: config.branch,
            )
          : await _giteeService.getFileSha(
              owner: config.owner,
              repo: config.repo,
              path: filePath,
              token: config.token,
              branch: config.branch,
            );
    }

    // 远程文件已不存在，视为删除成功。
    if (effectiveSha == null || effectiveSha.isEmpty) return;

    if (config.platform == GitPlatform.github) {
      await _gitHubService.deleteFile(
        owner: config.owner,
        repo: config.repo,
        path: filePath,
        token: config.token,
        branch: config.branch,
        sha: effectiveSha,
      );
      return;
    }

    await _giteeService.deleteFile(
      owner: config.owner,
      repo: config.repo,
      path: filePath,
      token: config.token,
      branch: config.branch,
      sha: effectiveSha,
    );
  }
}
