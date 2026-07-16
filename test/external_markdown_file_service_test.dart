import 'dart:io';

import 'package:casual/services/external_markdown_file_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory tempDirectory;
  late ExternalMarkdownFileService service;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('casual-markdown-');
    service = ExternalMarkdownFileService();
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test(
      'reads and saves complete external Markdown source without transforming it',
      () async {
    final target = File(path.join(tempDirectory.path, '会议记录.md'));
    const source = '''---
title: "会议记录"
tags: ["项目"]
---

# 结论

- 保留原始 front matter
''';

    await target.writeAsString(source);

    final opened = await service.readMarkdownFile(target.path);

    expect(opened.path, target.path);
    expect(opened.content, source);

    await service.saveMarkdownFile(path: target.path, content: source);

    expect(await target.readAsString(), source);
  });
}
