enum GitPlatform { github, gitee }

class GitConfig {
  final GitPlatform platform;
  final String token;
  final String owner;
  final String repo;
  final String branch;
  final String notesDir;
  final DateTime? lastSyncTime;

  const GitConfig({
    required this.platform,
    required this.token,
    required this.owner,
    required this.repo,
    this.branch = 'main',
    this.notesDir = 'notes',
    this.lastSyncTime,
  });

  bool get isConfigured =>
      token.isNotEmpty && owner.isNotEmpty && repo.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'platform': platform.name,
        'token': token,
        'owner': owner,
        'repo': repo,
        'branch': branch,
        'notesDir': notesDir,
        'lastSyncTime': lastSyncTime?.toIso8601String(),
      };

  factory GitConfig.fromJson(Map<String, dynamic> json) => GitConfig(
        platform: GitPlatform.values.firstWhere(
          (e) => e.name == json['platform'],
          orElse: () => GitPlatform.github,
        ),
        token: json['token'] as String? ?? '',
        owner: json['owner'] as String? ?? '',
        repo: json['repo'] as String? ?? '',
        branch: json['branch'] as String? ?? 'main',
        notesDir: json['notesDir'] as String? ?? 'notes',
        lastSyncTime: json['lastSyncTime'] != null
            ? DateTime.parse(json['lastSyncTime'] as String)
            : null,
      );

  GitConfig copyWith({
    GitPlatform? platform,
    String? token,
    String? owner,
    String? repo,
    String? branch,
    String? notesDir,
    DateTime? lastSyncTime,
  }) =>
      GitConfig(
        platform: platform ?? this.platform,
        token: token ?? this.token,
        owner: owner ?? this.owner,
        repo: repo ?? this.repo,
        branch: branch ?? this.branch,
        notesDir: notesDir ?? this.notesDir,
        lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      );
}
