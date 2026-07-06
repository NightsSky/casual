import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 计算内容的 git blob sha（SHA-1 内容寻址）。
///
/// git 对文件内容的哈希公式：`sha1("blob {字节数}\0" + 内容字节)`。
/// 本地算出的值与 GitHub/Gitee tree/contents API 返回的 blob sha 一致，
/// 因此同步引擎无需下载文件即可判断远端内容是否变化（doc/sync-design.md §6.1）。
///
/// 注意：仅支持 SHA-1 仓库（GitHub/Gitee 现网默认）。SHA-256 仓库极罕见，
/// 若未来需要支持，在 remote 层按仓库对象格式选择哈希算法。
String computeBlobSha(String content) {
  final bytes = utf8.encode(content);
  final header = utf8.encode('blob ${bytes.length}\x00');
  return sha1.convert([...header, ...bytes]).toString();
}
