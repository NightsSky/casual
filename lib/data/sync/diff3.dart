/// 三方行级合并（doc/sync-design.md §7.1）。
///
/// 算法移植自 node-diff3（MIT，https://github.com/bhousel/node-diff3）：
/// Hunt–Szymanski LCS → 双侧 hunk → 重叠区域归并。与 git merge-file 的
/// 判定语义一致：双方改动落在互不重叠（且不相邻）的行区块时自动合并，
/// 重叠或相邻的改动产生冲突块；双方做出完全相同的改动不算冲突。
///
/// 选行级而非字符级（diff-match-patch）的理由见设计文档 §7.1：
/// 行级结果更可预测，Markdown 以行为自然编辑单元。
library;

/// 合并输出块：连续的已合并行，或一个冲突块。
sealed class MergeBlock {
  const MergeBlock();
}

class OkBlock extends MergeBlock {
  const OkBlock(this.lines);

  final List<String> lines;
}

class ConflictBlock extends MergeBlock {
  const ConflictBlock({
    required this.local,
    required this.base,
    required this.remote,
  });

  final List<String> local;
  final List<String> base;
  final List<String> remote;
}

class MergeResult {
  const MergeResult(this.blocks);

  final List<MergeBlock> blocks;

  bool get clean => blocks.every((b) => b is OkBlock);

  /// 干净合并时的全部行；有冲突时为 null。
  List<String>? get mergedLines {
    if (!clean) return null;
    return [for (final b in blocks.cast<OkBlock>()) ...b.lines];
  }
}

/// 对整段文本做三方合并。按 `\n` 切分（尾行为空串表示末尾换行，
/// join 后无损还原），CRLF 文本的 `\r` 留在行尾参与比较，不做归一化。
MergeResult mergeText({
  required String base,
  required String local,
  required String remote,
}) {
  return diff3Merge(
    base: base.split('\n'),
    local: local.split('\n'),
    remote: remote.split('\n'),
  );
}

/// 干净时返回合并后的全文，冲突时返回 null。
String? mergeTextClean({
  required String base,
  required String local,
  required String remote,
}) {
  return mergeText(base: base, local: local, remote: remote)
      .mergedLines
      ?.join('\n');
}

/// 行级三方合并。
MergeResult diff3Merge({
  required List<String> base,
  required List<String> local,
  required List<String> remote,
}) {
  final regions = _diff3MergeRegions(local, base, remote);
  final blocks = <MergeBlock>[];
  var okBuffer = <String>[];

  void flushOk() {
    if (okBuffer.isNotEmpty) {
      blocks.add(OkBlock(okBuffer));
      okBuffer = <String>[];
    }
  }

  for (final region in regions) {
    if (region is _StableRegion) {
      okBuffer.addAll(region.content);
    } else if (region is _UnstableRegion) {
      // 双方改动内容一致 → 伪冲突，直接采纳。
      if (_listEquals(region.aContent, region.bContent)) {
        okBuffer.addAll(region.aContent);
      } else {
        flushOk();
        blocks.add(ConflictBlock(
          local: region.aContent,
          base: region.oContent,
          remote: region.bContent,
        ));
      }
    }
  }
  flushOk();
  return MergeResult(blocks);
}

// ---------------------------------------------------------------------------
// 内部：LCS 与区域划分（对应 node-diff3 的 LCS/diffIndices/diff3MergeRegions）
// ---------------------------------------------------------------------------

class _LcsCandidate {
  const _LcsCandidate(this.aIndex, this.bIndex, this.chain);

  final int aIndex;
  final int bIndex;
  final _LcsCandidate? chain;
}

_LcsCandidate _lcs(List<String> a, List<String> b) {
  final equivalenceClasses = <String, List<int>>{};
  for (var j = 0; j < b.length; j++) {
    equivalenceClasses.putIfAbsent(b[j], () => <int>[]).add(j);
  }

  const nullResult = _LcsCandidate(-1, -1, null);
  final candidates = <_LcsCandidate>[nullResult];

  for (var i = 0; i < a.length; i++) {
    final indices = equivalenceClasses[a[i]] ?? const <int>[];
    var r = 0;
    var c = candidates[0];

    for (final j in indices) {
      int s;
      for (s = r; s < candidates.length; s++) {
        if (candidates[s].bIndex < j &&
            (s == candidates.length - 1 || candidates[s + 1].bIndex > j)) {
          break;
        }
      }
      if (s < candidates.length) {
        final newCandidate = _LcsCandidate(i, j, candidates[s]);
        if (r == candidates.length) {
          candidates.add(c);
        } else {
          candidates[r] = c;
        }
        r = s + 1;
        c = newCandidate;
        if (r == candidates.length) break;
      }
    }
    if (r == candidates.length) {
      candidates.add(c);
    } else {
      candidates[r] = c;
    }
  }
  return candidates.last;
}

/// 一处差异：buffer1（旧）区间被 buffer2（新）区间替换。
class _DiffHunk {
  const _DiffHunk({
    required this.b1Start,
    required this.b1Length,
    required this.b2Start,
    required this.b2Length,
  });

  final int b1Start;
  final int b1Length;
  final int b2Start;
  final int b2Length;
}

