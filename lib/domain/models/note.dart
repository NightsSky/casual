enum SyncStatus { local, synced, conflict, syncing }

enum NoteFormat { txt, markdown }

class Note {
  final String id;
  String title;
  String content;
  List<String> tags;
  String category;
  NoteFormat format;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? syncedAt;
  SyncStatus syncStatus;
  String? filePath;
  String? sha;

  Note({
    required this.id,
    required this.title,
    this.content = '',
    this.tags = const [],
    this.category = '未分类',
    this.format = NoteFormat.txt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncedAt,
    this.syncStatus = SyncStatus.local,
    this.filePath,
    this.sha,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'tags': tags,
        'category': category,
        'format': format.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'syncedAt': syncedAt?.toIso8601String(),
        'syncStatus': syncStatus.name,
        'filePath': filePath,
        'sha': sha,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String? ?? '',
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        category: json['category'] as String? ?? '未分类',
        format: NoteFormat.values.firstWhere(
          (e) => e.name == json['format'],
          orElse: () => NoteFormat.txt,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        syncedAt: json['syncedAt'] != null
            ? DateTime.parse(json['syncedAt'] as String)
            : null,
        syncStatus: SyncStatus.values.firstWhere(
          (e) => e.name == json['syncStatus'],
          orElse: () => SyncStatus.local,
        ),
        filePath: json['filePath'] as String?,
        sha: json['sha'] as String?,
      );

  Note copyWith({
    String? id,
    String? title,
    String? content,
    List<String>? tags,
    String? category,
    NoteFormat? format,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
    SyncStatus? syncStatus,
    String? filePath,
    String? sha,
  }) =>
      Note(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        tags: tags ?? this.tags,
        category: category ?? this.category,
        format: format ?? this.format,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncedAt: syncedAt ?? this.syncedAt,
        syncStatus: syncStatus ?? this.syncStatus,
        filePath: filePath ?? this.filePath,
        sha: sha ?? this.sha,
      );
}
