class SyncLog {
  final String id;
  final SyncLogType type;
  final String message;
  final DateTime timestamp;

  const SyncLog({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
  });
}

enum SyncLogType { success, error, warning }
