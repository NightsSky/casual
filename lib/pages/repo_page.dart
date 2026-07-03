import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/notes_provider.dart';
import '../providers/git_provider.dart';
import '../theme/constants.dart';
import '../ui/core/extensions/build_context_l10n.dart';
import '../utils/common_utils.dart';

class RepoPage extends ConsumerWidget {
  const RepoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gitState = ref.watch(gitProvider);
    final notesState = ref.watch(notesProvider);
    final isDesktop = getScreenType(context) == ScreenType.desktop;

    final localCount =
        notesState.notes.where((n) => n.syncStatus == SyncStatus.local).length;
    final syncedCount =
        notesState.notes.where((n) => n.syncStatus == SyncStatus.synced).length;
    final conflictCount = notesState.notes
        .where((n) => n.syncStatus == SyncStatus.conflict)
        .length;

    return Column(
      children: [
        _buildHeader(context, ref, gitState, isDesktop),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _buildStatusCard(context, gitState),
              const SizedBox(height: AppSpacing.xl),
              _buildSectionTitle(context.l10n.quickActions),
              const SizedBox(height: AppSpacing.sm),
              _buildActionGrid(context, ref, gitState),
              const SizedBox(height: AppSpacing.xl),
              _buildSectionTitle(context.l10n.syncStats),
              const SizedBox(height: AppSpacing.sm),
              _buildStatsGrid(context, localCount, syncedCount, conflictCount,
                  notesState.notesCount),
              const SizedBox(height: AppSpacing.xl),
              _buildSectionTitle(context.l10n.syncLogs),
              const SizedBox(height: AppSpacing.sm),
              _buildSyncLogs(context, gitState),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
      BuildContext context, WidgetRef ref, GitState gitState, bool isDesktop) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        isDesktop
            ? AppSpacing.md
            : MediaQuery.of(context).padding.top + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(context.l10n.repositoryManagement,
                style: const TextStyle(
                    fontSize: AppFontSize.xxl, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              if (gitState.config.isConfigured) {
                ref.read(gitProvider.notifier).testConnection();
              }
            },
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, GitState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: state.connected
                    ? AppColors.success
                    : AppColors.textPlaceholder,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.connected
                        ? context.l10n.connected
                        : context.l10n.notConnected,
                    style: const TextStyle(
                        fontSize: AppFontSize.lg, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    state.config.isConfigured
                        ? '${state.config.platform.name}/${state.config.owner}/${state.config.repo}'
                        : context.l10n.configureGitPlatformInSettings,
                    style: const TextStyle(
                        fontSize: AppFontSize.sm,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding:
          const EdgeInsets.only(left: AppSpacing.md, bottom: AppSpacing.sm),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: AppFontSize.sm,
          fontWeight: FontWeight.w600,
          color: AppColors.textPlaceholder,
        ),
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, WidgetRef ref, GitState state) {
    final actions = [
      _ActionData(Icons.download, context.l10n.pullRemote,
          () => _pullFromRemote(ref, context)),
      _ActionData(Icons.upload, context.l10n.pushLocal,
          () => _pushToRemote(ref, context)),
      _ActionData(
          Icons.sync, context.l10n.fullSync, () => _fullSync(ref, context)),
      _ActionData(Icons.settings, context.l10n.repositorySettings, () {}),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      children: actions
          .map((action) => Card(
                child: InkWell(
                  onTap: action.onTap,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(action.icon, size: 32, color: AppColors.primary),
                      const SizedBox(height: AppSpacing.sm),
                      Text(action.label,
                          style: const TextStyle(
                              fontSize: AppFontSize.sm,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildStatsGrid(
      BuildContext context, int local, int synced, int conflict, int total) {
    final items = [
      _StatData(total.toString(), context.l10n.totalNotes),
      _StatData(local.toString(), context.l10n.unsyncedNotes),
      _StatData(synced.toString(), context.l10n.syncedNotes),
      _StatData(conflict.toString(), context.l10n.conflicts),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      children: items
          .map((item) => Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(item.value,
                              style: const TextStyle(
                                  fontSize: AppFontSize.xxl,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(item.label,
                              style: const TextStyle(
                                  fontSize: AppFontSize.sm,
                                  color: AppColors.textPlaceholder)),
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildSyncLogs(BuildContext context, GitState state) {
    if (state.syncLogs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: Center(child: _NoLogsText()),
        ),
      );
    }

    return Column(
      children: state.syncLogs
          .map((log) => Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _logColor(log.type),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log.message,
                                style: const TextStyle(
                                    fontSize: AppFontSize.base)),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                                formatTime(log.timestamp,
                                    locale: Localizations.localeOf(context)
                                        .languageCode),
                                style: const TextStyle(
                                    fontSize: AppFontSize.xs,
                                    color: AppColors.textPlaceholder)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Color _logColor(SyncLogType type) {
    switch (type) {
      case SyncLogType.success:
        return AppColors.success;
      case SyncLogType.error:
        return AppColors.error;
      case SyncLogType.warning:
        return AppColors.warning;
    }
  }

  Future<void> _pullFromRemote(WidgetRef ref, BuildContext context) async {
    final gitNotifier = ref.read(gitProvider.notifier);
    final notesNotifier = ref.read(notesProvider.notifier);
    final pulledRemoteNotes = context.l10n.pulledRemoteNotes;
    final syncFailedMessage = context.l10n.syncFailedMessage;

    if (!ref.read(gitProvider).config.isConfigured) {
      return;
    }

    try {
      final remoteNotes = await gitNotifier.pullNotes();
      for (final note in remoteNotes) {
        notesNotifier.importNote(note);
      }
      gitNotifier.addSyncLog(
          SyncLogType.success, pulledRemoteNotes(remoteNotes.length));
    } catch (e) {
      gitNotifier.addSyncLog(
          SyncLogType.error, syncFailedMessage(e.toString()));
    }
  }

  Future<void> _pushToRemote(WidgetRef ref, BuildContext context) async {
    final gitNotifier = ref.read(gitProvider.notifier);
    final notesNotifier = ref.read(notesProvider.notifier);
    final notesState = ref.read(notesProvider);
    final pushSummary = context.l10n.pushSummary;

    if (!ref.read(gitProvider).config.isConfigured) return;

    final unsynced = notesState.notes
        .where((n) => n.syncStatus == SyncStatus.local)
        .toList();
    if (unsynced.isEmpty) return;

    int successCount = 0;
    for (final note in unsynced) {
      try {
        final result = await gitNotifier.pushNote(note);
        if (result != null) {
          notesNotifier.markSynced(note.id, result['filePath'] as String,
              sha: result['sha'] as String?);
          successCount++;
        }
      } catch (_) {}
    }

    gitNotifier.addSyncLog(
        SyncLogType.success, pushSummary(successCount, unsynced.length));
  }

  Future<void> _fullSync(WidgetRef ref, BuildContext context) async {
    final gitNotifier = ref.read(gitProvider.notifier);
    final notesNotifier = ref.read(notesProvider.notifier);
    final fullSyncSummary = context.l10n.fullSyncSummary;
    final syncFailedMessage = context.l10n.syncFailedMessage;

    if (!ref.read(gitProvider).config.isConfigured) return;

    try {
      final remoteNotes = await gitNotifier.fullSync();
      for (final note in remoteNotes) {
        notesNotifier.importNote(note);
      }
      gitNotifier.addSyncLog(
          SyncLogType.success, fullSyncSummary(remoteNotes.length));
    } catch (e) {
      gitNotifier.addSyncLog(
          SyncLogType.error, syncFailedMessage(e.toString()));
    }
  }
}

class _NoLogsText extends StatelessWidget {
  const _NoLogsText();

  @override
  Widget build(BuildContext context) {
    return Text(context.l10n.noSyncLogs,
        style: const TextStyle(color: AppColors.textPlaceholder));
  }
}

class _ActionData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionData(this.icon, this.label, this.onTap);
}

class _StatData {
  final String value;
  final String label;
  const _StatData(this.value, this.label);
}
