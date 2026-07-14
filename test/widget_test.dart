import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:casual/data/repositories/notes_repository.dart';
import 'package:casual/data/services/storage_service.dart';
import 'package:casual/data/sync/remote/remote_repo.dart';
import 'package:casual/data/sync/sync_engine_provider.dart';
import 'package:casual/data/sync/sync_planner.dart' show RemoteFileState;
import 'package:casual/domain/models/models.dart';
import 'package:casual/domain/models/reminder.dart';
import 'package:casual/l10n/generated/app_localizations.dart';
import 'package:casual/main.dart';
import 'package:casual/pages/editor_page.dart';
import 'package:casual/pages/note_tag_window_page.dart';
import 'package:casual/pages/note_window_page.dart';
import 'package:casual/pages/notes_page.dart';
import 'package:casual/pages/reminder_alarm_window_page.dart';
import 'package:casual/providers/notes_provider.dart';
import 'package:casual/providers/reminder_provider.dart';
import 'package:casual/services/reminder_service.dart';
import 'package:casual/services/note_window_service.dart';
import 'package:casual/utils/markdown_utils.dart';
import 'package:casual/widgets/reminder_alarm_host.dart';

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

class _SeededNotesNotifier extends NotesNotifier {
  _SeededNotesNotifier(Note note)
      : super(NotesRepository(storageService: StorageService())) {
    state = NotesState(notes: [note], currentNoteId: note.id);
  }
}

class _FakeReminderService extends ReminderService {
  _FakeReminderService() : super(StorageService());

  final StreamController<Reminder> _controller =
      StreamController<Reminder>.broadcast();

  @override
  Stream<Reminder> get windowsAlarmStream => _controller.stream;

  void fire(Reminder reminder) => _controller.add(reminder);

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

class _DetachedEditorHarness extends StatelessWidget {
  const _DetachedEditorHarness({required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: EditorPage(noteId: noteId),
    );
  }
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

    // 默认新建 txt：无独立标题输入框，只有正文一个 TextField，
    // 标题从正文首行派生。
    expect(find.text('Untitled note'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(
        find.byType(TextField), 'Project plan\n\nShip routing first.');
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

  testWidgets('reminder alarm host shows in-app alarm dialog', (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    final service = _FakeReminderService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
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
          home: ReminderAlarmHost(
            openAlarmWindow: (_) async => false,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    service.fire(Reminder(title: 'Drink water', time: DateTime.now()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Assistant'), findsOneWidget);
    expect(find.text('Drink water'), findsOneWidget);
    expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);
    expect(find.text('Local assistant reminder'), findsOneWidget);
    expect(find.text('Remind later'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Drink water'), findsNothing);
  });

  testWidgets('reminder alarm window renders standalone popup', (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('en'),
          Locale('zh'),
        ],
        home: ReminderAlarmWindowPage(message: 'Drink water'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Assistant'), findsOneWidget);
    expect(find.text('Drink water'), findsOneWidget);
    expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);
    expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);
    expect(find.text('Local assistant reminder'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
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

  group('deriveTxtTitle', () {
    test('takes the first non-empty line', () {
      expect(deriveTxtTitle('Hello world\nsecond line'), 'Hello world');
    });

    test('skips leading blank lines and trims', () {
      expect(deriveTxtTitle('\n\n   Meeting notes  \nbody'), 'Meeting notes');
    });

    test('returns empty string for blank content', () {
      expect(deriveTxtTitle(''), '');
      expect(deriveTxtTitle('   \n\t\n'), '');
    });

    test('truncates to 80 characters', () {
      final long = 'a' * 100;
      expect(deriveTxtTitle(long).length, 80);
    });
  });

  testWidgets('detached editor only shows read-only notice', (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    final note = Note(
      id: 'detached-note',
      title: 'Detached note',
      content: '# Hidden preview\n\nHidden editor body',
      format: NoteFormat.markdown,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesProvider.overrideWith((ref) => _SeededNotesNotifier(note)),
          externallyOpenNotesProvider.overrideWith((ref) => {note.id}),
        ],
        child: _DetachedEditorHarness(noteId: note.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
          'This note is being edited in a separate window and is read-only here'),
      findsOneWidget,
    );
    expect(find.text('Focus window'), findsOneWidget);
    expect(find.byType(Markdown), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
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
    expect(find.text('Markdown'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
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
    final contentField = tester.widget<TextField>(find.byType(TextField).last);
    expect(contentField.focusNode?.hasFocus, isTrue);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.format_bold), findsOneWidget);
    expect(find.byIcon(Icons.format_italic), findsOneWidget);
  });

  testWidgets('txt note window toggles between edit and preview',
      (tester) async {
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
          noteId: 'txt-note',
          initialTitle: '',
          initialContent: 'first line\nsecond line',
          initialFormat: NoteFormat.txt,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // txt 默认进入预览态：正文以可选中纯文本呈现，无可编辑 TextField，
    // 无 Markdown 渲染与工具栏，标题栏提供切换到编辑的按钮。
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byType(Markdown), findsNothing);
    expect(find.byIcon(Icons.format_bold), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    // 切到编辑态：正文可编辑，内容随共享 controller 保留，按钮回到预览图标。
    expect(find.byType(SelectableText), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    final contentField = tester.widget<TextField>(find.byType(TextField));
    expect(contentField.controller?.text, 'first line\nsecond line');
    expect(contentField.focusNode?.hasFocus, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    // 切回预览态：内容随共享 controller 保留，不丢失编辑内容。
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text('first line\nsecond line'), findsOneWidget);
  });

  testWidgets('txt tag window collapses to a capsule and expands on tap',
      (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('en'),
          Locale('zh'),
        ],
        home: NoteTagWindowPage(
          noteId: 'tag-note',
          initialContent: 'sticky first line\nmore body text',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 折叠胶囊态：只显示首行文字，无可编辑 TextField，提供展开图标。
    expect(find.text('sticky first line'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.unfold_more), findsOneWidget);

    // 点击胶囊展开：出现可编辑正文，内容为完整原文，图标变为折叠。
    await tester.tap(find.byIcon(Icons.unfold_more));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'sticky first line\nmore body text');
    expect(find.byIcon(Icons.unfold_less), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