List<_DiffHunk> _diffIndices(List<String> buffer1, List<String> buffer2) {
  final result = <_DiffHunk>[];
  var tail1 = buffer1.length;
  var tail2 = buffer2.length;

  for (_LcsCandidate? candidate = _lcs(buffer1, buffer2);
      candidate != null;
      candidate = candidate.chain) {
    final mismatchLength1 = tail1 - candidate.aIndex - 1;
    final mismatchLength2 = tail2 - candidate.bIndex - 1;
    tail1 = candidate.aIndex;
    tail2 = candidate.bIndex;
    if (mismatchLength1 > 0 || mismatchLength2 > 0) {
      result.add(_DiffHunk(
        b1Start: tail1 + 1,
        b1Length: mismatchLength1,
        b2Start: tail2 + 1,
        b2Length: mismatchLength2,
      ));
    }
  }
  return result.reversed.toList();
}

/// hunk：某一侧（a=local / b=remote）相对 o（base）的一处差异。
class _SideHunk {
  const _SideHunk({
    required this.isA,
    required this.oStart,
    required this.oLength,
    required this.abStart,
    required this.abLength,
  });

  final bool isA;
  final int oStart;
  final int oLength;
  final int abStart;
  final int abLength;
}

sealed class _Region {
  const _Region();
}

class _StableRegion extends _Region {
  const _StableRegion(this.content);

  final List<String> content;
}

class _UnstableRegion extends _Region {
  const _UnstableRegion({
    required this.aContent,
    required this.oContent,
    required this.bContent,
  });

  final List<String> aContent;
  final List<String> oContent;
  final List<String> bContent;
}

List<_Region> _diff3MergeRegions(List<String> a, List<String> o, List<String> b) {
  final hunks = <_SideHunk>[
    for (final h in _diffIndices(o, a))
      _SideHunk(
        isA: true,
        oStart: h.b1Start,
        oLength: h.b1Length,
        abStart: h.b2Start,
        abLength: h.b2Length,
      ),
    for (final h in _diffIndices(o, b))
      _SideHunk(
        isA: false,
        oStart: h.b1Start,
        oLength: h.b1Length,
        abStart: h.b2Start,
        abLength: h.b2Length,
      ),
  ];
  // Dart 的 sort 不稳定，补足次级排序键保证确定性输出。
  hunks.sort((x, y) {
    final byStart = x.oStart.compareTo(y.oStart);
    if (byStart != 0) return byStart;
    if (x.isA != y.isA) return x.isA ? -1 : 1;
    return x.abStart.compareTo(y.abStart);
  });

  final results = <_Region>[];
  var currOffset = 0;

  void advanceTo(int endOffset) {
    if (endOffset > currOffset) {
      results.add(_StableRegion(o.sublist(currOffset, endOffset)));
      currOffset = endOffset;
    }
  }

  var index = 0;
  while (index < hunks.length) {
    var hunk = hunks[index++];
    final regionStart = hunk.oStart;
    var regionEnd = hunk.oStart + hunk.oLength;
    final regionHunks = <_SideHunk>[hunk];
    advanceTo(regionStart);

    // 吸收与当前区域重叠（含相邻）的后续 hunk。
    while (index < hunks.length) {
      final nextHunk = hunks[index];
      if (nextHunk.oStart > regionEnd) break;
      regionEnd = regionEnd > nextHunk.oStart + nextHunk.oLength
          ? regionEnd
          : nextHunk.oStart + nextHunk.oLength;
      regionHunks.add(nextHunk);
      index++;
    }

    if (regionHunks.length == 1) {
      // 只有一侧动了这段 → 无冲突，直接取该侧内容。
      if (hunk.abLength > 0) {
        final buffer = hunk.isA ? a : b;
        results.add(_StableRegion(
          buffer.sublist(hunk.abStart, hunk.abStart + hunk.abLength),
        ));
      }
    } else {
      // 双侧都动了 → 计算各侧覆盖范围（按 o 区间的偏移校正两端），产出冲突区域。
      // 注：区域含 ≥2 个 hunk 时必然双侧都在（同侧 hunk 之间至少隔一行公共行，
      // 只有对侧 hunk 才能把它们桥接进同一区域），因此两侧 bounds 均有效。
      final aBounds = [a.length, -1, o.length, -1];
      final bBounds = [b.length, -1, o.length, -1];
      for (final h in regionHunks) {
        final oEnd = h.oStart + h.oLength;
        final abEnd = h.abStart + h.abLength;
        final bounds = h.isA ? aBounds : bBounds;
        bounds[0] = bounds[0] < h.abStart ? bounds[0] : h.abStart;
        bounds[1] = bounds[1] > abEnd ? bounds[1] : abEnd;
        bounds[2] = bounds[2] < h.oStart ? bounds[2] : h.oStart;
        bounds[3] = bounds[3] > oEnd ? bounds[3] : oEnd;
      }

      final aStart = aBounds[0] + (regionStart - aBounds[2]);
      final aEnd = aBounds[1] + (regionEnd - aBounds[3]);
      final bStart = bBounds[0] + (regionStart - bBounds[2]);
      final bEnd = bBounds[1] + (regionEnd - bBounds[3]);

      results.add(_UnstableRegion(
        aContent: a.sublist(aStart, aEnd),
        oContent: o.sublist(regionStart, regionEnd),
        bContent: b.sublist(bStart, bEnd),
      ));
    }
    currOffset = regionEnd;
  }

  advanceTo(o.length);
  return results;
}

bool _listEquals(List<String> x, List<String> y) {
  if (x.length != y.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i]) return false;
  }
  return true;
}
