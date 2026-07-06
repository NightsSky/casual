/// YAML front-matter 的解析与序列化（doc/sync-design.md §5.1 / §9.2）。
///
/// 刻意不引入完整 YAML 库，只支持笔记元数据所需的子集：
/// - 标量：`key: value`（可选单/双引号包裹，双引号支持 `\\` 与 `\"` 转义）
/// - 行内列表：`key: [a, b, c]`
///
/// 兼容性原则：**读宽容、写保守、外来数据不丢**。
/// - 无法识别的行（注释、嵌套块、缩进续行等，可能来自 Obsidian 等外部工具）
///   原样保留，序列化时按原顺序回写，只改动本应用管理的键；
/// - 解析容忍 CRLF（去掉行尾 `\r`），序列化一律输出 LF（git 文本惯例）；
/// - 起始行不是 `---` 或找不到闭合 `---` 时，整个内容视为正文。
library;

/// 笔记 front-matter 的管理键（引擎写入的字段，doc/sync-design.md §5.1）。
abstract final class FmKeys {
  static const id = 'id';
  static const created = 'created';
  static const updated = 'updated';
  static const category = 'category';
  static const tags = 'tags';
}

/// 解析结果。[values] 只含可识别的标量/列表；不可识别行保留在内部原始行中，
/// 经 [serialize] 无损回写。
class FrontMatterDoc {
  FrontMatterDoc._({
    required this.hasFrontMatter,
    required Map<String, Object> values,
    required this.body,
    required List<String> rawLines,
    required Map<String, int> keyLineIndex,
  })  : _values = values,
        _rawLines = rawLines,
        _keyLineIndex = keyLineIndex;

  /// 原文是否带有合法的 front-matter 块。
  final bool hasFrontMatter;

  /// 闭合 `---` 行之后的正文原文（保留可能的前导空行，保证往返无损）。
  final String body;

  final Map<String, Object> _values;
  final List<String> _rawLines;
  final Map<String, int> _keyLineIndex;

  /// 解析出的键值只读视图（值类型为 String 或 List&lt;String&gt;）。
  Map<String, Object> get values => Map.unmodifiable(_values);

  String? scalar(String key) {
    final v = _values[key];
    return v is String ? v : null;
  }

  List<String>? list(String key) {
    final v = _values[key];
    if (v is List<String>) return v;
    // 单标量也允许按单元素列表读取（宽容外部工具写法 tags: foo）。
    if (v is String && v.isNotEmpty) return [v];
    return null;
  }

  /// 应用 [updates]（值为 null 表示删除该键）并重组完整文件内容。
  ///
  /// 管理键就地替换保持原行顺序，新键追加在块尾，未涉及的行原样保留。
  /// [body] 缺省沿用解析出的正文。原文没有 front-matter 时等价于
  /// [buildFrontMatter]（此时正文前补一个空行分隔）。
  String serialize({Map<String, Object?> updates = const {}, String? body}) {
    final effectiveBody = body ?? this.body;
    if (!hasFrontMatter) {
      final nonNull = <String, Object>{
        for (final e in updates.entries)
          if (e.value != null) e.key: e.value!,
      };
      return buildFrontMatter(nonNull, effectiveBody);
    }

    final lines = List<String?>.from(_rawLines);
    final appended = <String>[];
    for (final entry in updates.entries) {
      final index = _keyLineIndex[entry.key];
      final value = entry.value;
      if (index != null) {
        lines[index] = value == null ? null : _formatLine(entry.key, value);
      } else if (value != null) {
        appended.add(_formatLine(entry.key, value));
      }
    }

    final buffer = StringBuffer('---\n');
    for (final line in lines) {
      if (line != null) buffer.writeln(line);
    }
    for (final line in appended) {
      buffer.writeln(line);
    }
    buffer.write('---\n');
    buffer.write(effectiveBody);
    return buffer.toString();
  }
}

