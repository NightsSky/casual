/// 同步 base 快照：某篇笔记上次同步成功时双方共识的版本
/// （doc/sync-design.md §4.1/§9.1，不变量 I2：只在达成共识的时刻更新）。
///
/// [key] 的取值约定与判定器一致（§5.1）：Markdown 用 front-matter id，
/// txt 用远端路径。
class NoteSyncBase {
  const NoteSyncBase({
    required this.key,
    required this.path,
    required this.blobSha,
    required this.content,
    required this.syncedAt,
  });

  final String key;

  /// 上次共识时的远端路径（识别重命名的锚点）。
  final String path;

  /// 共识版本的 git blob sha（与远端清单比对判断"远端是否变了"）。
  final String blobSha;

  /// 共识版本全文（三方合并的 base 输入）。
  final String content;

  final DateTime syncedAt;

  Map<String, dynamic> toJson() => {
        'key': key,
        'path': path,
        'blobSha': blobSha,
        'content': content,
        'syncedAt': syncedAt.toUtc().toIso8601String(),
      };

  factory NoteSyncBase.fromJson(Map<String, dynamic> json) => NoteSyncBase(
        key: json['key'] as String,
        path: json['path'] as String,
        blobSha: json['blobSha'] as String,
        content: json['content'] as String? ?? '',
        syncedAt: DateTime.tryParse(json['syncedAt'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
      );
}
