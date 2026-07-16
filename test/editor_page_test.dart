import 'dart:io' show Platform;

import 'package:casual/data/repositories/notes_repository.dart';
import 'package:casual/data/services/storage_service.dart';
import 'package:casual/domain/models/note.dart';
import 'package:casual/l10n/generated/app_localizations.dart';
import 'package:casual/pages/editor_page.dart';
import 'package:casual/providers/notes_provider.dart';
import 'package:casual/widgets/markdown_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EditorTestNotesNotifier extends NotesNotifier {
  _EditorTestNotesNotifier(Note note)
      : super(NotesRepository(storageService: StorageService())) {
    state = NotesState(notes: [note], currentNoteId: note.id);
  }
}

Widget _buildEditorUnderTest(Note note) {
  return ProviderScope(
    overrides: [
      notesProvider.overrideWith((ref) => _EditorTestNotesNotifier(note)),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('zh')],
      home: Scaffold(body: EditorPage(noteId: note.id)),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('wide Markdown editor cycles one mode button through all views',
      (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.binding.platformDispatcher.clearLocaleTestValue();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final note = Note(
      id: 'markdown-editor-test',
      title: 'Markdown workspace',
      content: '# Heading\n\nPreview me',
      format: NoteFormat.markdown,
    );

    await tester.pumpWidget(_buildEditorUnderTest(note));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('markdownSplitSourceEditor')),
        findsOneWidget);
    expect(find.byType(MarkdownPreview), findsOneWidget);
    expect(
        find.byKey(const ValueKey('markdownModeCycleButton')), findsOneWidget);
    expect(find.byIcon(Icons.vertical_split), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    if (Platform.isWindows) {
      // Windows 默认收起源码格式工具栏，让分屏拥有更多纵向空间。
      expect(find.byTooltip('标题'), findsNothing);
    }

    await tester.enterText(
      find.byKey(const ValueKey('markdownSplitSourceEditor')),
      '# Live preview',
    );
    await tester.pump();
    expect(
      tester.widget<MarkdownPreview>(find.byType(MarkdownPreview)).data,
      '# Live preview',
    );

    // 单按钮从当前分屏模式依次推进到预览、编辑，再回到分屏。
    final modeButton = find.byKey(const ValueKey('markdownModeCycleButton'));
    await tester.tap(modeButton);
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('markdownSplitSourceEditor')), findsNothing);
    expect(find.byType(MarkdownPreview), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(modeButton);
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownPreview), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    await tester.tap(modeButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('markdownSplitSourceEditor')),
        findsOneWidget);
    expect(find.byType(MarkdownPreview), findsOneWidget);
    expect(find.byIcon(Icons.vertical_split), findsOneWidget);
  });

  testWidgets('Markdown focus view keeps a visible exit control',
      (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.binding.platformDispatcher.clearLocaleTestValue();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final note = Note(
      id: 'markdown-focus-test',
      title: 'Focus',
      content: '# Focus',
      format: NoteFormat.markdown,
    );

    await tester.pumpWidget(_buildEditorUnderTest(note));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Full-screen edit/preview'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Exit full-screen edit/preview'), findsOneWidget);
  });
}
