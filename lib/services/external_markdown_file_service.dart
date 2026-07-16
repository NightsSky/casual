import 'dart:io';

import 'package:file_selector/file_selector.dart';

/// 用户从电脑中打开的 Markdown 文件快照。
///
/// 外部文件不进入笔记仓库和 Git 同步链路，编辑页始终保留原始全文，
/// 保存时直接覆盖用户选择的同一文件。
class ExternalMarkdownFile {
  const ExternalMarkdownFile({
    required this.path,
    required this.content,
  });

  final String path;
  final String content;
}

class ExternalMarkdownFileService {
  static const _markdownFileGroup = XTypeGroup(
    label: 'Markdown',
    extensions: <String>['md', 'markdown', 'mdown', 'mkdn'],
  );

  /// 通过系统文件选择器读取一篇 Markdown；用户取消时返回 null。
  Future<ExternalMarkdownFile?> pickMarkdownFile() async {
    final selectedFile = await openFile(
      acceptedTypeGroups: const [_markdownFileGroup],
      confirmButtonText: '打开',
    );
    if (selectedFile == null) return null;

    return readMarkdownFile(selectedFile.path);
  }

  /// 从已确认可访问的文件路径读取完整 Markdown 原文。
  Future<ExternalMarkdownFile> readMarkdownFile(String path) async {
    return ExternalMarkdownFile(
      path: path,
      content: await File(path).readAsString(),
    );
  }

  /// Windows 使用真实文件路径保存，确保用户编辑的是选中的原文件。
  Future<void> saveMarkdownFile({
    required String path,
    required String content,
  }) {
    return File(path).writeAsString(content);
  }
}
