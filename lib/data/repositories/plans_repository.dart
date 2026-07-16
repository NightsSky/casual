import 'dart:convert';

import '../../domain/models/plan.dart';
import '../services/storage_service.dart';

/// 2026-07-15 16:20:00（北京时间）：负责计划列表的本地 JSON 持久化，不把存储细节暴露给状态管理层。
class PlansRepository {
  static const String _storageKey = 'gitnote_plans';

  final StorageService _storage;

  PlansRepository(this._storage);

  /// 读取全部计划；单条损坏数据会被跳过，避免一个异常计划阻断整个计划页面。
  Future<List<Plan>> loadPlans() async {
    final raw = await _storage.read(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final items = jsonDecode(raw) as List<dynamic>;
      final plans = <Plan>[];
      for (final item in items) {
        try {
          plans.add(Plan.fromJson(Map<String, dynamic>.from(item as Map)));
        } catch (_) {
          // 本地可能残留旧版本或未完整写入的数据，只隔离异常条目，保留其他可用计划。
        }
      }
      return plans;
    } catch (_) {
      return [];
    }
  }

  /// 覆盖保存当前计划快照，状态层每次业务操作完成后统一调用，保证列表与时间轴同步落盘。
  Future<void> savePlans(List<Plan> plans) async {
    final data = plans.map((plan) => plan.toJson()).toList();
    await _storage.write(_storageKey, jsonEncode(data));
  }
}