/// 解析 [raw]。没有（或格式不完整的）front-matter 时返回
/// `hasFrontMatter == false` 且 `body == raw`。
FrontMatterDoc parseFrontMatter(String raw) {
  FrontMatterDoc asPlainBody() => FrontMatterDoc._(
        hasFrontMatter: false,
        values: {},
        body: raw,
        rawLines: const [],
        keyLineIndex: const {},
      );

  // 起始行必须是独占的 `---`（容忍 \r\n）。
  if (!raw.startsWith('---')) return asPlainBody();
  final firstLineEnd = raw.indexOf('\n');
  if (firstLineEnd == -1) return asPlainBody();
  if (raw.substring(0, firstLineEnd).replaceAll('\r', '').trim() != '---') {
    return asPlainBody();
  }

  // 逐行扫描到闭合 `---`。
  final rest = raw.substring(firstLineEnd + 1);
  final rawLines = <String>[];
  var cursor = 0;
  int? bodyStart;
  while (cursor <= rest.length) {
    final nl = rest.indexOf('\n', cursor);
    final lineEnd = nl == -1 ? rest.length : nl;
    var line = rest.substring(cursor, lineEnd);
    if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
    if (line.trim() == '---') {
      bodyStart = nl == -1 ? rest.length : nl + 1;
      break;
    }
    rawLines.add(line);
    if (nl == -1) break;
    cursor = nl + 1;
  }
  if (bodyStart == null) return asPlainBody(); // 无闭合定界符

  final values = <String, Object>{};
  final keyLineIndex = <String, int>{};
  final keyPattern = RegExp(r'^([A-Za-z0-9_-]+):\s(.*)$');
  for (var i = 0; i < rawLines.length; i++) {
    final match = keyPattern.firstMatch(rawLines[i]);
    if (match == null) continue; // 注释/嵌套/续行 → 原样保留
    final key = match.group(1)!;
    if (keyLineIndex.containsKey(key)) continue; // 重复键以首行为准
    final parsed = _parseValue(match.group(2)!.trim());
    if (parsed == null) continue;
    values[key] = parsed;
    keyLineIndex[key] = i;
  }

  return FrontMatterDoc._(
    hasFrontMatter: true,
    values: values,
    body: rest.substring(bodyStart),
    rawLines: rawLines,
    keyLineIndex: keyLineIndex,
  );
}

/// 为不带 front-matter 的正文构造全新块（块与正文间空一行）。
String buildFrontMatter(Map<String, Object> values, String body) {
  final buffer = StringBuffer('---\n');
  for (final entry in values.entries) {
    buffer.writeln(_formatLine(entry.key, entry.value));
  }
  buffer.write('---\n\n');
  buffer.write(body);
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// 值的解析与格式化
// ---------------------------------------------------------------------------

/// 解析行内值：标量或 `[a, b]` 列表。返回 String 或 List&lt;String&gt;；
/// 返回 null 表示无法识别（该行按原样保留）。
Object? _parseValue(String raw) {
  if (raw.isEmpty) return null; // `key:` 空值可能是嵌套块的开头，不解析
  if (raw.startsWith('[')) {
    if (!raw.endsWith(']')) return null;
    final inner = raw.substring(1, raw.length - 1).trim();
    if (inner.isEmpty) return const <String>[];
    return _splitListItems(inner).map(_unquote).toList();
  }
  return _unquote(raw);
}

/// 按不在引号内的逗号切分列表项。
List<String> _splitListItems(String inner) {
  final items = <String>[];
  final current = StringBuffer();
  String? quote;
  for (var i = 0; i < inner.length; i++) {
    final ch = inner[i];
    if (quote != null) {
      current.write(ch);
      if (ch == r'\' && quote == '"' && i + 1 < inner.length) {
        current.write(inner[++i]); // 双引号内的转义对
      } else if (ch == quote) {
        quote = null;
      }
      continue;
    }
    if (ch == '"' || ch == "'") {
      quote = ch;
      current.write(ch);
    } else if (ch == ',') {
      items.add(current.toString().trim());
      current.clear();
    } else {
      current.write(ch);
    }
  }
  final last = current.toString().trim();
  if (last.isNotEmpty || items.isNotEmpty) items.add(last);
  return items;
}

String _unquote(String raw) {
  final s = raw.trim();
  if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
    final inner = s.substring(1, s.length - 1);
    final out = StringBuffer();
    for (var i = 0; i < inner.length; i++) {
      final ch = inner[i];
      if (ch == r'\' && i + 1 < inner.length) {
        out.write(inner[++i]);
      } else {
        out.write(ch);
      }
    }
    return out.toString();
  }
  if (s.length >= 2 && s.startsWith("'") && s.endsWith("'")) {
    // YAML 单引号转义：'' → '
    return s.substring(1, s.length - 1).replaceAll("''", "'");
  }
  return s;
}

String _formatLine(String key, Object value) {
  if (value is List) {
    final items = value.map((e) => _formatScalar(e.toString(), inList: true));
    return '$key: [${items.join(', ')}]';
  }
  return '$key: ${_formatScalar(value.toString(), inList: false)}';
}

/// 含特殊字符时加双引号，保证解析往返一致。
String _formatScalar(String value, {required bool inList}) {
  var needsQuote = value.isEmpty ||
      value != value.trim() ||
      value.contains('\n') ||
      RegExp(r'''[:#"'\[\]{}|>&*!%@`\\]''').hasMatch(value) ||
      value.startsWith('-') ||
      value.startsWith('?');
  if (inList && value.contains(',')) needsQuote = true;
  if (!needsQuote) return value;
  final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}
