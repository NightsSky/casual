import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import '../services/gitee_service.dart';
import '../services/github_service.dart';

final gitHubServiceProvider = Provider<GitHubService>((ref) {
  return GitHubService();
});

final giteeServiceProvider = Provider<GiteeService>((ref) {
  return GiteeService();
});

final gitSyncRepositoryProvider = Provider<GitSyncRepository>((ref) {
  return GitSyncRepository(
    gitHubService: ref.watch(gitHubServiceProvider),
    giteeService: ref.watch(giteeServiceProvider),
  );
});

/// 连接测试仓储。
///
/// 笔记的拉取/推送/删除自 v2 起由 [SyncEngine]（`lib/data/sync/`）经
/// [RemoteRepo] 抽象承担，本类只保留配置校验用的连通性测试。
class GitSyncRepository {
  const GitSyncRepository({
    required GitHubService gitHubService,
    required GiteeService giteeService,
  })  : _gitHubService = gitHubService,
        _giteeService = giteeService;

  final GitHubService _gitHubService;
  final GiteeService _giteeService;

  Future<bool> testConnection(GitConfig config) {
    if (config.platform == GitPlatform.github) {
      return _gitHubService.testConnection(config.token);
    }
    return _giteeService.testConnection(config.token);
  }
}
