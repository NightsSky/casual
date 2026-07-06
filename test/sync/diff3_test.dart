import 'package:casual/data/sync/diff3.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('diff3Merge（期望结果均与 git merge-file 实测对齐）', () {
    test('双方均未改动 → 原样', () {
      final r = diff3Merge(
        base: ['1', '2', '3'],
        local: ['1', '2', '3'],
        remote: ['1', '2', '3'],
      );
      expect(r.clean, isTrue);
      expect(r.mergedLines, ['1', '2', '3']);
    });

    test('仅本地改动 → 取本地', () {
      final r = diff3Merge(
        base: ['1', '2', '3'],
        local: ['1', 'X', '3'],
        remote: ['1', '2', '3'],
      );
      expect(r.mergedLines, ['1', 'X', '3']);
    });

    test('仅远端改动 → 取远端', () {
      final r = diff3Merge(
        base: ['1', '2', '3'],
        local: ['1', '2', '3'],
        remote: ['1', 'Y', '3'],
      );
      expect(r.mergedLines, ['1', 'Y', '3']);
    });

    test('非重叠改动自动合并（git merge-file 实测 case1）', () {
      final r = diff3Merge(
        base: ['1', '2', '3', '4', '5', '6'],
        local: ['1', 'X', '3', '4', '5', '6'],
        remote: ['1', '2', '3', '4', 'Y', '6'],
      );
      expect(r.clean, isTrue);
      expect(r.mergedLines, ['1', 'X', '3', '4', 'Y', '6']);
    });

    test('本地删行 + 远端改别处 → 自动合并（git 实测 case3）', () {
      final r = diff3Merge(
        base: ['1', '2', '3', '4', '5', '6'],
        local: ['1', '2', '4', '5', '6'],
        remote: ['1', '2', '3', '4', 'Y', '6'],
      );
      expect(r.mergedLines, ['1', '2', '4', 'Y', '6']);
    });

    test('双方相同改动 → 伪冲突，直接采纳', () {
      final r = diff3Merge(
        base: ['1', '2', '3'],
        local: ['1', 'X', '3'],
        remote: ['1', 'X', '3'],
      );
      expect(r.clean, isTrue);
      expect(r.mergedLines, ['1', 'X', '3']);
    });

    test('同一行不同改动 → 冲突块', () {
      final r = diff3Merge(
        base: ['1', '2', '3'],
        local: ['1', 'X', '3'],
        remote: ['1', 'Y', '3'],
      );
      expect(r.clean, isFalse);
      expect(r.blocks, hasLength(3));
      final conflict = r.blocks[1] as ConflictBlock;
      expect(conflict.local, ['X']);
      expect(conflict.base, ['2']);
      expect(conflict.remote, ['Y']);
      expect((r.blocks[0] as OkBlock).lines, ['1']);
      expect((r.blocks[2] as OkBlock).lines, ['3']);
    });

    test('相邻行改动 → 冲突（与 git 语义一致，实测 case2）', () {
      final r = diff3Merge(
        base: ['1', '2', '3', '4', '5'],
        local: ['1', 'X', '3', '4', '5'],
        remote: ['1', '2', 'Y', '4', '5'],
      );
      expect(r.clean, isFalse);
      final conflict = r.blocks[1] as ConflictBlock;
      // git merge-file 输出：<<< X 3 === 2 Y >>>
      expect(conflict.local, ['X', '3']);
      expect(conflict.base, ['2', '3']);
      expect(conflict.remote, ['2', 'Y']);
    });

    test('同位置插入不同内容 → 冲突（git 实测 case4）', () {
      final r = diff3Merge(
        base: ['1', '2'],
        local: ['1', 'A', '2'],
        remote: ['1', 'B', '2'],
      );
      expect(r.clean, isFalse);
      final conflict = r.blocks[1] as ConflictBlock;
      expect(conflict.local, ['A']);
      expect(conflict.base, isEmpty);
      expect(conflict.remote, ['B']);
    });

    test('空 base（无共同祖先）且内容不同 → 冲突', () {
      final r = diff3Merge(
        base: [''],
        local: ['本地内容'],
        remote: ['远端内容'],
      );
      expect(r.clean, isFalse);
    });
  });

  group('mergeText', () {
    test('保留末尾换行的往返', () {
      final merged = mergeTextClean(
        base: '1\n2\n3\n4\n5\n6\n',
        local: '1\nX\n3\n4\n5\n6\n',
        remote: '1\n2\n3\n4\nY\n6\n',
      );
      expect(merged, '1\nX\n3\n4\nY\n6\n');
    });

    test('Markdown 两段落分别编辑 → 自动合并', () {
      const base = '# 标题\n\n第一段。\n\n第二段。\n';
      const local = '# 标题\n\n第一段（本地改）。\n\n第二段。\n';
      const remote = '# 标题\n\n第一段。\n\n第二段（远端改）。\n';
      expect(
        mergeTextClean(base: base, local: local, remote: remote),
        '# 标题\n\n第一段（本地改）。\n\n第二段（远端改）。\n',
      );
    });

    test('冲突时返回 null', () {
      expect(
        mergeTextClean(base: 'a\n', local: 'b\n', remote: 'c\n'),
        isNull,
      );
    });
  });
}
