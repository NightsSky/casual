import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/note_sync_base.dart';

/// base 快照表的持久化（doc/sync-design.md §9.2）。
///
/// 与笔记表分开存储（key `gitnote_sync_base`），清空 base 等价于
/// "忘记同步历史"，下轮同步按迁移路径重新对齐，不影响笔记数据本身。
class SyncBaseStore {
  static const _key = 'gitnote_sync_base';

  Future<List<NoteSyncBase>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => NoteSyncBase.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      // 损坏的 base 表按空表处理：同步引擎会走"合成 base"路径重新对齐，
      // 不丢笔记数据（doc/sync-design.md §12 回滚安全）。
      return [];
    }
  }

  Future<void> saveAll(List<NoteSyncBase> bases) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(bases.map((b) => b.toJson()).toList()),
    );
  }
}
