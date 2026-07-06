import 'package:casual/data/sync/note_file_codec.dart';
import 'package:casual/domain/models/note.dart';
import 'package:flutter_test/flutter_test.dart';

Note _note({
  String id = 'abcdefgh12345678',
  String title = '会议纪要',
  String content = '# 正文\n第一行\n',
  List<String> tags = const [],
  String category = '未分类',
  NoteFormat format = NoteFormat.markdown,
}) =>
    Note(
      id: id,
      title: title,
      content: content,
      tags: tags,
      category: category,
      format: format,
      createdAt: DateTime.utc(2026, 7, 1, 10),
      updatedAt: DateTime.utc(2026, 7, 3, 12, 30),
    );

void main() {
  group('encodeNoteFile', () {
    test('md：生成 front-matter（id/时间 UTC/分类/标签）+ 空行 + 正文', () {
      final out = encodeNoteFile(_note(tags: ['a', 'b'], category: '工作'));
      expect(out, '---\n'
          'id: abcdefgh12345678\n'
          'created: "2026-07-01T10:00:00.000Z"\n'
          'updated: "2026-07-03T12:30:00.000Z"\n'
          'category: 工作\n'
          'tags: [a, b]\n'
          '---\n'
          '\n'
          '# 正文\n第一行\n');
    });

    test('md：编码是确定的（同一状态两次编码一致）', () {
      final n = _note(tags: ['x']);
      expect(encodeNoteFile(n), encodeNoteFile(n));
    });

    test('md：以 base 内容为模板时保留外来字段', () {
      const template = '---\n'
          'id: abcdefgh12345678\n'
          'aliases: [外部别名]\n'
          'created: "2026-07-01T10:00:00.000Z"\n'
          'updated: "2026-07-01T10:00:00.000Z"\n'
          '---\n'
          '\n'
          '旧正文\n';
      final out = encodeNoteFile(_note(content: '新正文\n'), template: template);
      expect(out, contains('aliases: [外部别名]'));
      expect(out, contains('updated: "2026-07-03T12:30:00.000Z"'));
      expect(out, endsWith('---\n\n新正文\n'));
    });

    test('txt：原样输出正文，不注入任何元数据', () {
      final out = encodeNoteFile(_note(format: NoteFormat.txt, content: '纯文本'));
      expect(out, '纯文本');
    });

    test('encode → decode 往返：正文与元数据一致', () {
      final n = _note(tags: ['a'], category: '工作');
      final decoded = decodeNoteFile('notes/会议纪要.md', encodeNoteFile(n));
      expect(decoded.id, n.id);
      expect(decoded.body, n.content);
      expect(decoded.title, '会议纪要');
      expect(decoded.category, '工作');
      expect(decoded.tags, ['a']);
      expect(decoded.created, DateTime.utc(2026, 7, 1, 10).toLocal());
      expect(decoded.updated, DateTime.utc(2026, 7, 3, 12, 30).toLocal());
    });
  });

  group('decodeNoteFile', () {
    test('无 front-matter 的 md：整体为正文，id 为 null', () {
      final d = decodeNoteFile('notes/外部创建.md', '# 手写文件\n内容');
      expect(d.id, isNull);
      expect(d.body, '# 手写文件\n内容');
      expect(d.title, '外部创建');
      expect(d.format, NoteFormat.markdown);
    });

    test('txt：纯文本正文', () {
      final d = decodeNoteFile('notes/备忘.txt', '一行字');
      expect(d.format, NoteFormat.txt);
      expect(d.body, '一行字');
      expect(d.title, '备忘');
      expect(d.id, isNull);
    });

    test('标题剥离短 id 后缀', () {
      const content = '---\nid: abcdefgh12345678\n---\n\nX';
      expect(
        decodeNoteFile('notes/会议-abcdefgh.md', content).title,
        '会议',
      );
      expect(
        decodeNoteFile('notes/会议-abcdefgh12345678.md', content).title,
        '会议',
      );
      // 无 id 信息时不剥离。
      expect(displayTitleFromPath('notes/会议-abcdefgh.md'), '会议-abcdefgh');
    });
  });
}
