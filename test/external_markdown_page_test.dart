import 'package:casual/l10n/generated/app_localizations.dart';
import 'package:casual/pages/external_markdown_page.dart';
import 'package:casual/services/external_markdown_file_service.dart';
import 'package:casual/widgets/markdown_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

Widget _buildExternalMarkdownPage(ExternalMarkdownFile file) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('zh')],
    home: ExternalMarkdownPage(file: file),
  );
}

void main() {
  testWidgets(
      'external Markdown preview hides front matter and resolves image base',
      (tester) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.binding.platformDispatcher.clearLocaleTestValue();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const filePath = r'C:\notes\meeting.md';
    const source = '''---
title: Meeting
tags: [work]
---
# Agenda

![Diagram](assets/diagram.png)
''';

    await tester.pumpWidget(
      _buildExternalMarkdownPage(
        const ExternalMarkdownFile(path: filePath, content: source),
      ),
    );
    await tester.pumpAndSettle();

    // 外部 Markdown 也只保留一个模式按钮，并按分屏、预览、编辑循环。
    final modeButton =
        find.byKey(const ValueKey('externalMarkdownModeCycleButton'));
    expect(modeButton, findsOneWidget);
    expect(find.byIcon(Icons.vertical_split), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);

    await tester.tap(modeButton);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byType(MarkdownPreview), findsOneWidget);

    await tester.tap(modeButton);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byType(MarkdownPreview), findsNothing);

    await tester.tap(modeButton);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.vertical_split), findsOneWidget);

    final preview = tester.widget<MarkdownPreview>(
      find.byType(MarkdownPreview),
    );
    expect(preview.data, '# Agenda\n\n![Diagram](assets/diagram.png)\n');
    expect(
      preview.imageDirectory,
      Uri.file(
        '${path.dirname(filePath)}${path.separator}',
        windows: true,
      ).toString(),
    );
  });
}
