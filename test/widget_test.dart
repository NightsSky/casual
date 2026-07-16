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
import 'package:casual/pages/plan_page.dart';
import 'package:casual/pages/platform_config_page.dart';
import 'package:casual/pages/reminder_alarm_window_page.dart';
import 'package:casual/pages/repo_page.dart';
import 'package:casual/pages/settings_page.dart';
import 'package:casual/providers/notes_provider.dart';
import 'package:casual/providers/plan_provider.dart';
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
  _SeededNotesNotifier(List<Note> notes)
      : super(NotesRepository(storageService: StorageService())) {
    state = NotesState(
      notes: notes,
      currentNoteId: notes.isEmpty ? null : notes.first.id,
    );
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

  testWidgets('note list shows distinct Markdown and TXT format icons',
      (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.binding.platformDispatcher.clearLocaleTestValue();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final markdownNote = Note(
      id: 'format-markdown',
      title: 'Markdown note',
      content: '# Markdown',
      format: NoteFormat.markdown,
    );
    final txtNote = Note(
      id: 'format-txt',
      title: 'TXT note',
      content: 'Plain text',
      format: NoteFormat.txt,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesProvider.overrideWith(
            (ref) => _SeededNotesNotifier([markdownNote, txtNote]),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en'), Locale('zh')],
          home: Scaffold(body: NotesPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 两种格式的标识不仅颜色不同，图标与语义标签也可独立辨识。
    final markdownBadge =
        find.byKey(const ValueKey('noteFormatBadge-format-markdown'));
    final txtBadge = find.byKey(const ValueKey('noteFormatBadge-format-txt'));
    expect(markdownBadge, findsOneWidget);
    expect(txtBadge, findsOneWidget);
    final markdownIconFinder = find.descendant(
      of: markdownBadge,
      matching: find.byIcon(Icons.code_rounded),
    );
    final txtIconFinder = find.descendant(
      of: txtBadge,
      matching: find.byIcon(Icons.notes_rounded),
    );
    expect(markdownIconFinder, findsOneWidget);
    expect(txtIconFinder, findsOneWidget);
    expect(tester.widget<Icon>(markdownIconFinder).semanticLabel, 'MD');
    expect(tester.widget<Icon>(txtIconFinder).semanticLabel, 'TXT');
  });

  testWidgets('repository and Git platform configuration live under settings',
      (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(const ProviderScope(child: GitNoteApp()));
    await tester.pumpAndSettle();

    // 主导航第三项进入独立计划模块，不再直接进入仓库管理。
    expect(find.text('Plan'), findsOneWidget);
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanPage), findsOneWidget);

    // 设置总览分别提供仓库管理和 Git 平台配置两个独立入口。
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Repository'), findsOneWidget);
    expect(find.text('Git platform'), findsOneWidget);

    await tester.tap(find.text('Repository'));
    await tester.pumpAndSettle();
    expect(find.byType(RepoPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Git platform'));
    await tester.pumpAndSettle();
    expect(find.byType(PlatformConfigPage), findsOneWidget);

    // 全局路由由后续用例复用，验证完成后回到笔记首页，避免测试间状态串扰。
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.byType(NotesPage), findsOneWidget);
  });

  testWidgets('plan flow creates steps, completes out of order and adds record',
      (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.binding.platformDispatcher.clearLocaleTestValue();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: GitNoteApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('No plans yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('create-plan-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('plan-title-field')),
      'Release casual 1.0',
    );
    await tester.enterText(
      find.byKey(const Key('plan-goal-field')),
      'Ship a stable first release',
    );
    await tester.enterText(
      find.byKey(const Key('plan-step-title-field-0')),
      'Create the release project',
    );
    await tester.ensureVisible(find.byKey(const Key('add-plan-step-button')));
    await tester.tap(find.byKey(const Key('add-plan-step-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('plan-step-title-field-1')),
      'Start implementation',
    );
    await tester.ensureVisible(find.byKey(const Key('save-plan-button')));
    await tester.tap(find.byKey(const Key('save-plan-button')));
    await tester.pumpAndSettle();

    expect(find.text('Release casual 1.0'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanPage)),
    );
    final createdPlan = container.read(planProvider).plans.single;
    expect(createdPlan.steps, hasLength(2));
    expect(
      createdPlan.steps.every(
        (step) => step.reminderEnabled && step.reminderMinutesBefore == 0,
      ),
      isTrue,
    );

    await tester.tap(find.text('Release casual 1.0'));
    await tester.pumpAndSettle();
    expect(find.text('Plan steps'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Step 1'), findsOneWidget);
    expect(find.text('Step 2'), findsOneWidget);
    expect(find.text('Plan created'), findsOneWidget);

    final completeButtons = find.widgetWithText(FilledButton, 'Complete step');
    await tester.ensureVisible(completeButtons.last);
    await tester.tap(completeButtons.last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('plan-step-completion-note-field')),
      'Implementation started early',
    );
    await tester.tap(
      find.byKey(const Key('confirm-complete-plan-step-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Implementation started early'), findsWidgets);

    final remainingComplete =
        find.widgetWithText(FilledButton, 'Complete step');
    await tester.ensureVisible(remainingComplete);
    await tester.tap(remainingComplete);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirm-complete-plan-step-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);

    final reopenButton = find.widgetWithText(TextButton, 'Reopen step').last;
    await tester.ensureVisible(reopenButton);
    await tester.tap(reopenButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();
    expect(find.text('50%'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('add-plan-record-button')),
    );
    await tester.tap(find.byKey(const Key('add-plan-record-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('plan-record-field')),
      'Finished the plan data model',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Finished the plan data model'));
    expect(find.text('Execution record'), findsOneWidget);
    expect(find.text('Finished the plan data model'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.byType(NotesPage), findsOneWidget);
  });

  testWidgets('plan editor reorders steps and blocks decreasing times',
      (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.binding.platformDispatcher.clearLocaleTestValue();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: GitNoteApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-plan-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('plan-title-field')),
      'Reordered plan',
    );
    await tester.enterText(
      find.byKey(const Key('plan-goal-field')),
      'Verify ordered step validation',
    );
    await tester.enterText(
      find.byKey(const Key('plan-step-title-field-0')),
      'Earlier step',
    );
    await tester.ensureVisible(find.byKey(const Key('add-plan-step-button')));
    await tester.tap(find.byKey(const Key('add-plan-step-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('plan-step-title-field-1')),
      'Later step',
    );
    await tester.tap(find.byKey(const Key('remove-plan-step-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-step-title-field-1')), findsNothing);

    await tester.tap(find.byKey(const Key('add-plan-step-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('plan-step-title-field-1')),
      'Later step',
    );

    await tester.drag(
      find.byIcon(Icons.drag_handle).last,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-plan-button')));
    await tester.tap(find.byKey(const Key('save-plan-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Each step time must be no earlier than the previous step'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.byType(NotesPage), findsOneWidget);
  });

  testWidgets('plan uses list and detail split view on wide screens',
      (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.binding.platformDispatcher.clearLocaleTestValue();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final now = DateTime.now();
    final plan = Plan.create(
      title: 'Wide plan',
      goal: 'Verify the desktop split layout',
      startAt: now,
      steps: [
        PlanStep(
          title: 'Create project',
          targetAt: now.add(const Duration(days: 2)),
        ),
        PlanStep(
          title: 'Start implementation',
          targetAt: now.add(const Duration(days: 7)),
        ),
      ],
      now: now,
    );
    SharedPreferences.setMockInitialValues({
      'gitnote_plans': jsonEncode([plan.toJson()]),
    });

    await tester.pumpWidget(const ProviderScope(child: GitNoteApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('plan-list')), findsOneWidget);
    expect(find.text('Wide plan'), findsNWidgets(2));
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Plan steps'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.byType(NotesPage), findsOneWidget);
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
          notesProvider.overrideWith((ref) => _SeededNotesNotifier([note])),
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

  testWidgets('markdown note window opens as split workspace', (tester) async {
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

    // Windows 独立 Markdown 窗口默认分屏：左侧源码、右侧实时渲染，工具栏默认收起。
    expect(find.byType(Markdown), findsOneWidget);
    expect(find.text('Markdown'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('noteWindowMarkdownSplitSource')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNWidgets(2));
    // Markdown 标题栏只显示当前分屏模式的单个切换按钮。
    expect(
      find.byKey(const ValueKey('noteWindowMarkdownModeCycleButton')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.vertical_split), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
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

    final modeButton =
        find.byKey(const ValueKey('noteWindowMarkdownModeCycleButton'));
    await tester.tap(modeButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('noteWindowMarkdownSplitSource')),
      findsNothing,
    );
    expect(find.byType(Markdown), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(modeButton);
    await tester.pumpAndSettle();

    expect(find.byType(Markdown), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
    final contentField = tester.widget<TextField>(find.byType(TextField).last);
    expect(contentField.focusNode?.hasFocus, isTrue);
    expect(find.byIcon(Icons.format_bold), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    await tester.tap(modeButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('noteWindowMarkdownSplitSource')),
      findsOneWidget,
    );
    expect(find.byType(Markdown), findsOneWidget);
    expect(find.byIcon(Icons.vertical_split), findsOneWidget);

    await tester.tap(find.byTooltip('Show formatting toolbar'));
    await tester.pumpAndSettle();

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
