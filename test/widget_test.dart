import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gitnote_flutter/data/repositories/git_sync_repository.dart';
import 'package:gitnote_flutter/data/services/gitee_service.dart';
import 'package:gitnote_flutter/data/services/github_service.dart';
import 'package:gitnote_flutter/domain/models/models.dart';
import 'package:gitnote_flutter/l10n/generated/app_localizations.dart';
import 'package:gitnote_flutter/main.dart';
import 'package:gitnote_flutter/pages/note_window_page.dart';
import 'package:gitnote_flutter/pages/notes_page.dart';
import 'package:gitnote_flutter/providers/git_provider.dart';
import 'package:gitnote_flutter/providers/notes_provider.dart';
import 'package:gitnote_flutter/services/note_window_service.dart';

class _FakeGitHubService extends GitHubService {
  @override
  Future<List<Map<String, dynamic>>> listFiles({
    required String owner,
    required String repo,
    required String branch,
    required String token,
    String path = '',
  }) async {
    return [];
  }
}

class _SyncOrderGitHubService extends GitHubService {
  final calls = <String>[];
  String remoteContent = 'remote old';
  String remoteSha = 'old-sha';

  @override
  Future<String?> getFileSha({
    required String owner,
    required String repo,
    required String path,
    required String token,
    required String branch,
  }) async {
    calls.add('sha:$path');
    return remoteSha;
  }

  @override
  Future<List<Map<String, dynamic>>> listFiles({
    required String owner,
    required String repo,
    required String branch,
    required String token,
    String path = '',
  }) async {
    calls.add('list');
    return [
      {
        'name': 'Draft.txt',
        'path': 'notes/Draft.txt',
        'type': 'file',
        'sha': remoteSha,
      },
    ];
  }

  @override
  Future<String> getFileContent({
    required String owner,
    required String repo,
    required String path,
    required String token,
    required String branch,
  }) async {
    calls.add('content');
    return remoteContent;
  }

  @override
  Future<Map<String, dynamic>> createOrUpdateFile({
    required String owner,
    required String repo,
    required String path,
    required String content,
    required String message,
    required String token,
    required String branch,
    String? sha,
  }) async {
    calls.add('push:$content');
    remoteContent = content;
    remoteSha = 'new-sha';
    return {
      'content': {'sha': remoteSha},
    };
  }
}

class _PushShaGitHubService extends GitHubService {
  String? pushedSha;

  @override
  Future<String?> getFileSha({
    required String owner,
    required String repo,
    required String path,
    required String token,
    required String branch,
  }) async {
    return 'remote-sha';
  }

  @override
  Future<Map<String, dynamic>> createOrUpdateFile({
    required String owner,
    required String repo,
    required String path,
    required String content,
    required String message,
    required String token,
    required String branch,
    String? sha,
  }) async {
    pushedSha = sha;
    return {
      'content': {'sha': 'new-sha'},
    };
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('full sync pushes local edits before importing remote notes', () async {
    final gitHubService = _SyncOrderGitHubService();
    final container = ProviderContainer(
      overrides: [
        gitHubServiceProvider.overrideWithValue(gitHubService),
      ],
    );
    addTearDown(container.dispose);

    container.read(gitProvider.notifier).setConfig(
          const GitConfig(
            platform: GitPlatform.github,
            token: 'token',
            owner: 'owner',
            repo: 'repo',
          ),
        );

    final notesNotifier = container.read(notesProvider.notifier);
    final note = notesNotifier.createNote(
      title: 'Draft',
      content: 'remote old',
    );
    notesNotifier.markSynced(note.id, 'notes/Draft.txt', sha: 'old-sha');
    notesNotifier.updateNote(note.id, content: 'local edited');

    final remoteNotes = await container.read(gitProvider.notifier).fullSync();
    for (final note in remoteNotes) {
      notesNotifier.importNote(note);
    }

    final syncedNote = container.read(notesProvider).notes.single;
    expect(gitHubService.calls, [
      'sha:notes/Draft.txt',
      'push:local edited',
      'list',
      'content',
    ]);
    expect(syncedNote.content, 'local edited');
    expect(syncedNote.syncStatus, SyncStatus.synced);
    expect(syncedNote.sha, 'new-sha');
  });

  test('push note fills missing local sha from remote file', () async {
    final gitHubService = _PushShaGitHubService();
    final repository = GitSyncRepository(
      gitHubService: gitHubService,
      giteeService: GiteeService(),
    );

    final result = await repository.pushNote(
      const GitConfig(
        platform: GitPlatform.github,
        token: 'token',
        owner: 'owner',
        repo: 'repo',
      ),
      Note(
        id: 'note',
        title: 'Draft',
        content: 'local edited',
        filePath: 'notes/Draft.txt',
      ),
    );

    expect(gitHubService.pushedSha, 'remote-sha');
    expect(result?['filePath'], 'notes/Draft.txt');
    expect(result?['sha'], 'new-sha');
  });

  test('remote import marks unsynced local edits as conflict', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notesNotifier = container.read(notesProvider.notifier);
    final note = notesNotifier.createNote(
      title: 'Draft',
      content: 'remote old',
    );
    notesNotifier.markSynced(note.id, 'notes/Draft.txt', sha: 'old-sha');
    notesNotifier.updateNote(note.id, content: 'local edited');

    // 远程更新时间不可靠时也不能覆盖本地未同步编辑，只能进入冲突态等待用户处理。
    notesNotifier.importNote(
      Note(
        id: '',
        title: 'Draft',
        content: 'remote changed',
        filePath: 'notes/Draft.txt',
        sha: 'remote-sha',
        updatedAt: DateTime.now().add(const Duration(minutes: 1)),
        syncStatus: SyncStatus.synced,
      ),
    );

    final conflictNote = container.read(notesProvider).notes.single;
    expect(conflictNote.content, 'local edited');
    expect(conflictNote.syncStatus, SyncStatus.conflict);
    expect(conflictNote.sha, 'remote-sha');
  });

