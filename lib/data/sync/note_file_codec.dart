/// Note ↔ 仓库文件表示的编解码（doc/sync-design.md §5.1/§5.3）。
///
/// - Markdown：文件 = YAML front-matter（id/created/updated/category/tags）+ 正文；
///   标题不入 front-matter，标题即文件名（§5.3）。
/// - txt：文件 = 纯正文（路径即身份，不注入任何元数据）。
///
/// 编码必须**确定**（同一笔记状态 → 同一字节序列）：同步判定依赖内容寻址，
/// 时间戳统一序列化为 UTC ISO8601。编码时可传入上一版文件内容作模板，
/// 以保留外部工具（如 Obsidian）写入的未知 front-matter 字段（不变量 I3 延伸）。
library;

import '../../domain/models/note.dart';
import '../../utils/front_matter.dart';

/// 从仓库文件解码出的字段（尚未合成 Note——引擎按判定结果决定
/// 新建还是覆盖已有笔记）。
class DecodedNoteFile {
  const DecodedNoteFile({
    required this.title,
    required this.body,
    required this.format,
    this.id,
    this.created,
    this.updated,
    this.category,
    this.tags = const [],
  });

  /// front-matter id；txt 或无 front-matter 的 md 为 null。
  final String? id;

  /// 展示标题（文件名去扩展名，已剥离路径碰撞的短 id 后缀）。
  final String title;

  /// 不含 front-matter 的正文。
  final String body;

  final NoteFormat format;
  final DateTime? created;
  final DateTime? updated;
  final String? category;
  final List<String> tags;
}

/// 把笔记编码为仓库文件内容。
///
/// [template] 传该笔记上一版的完整文件内容（通常取 base.content）：
/// 有 front-matter 时就地更新管理键、保留未知行；否则构造全新块。
String encodeNoteFile(Note note, {String? template}) {
  if (note.format == NoteFormat.txt) return note.content;

  final updates = <String, Object?>{
    FmKeys.id: note.id,
    FmKeys.created: note.createdAt.toUtc().toIso8601String(),
    FmKeys.updated: note.updatedAt.toUtc().toIso8601String(),
    // 空值键写 null 以从模板中移除，保证编码确定性。
    FmKeys.category: note.category.isEmpty ? null : note.category,
    FmKeys.tags: note.tags.isEmpty ? null : note.tags,
  };

  if (template != null) {
    final parsed = parseFrontMatter(template);
    if (parsed.hasFrontMatter) {
      return parsed.serialize(updates: updates, body: _bodyBlock(note.content));
    }
  }
  final values = <String, Object>{
    for (final e in updates.entries)
      if (e.value != null) e.key: e.value!,
  };
  return buildFrontMatter(values, note.content);
}

/// front-matter 块与正文之间固定空一行（与 buildFrontMatter 一致），
/// 使 serialize 与全新构造产出相同布局。
String _bodyBlock(String body) => '\n$body';

/// 解码仓库文件。[path] 用于推导格式与标题。
DecodedNoteFile decodeNoteFile(String path, String content) {
  final format =
      path.toLowerCase().endsWith('.md') ? NoteFormat.markdown : NoteFormat.txt;

  if (format == NoteFormat.txt) {
    return DecodedNoteFile(
      title: displayTitleFromPath(path),
      body: content,
      format: format,
    );
  }

  final doc = parseFrontMatter(content);
  final id = doc.scalar(FmKeys.id);
  return DecodedNoteFile(
    id: id,
    title: displayTitleFromPath(path, id: id),
    // 剥掉块后固定的一个分隔空行，与 _bodyBlock 对偶。
    body: doc.hasFrontMatter ? _stripLeadingBlankLine(doc.body) : content,
    format: format,
    created: _parseTime(doc.scalar(FmKeys.created)),
    updated: _parseTime(doc.scalar(FmKeys.updated)),
    category: doc.scalar(FmKeys.category),
    tags: doc.list(FmKeys.tags) ?? const [],
  );
}

/// 文件名 → 展示标题：去扩展名；已知 [id] 时剥离路径碰撞产生的
/// `-{id 前 8 位}` / `-{id}` 后缀（§5.3）。
String displayTitleFromPath(String path, {String? id}) {
  final slash = path.lastIndexOf('/');
  var name = slash == -1 ? path : path.substring(slash + 1);
  final dot = name.lastIndexOf('.');
  if (dot > 0) name = name.substring(0, dot);
  if (id != null && id.isNotEmpty) {
    final shortId = id.length > 8 ? id.substring(0, 8) : id;
    for (final suffix in ['-$id', '-$shortId']) {
      if (name.length > suffix.length && name.endsWith(suffix)) {
        return name.substring(0, name.length - suffix.length);
      }
    }
  }
  return name;
}

String _stripLeadingBlankLine(String body) {
  if (body.startsWith('\r\n')) return body.substring(2);
  if (body.startsWith('\n')) return body.substring(1);
  return body;
}

DateTime? _parseTime(String? raw) =>
    raw == null ? null : DateTime.tryParse(raw)?.toLocal();
