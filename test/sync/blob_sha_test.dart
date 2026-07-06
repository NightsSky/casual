import 'package:casual/data/sync/blob_sha.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeBlobSha', () {
    // 期望值全部来自本机 `git hash-object --stdin` 实测，是 git 的权威结果。
    test('空内容', () {
      expect(computeBlobSha(''), 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391');
    });

    test('ASCII 带换行', () {
      expect(
        computeBlobSha('hello\n'),
        'ce013625030ba8dba906f756967f9e9ca394464a',
      );
      expect(
        computeBlobSha('test content\n'),
        'd670460b4b4aece5915caf5c68d12f560a9fe3e4',
      );
    });

    test('UTF-8 多字节内容按字节数计长', () {
      expect(
        computeBlobSha('你好，世界'),
        'd007ecca291018bacc0b88277c030983cc3fa5b1',
      );
    });

    test('front-matter 文档', () {
      expect(
        computeBlobSha('---\nid: abc\n---\n\n# 标题\n正文\n'),
        'c42281f1feb0b5fc5d408ad64fe90e9d52a04946',
      );
    });

    test('内容不同则 sha 不同', () {
      expect(computeBlobSha('a'), isNot(computeBlobSha('b')));
    });
  });
}