  testWidgets('app boots into notes view', (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(const ProviderScope(child: GitNoteApp()));
    await tester.pumpAndSettle();

    expect(find.text('GitNote'), findsOneWidget);
    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('create note flow opens editor and saves draft', (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(const ProviderScope(child: GitNoteApp()));
    await tester.pumpAndSettle();

    // FAB 为两段式交互：第一次点击展开格式选择器，第二次点击（对勾）确认创建
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('Untitled note'), findsWidgets);
    expect(find.byType(TextField), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).first, 'Project plan');
    await tester.enterText(
        find.byType(TextField).last, '# Project plan\n\nShip routing first.');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Project plan'), findsOneWidget);
  });

  testWidgets('sync dialog closes without popping notes route', (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    const gitConfig = GitConfig(
      platform: GitPlatform.github,
      token: 'token',
      owner: 'owner',
      repo: 'repo',
    );
    SharedPreferences.setMockInitialValues({
      'gitnote_git_config': jsonEncode(gitConfig.toJson()),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gitHubServiceProvider.overrideWithValue(_FakeGitHubService()),
        ],
        child: const GitNoteApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NotesPage),
        matching: find.byIcon(Icons.sync),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NotesPage), findsOneWidget);
    expect(find.text('Sync complete'), findsOneWidget);
  });

  test('txt and markdown notes can detach when note windows are supported', () {
    final txtNote = Note(id: 'txt-note', title: 'TXT', format: NoteFormat.txt);
    final markdownNote = Note(
      id: 'markdown-note',
      title: 'Markdown',
      format: NoteFormat.markdown,
    );

    expect(
      NoteWindowService.canDetach(txtNote),
      NoteWindowService.isSupported,
    );
    expect(
      NoteWindowService.canDetach(markdownNote),
      NoteWindowService.isSupported,
    );
  });

  testWidgets('markdown note window opens as markdown preview', (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(
      MaterialApp(
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
          windowController: WindowController.fromWindowId(1),
          noteId: 'markdown-note',
          initialTitle: 'Markdown',
          initialContent: '# Heading\n\nBody',
          initialFormat: NoteFormat.markdown,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Markdown), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    expect(find.byIcon(Icons.opacity), findsOneWidget);
    expect(find.byIcon(Icons.format_bold), findsNothing);

    await tester.tap(find.byIcon(Icons.push_pin_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.opacity));
    await tester.pumpAndSettle();

    expect(find.text('Window opacity'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(Markdown), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.format_bold), findsOneWidget);
    expect(find.byIcon(Icons.format_italic), findsOneWidget);
  });
}
