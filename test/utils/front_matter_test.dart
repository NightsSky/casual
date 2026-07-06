import 'package:casual/utils/front_matter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseFrontMatter', () {
    test('标准块：标量与列表', () {
      const raw = '---\n'
          'id: 550e8400e29b41d4\n'
          'created: 2026-07-03T10:00:00+08:00\n'
          'category: 工作\n'
          'tags: [flutter, sync]\n'
          '---\n'
          '\n'
          '# 标题\n正文\n';
      final doc = parseFrontMatter(raw);
      expect(doc.hasFrontMatter, isTrue);
      expect(doc.scalar(FmKeys.id), '550e8400e29b41d4');
      expect(doc.scalar(FmKeys.created), '2026-07-03T10:00:00+08:00');
      expect(doc.scalar(FmKeys.category), '工作');
      expect(doc.list(FmKeys.tags), ['flutter', 'sync']);
      expect(doc.body, '\n# 标题\n正文\n');
    });

    test('无 front-matter：整体视为正文', () {
      const raw = '# 只是正文\n--- 中间的分隔线\n';
      final doc = parseFrontMatter(raw);
      expect(doc.hasFrontMatter, isFalse);
      expect(doc.body, raw);
      expect(doc.values, isEmpty);
    });

    test('只有起始定界符没有闭合：整体视为正文', () {
      const raw = '---\nid: abc\n没有闭合\n';
      final doc = parseFrontMatter(raw);
      expect(doc.hasFrontMatter, isFalse);
      expect(doc.body, raw);
    });

    test('容忍 CRLF', () {
      const raw = '---\r\nid: abc\r\ntags: [a, b]\r\n---\r\n\r\n正文';
      final doc = parseFrontMatter(raw);
      expect(doc.hasFrontMatter, isTrue);
      expect(doc.scalar('id'), 'abc');
      expect(doc.list('tags'), ['a', 'b']);
      // 正文原样保留（包括其 CRLF 与前导空行）。
      expect(doc.body, '\r\n正文');
    });

    test('引号标量与转义', () {
      const raw = '---\n'
          'category: "带: 冒号 #井号 \\"引号\\""\n'
          "note: 'it''s'\n"
          '---\n正文';
      final doc = parseFrontMatter(raw);
      expect(doc.scalar('category'), '带: 冒号 #井号 "引号"');
      expect(doc.scalar('note'), "it's");
    });

    test('列表项支持引号与内嵌逗号', () {
      const raw = '---\ntags: ["a, b", c, \'d\']\n---\n';
      final doc = parseFrontMatter(raw);
      expect(doc.list('tags'), ['a, b', 'c', 'd']);
    });

    test('空列表', () {
      const raw = '---\ntags: []\n---\n';
      expect(parseFrontMatter(raw).list('tags'), isEmpty);
    });

    test('单标量可按单元素列表读取', () {
      const raw = '---\ntags: solo\n---\n';
      expect(parseFrontMatter(raw).list('tags'), ['solo']);
    });

    test('无法识别的行不进入 values', () {
      const raw = '---\n'
          'id: abc\n'
          '# 注释行\n'
          'nested:\n'
          '  - block item\n'
          '---\n';
      final doc = parseFrontMatter(raw);
      expect(doc.values.keys, ['id']);
    });
  });

  group('serialize', () {
    test('无改动时往返无损（含外来行与正文前导空行）', () {
      const raw = '---\n'
          'id: abc\n'
          'aliases: [外部工具写入]\n'
          '# obsidian 注释\n'
          'cssclass: wide\n'
          '---\n'
          '\n'
          '正文第一行\n';
      final doc = parseFrontMatter(raw);
      expect(doc.serialize(), raw);
    });

    test('就地更新管理键，保持行序与外来行', () {
      const raw = '---\n'
          'id: abc\n'
          '# 注释\n'
          'category: 旧分类\n'
          '---\n正文';
      final doc = parseFrontMatter(raw);
      final out = doc.serialize(updates: {FmKeys.category: '新分类'});
      expect(out, '---\nid: abc\n# 注释\ncategory: 新分类\n---\n正文');
    });

    test('新增键追加在块尾', () {
      const raw = '---\nid: abc\n---\n正文';
      final doc = parseFrontMatter(raw);
      final out = doc.serialize(updates: {
        FmKeys.tags: ['a', 'b'],
      });
      expect(out, '---\nid: abc\ntags: [a, b]\n---\n正文');
    });

    test('null 删除键', () {
      const raw = '---\nid: abc\ncategory: 工作\n---\n正文';
      final doc = parseFrontMatter(raw);
      final out = doc.serialize(updates: {FmKeys.category: null});
      expect(out, '---\nid: abc\n---\n正文');
    });

    test('替换正文', () {
      const raw = '---\nid: abc\n---\n\n旧正文';
      final doc = parseFrontMatter(raw);
      expect(doc.serialize(body: '\n新正文'), '---\nid: abc\n---\n\n新正文');
    });

    test('原文无 front-matter 时等价于注入新块', () {
      final doc = parseFrontMatter('正文而已\n');
      final out = doc.serialize(updates: {FmKeys.id: 'abc'});
      expect(out, '---\nid: abc\n---\n\n正文而已\n');
    });

    test('特殊字符标量自动加引号且可往返', () {
      final out = buildFrontMatter({'category': 'a: b #c "d"'}, '正文');
      final back = parseFrontMatter(out);
      expect(back.scalar('category'), 'a: b #c "d"');
    });

    test('含逗号的列表项自动加引号且可往返', () {
      final out = buildFrontMatter({
        'tags': ['a, b', 'c'],
      }, '');
      expect(parseFrontMatter(out).list('tags'), ['a, b', 'c']);
    });
  });

  group('buildFrontMatter', () {
    test('生成标准块，块后空一行', () {
      final out = buildFrontMatter({
        FmKeys.id: 'abc',
        FmKeys.tags: ['x'],
      }, '# 正文\n');
      expect(out, '---\nid: abc\ntags: [x]\n---\n\n# 正文\n');
    });
  });
}
