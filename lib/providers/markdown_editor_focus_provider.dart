import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 控制主笔记编辑器是否进入专注视图。
///
/// 专注视图只影响当前编辑路由的布局：隐藏应用侧栏和笔记列表，
/// 让 Markdown 的编辑、分屏或预览区域占满应用内容区。
final markdownEditorFocusProvider = StateProvider<bool>((ref) => false);
