import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';
import '../services/window_service.dart';

/// 关闭主窗口行为的偏好设置（仅 Windows 桌面端使用）。
class WindowCloseActionNotifier extends StateNotifier<WindowCloseAction> {
  WindowCloseActionNotifier(this._storage) : super(WindowCloseAction.ask);

  static const _storageKey = 'gitnote_window_close_action';

  final StorageService _storage;

  Future<void> load() async {
    final value = await _storage.read(_storageKey);
    if (mounted && value != null) {
      state = WindowCloseAction.fromName(value);
    }
  }

  Future<void> setAction(WindowCloseAction action) async {
    state = action;
    await _storage.write(_storageKey, action.name);
  }
}

final windowCloseActionProvider =
    StateNotifierProvider<WindowCloseActionNotifier, WindowCloseAction>((ref) {
  final notifier = WindowCloseActionNotifier(StorageService());
  notifier.load();
  return notifier;
});
