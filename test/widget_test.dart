import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:casual/data/sync/remote/remote_repo.dart';
import 'package:casual/data/sync/sync_engine_provider.dart';
import 'package:casual/data/sync/sync_planner.dart' show RemoteFileState;
import 'package:casual/domain/models/models.dart';
import 'package:casual/l10n/generated/app_localizations.dart';
import 'package:casual/main.dart';
import 'package:casual/pages/note_window_page.dart';
import 'package:casual/pages/notes_page.dart';
import 'package:casual/services/note_window_service.dart';

/// 空远端：head 为 null（等价空仓库），不产生任何网络请求。
/// 让走 v2 引擎的同步在测试中稳定跑通（无真实 GitHub Git Data API）。
class _EmptyRemote implements RemoteRepo {
  @override
  Future<String?> fetchHead() async => null;

  @override
  Future<List<RemoteFileState>> listTree(String headSha) async => const [];

  @override
  Future<String> fetchBlob(String blobSha) async => '';

  @override
  Future<RemoteCommitResult> commitChanges(RemoteCommitRequest request) async =>
      const RemoteCommitResult();

  @override
  Future<DateTime?> fetchLastCommitTime(String path) async => null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app boots into notes view', (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(const ProviderScope(child: GitNoteApp()));
    await tester.pumpAndSettle();

    expect(find.text('casual'), findsOneWidget);
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
          remoteRepoFactoryProvider.overrideWithValue((_) => _EmptyRemote()),
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

    expect(find.byIcon(Icons.push_pin), findsOneWidget);

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
