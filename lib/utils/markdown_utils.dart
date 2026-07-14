import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String generateId() => _uuid.v4().replaceAll('-', '').substring(0, 16);

String? extractTitle(String content) {
  if (content.isEmpty) return null;

  final lines = content.split('\n');
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('# ')) {
      return trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
    }
    if (trimmed.isNotEmpty &&
        !trimmed.startsWith('#') &&
        !trimmed.startsWith('---') &&
        !trimmed.startsWith('```')) {
      return trimmed.length > 50 ? '${trimmed.substring(0, 50)}...' : trimmed;
    }
  }

  return null;
}

/// txt 笔记的派生标题：取正文首个非空行、截断至 80 字符。
///
/// txt 笔记没有独立标题字段（不再向用户展示标题输入框），标题完全由正文
/// 首行派生，用于列表卡片显示与同步文件名（allocatePath）。全空内容返回空串，
/// 由上层回退到默认「无标题」文案 / untitled 文件名。
String deriveTxtTitle(String content) {
  if (content.isEmpty) return '';
  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.length <= 80) return trimmed;
    var cut = trimmed.substring(0, 80);
    // 避免截断在 UTF-16 代理对中间产生非法字符。
    final last = cut.codeUnitAt(cut.length - 1);
    if (last >= 0xD800 && last <= 0xDBFF) cut = cut.substring(0, cut.length - 1);
    return cut;
  }
  return '';
}

List<String> extractTags(String content) {
  if (content.isEmpty) return [];

  final tags = <String>{};
  final lines = content.split('\n');

  for (final line in lines) {
    if (line.trim().startsWith('# ')) continue;

    final matches = RegExp(r'(?<!\w)#([a-zA-Z\u4e00-\u9fa5][\w\u4e00-\u9fa5]*)')
        .allMatches(line);

    for (final match in matches) {
      final tag = match.group(1)!;
      if (tag.length <= 20) {
        tags.add(tag);
      }
    }
  }

  return tags.toList()..sort();
}

String stripMarkdown(String content) {
  return content
      .replaceAll(RegExp(r'```[\s\S]*?```'), '')
      .replaceAll(RegExp(r'`[^`]+`'), '')
      .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '')
      .replaceAll(RegExp(r'\[([^\]]+)\]\(.*?\)'), r'$1')
      .replaceAll(RegExp(r'[#*_~>=\-|`]'), '')
      .replaceAll(RegExp(r'\n+'), ' ')
      .trim();
}

Map<String, dynamic> parseFrontmatter(String content) {
  if (!content.startsWith('---')) {
    return {'meta': <String, dynamic>{}, 'content': content};
  }

  final endIndex = content.indexOf('---', 3);
  if (endIndex == -1) {
    return {'meta': <String, dynamic>{}, 'content': content};
  }

  final frontmatter = content.substring(3, endIndex).trim();
  final body = content.substring(endIndex + 3).trim();

  final meta = <String, dynamic>{};
  for (final line in frontmatter.split('\n')) {
    final colonIndex = line.indexOf(':');
    if (colonIndex == -1) continue;

    final key = line.substring(0, colonIndex).trim();
    var value = line.substring(colonIndex + 1).trim();

    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }

    if (value.startsWith('[') && value.endsWith(']')) {
      meta[key] = value.substring(1, value.length - 1).split(',').map((v) {
        final trimmed = v.trim();
        if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
            (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
          return trimmed.substring(1, trimmed.length - 1);
        }
        return trimmed;
      }).toList();
    } else {
      meta[key] = value;
    }
  }

  return {'meta': meta, 'content': body};
}

String generateFrontmatter(Map<String, dynamic> meta) {
  final lines = <String>['---'];
  for (final entry in meta.entries) {
    if (entry.value is List) {
      final values = (entry.value as List).map((v) => '"$v"').join(', ');
      lines.add('${entry.key}: [$values]');
    } else {
      lines.add('${entry.key}: "${entry.value}"');
    }
  }
  lines.add('---');
  return lines.join('\n');
}
