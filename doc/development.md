# 开发指南

## 环境要求

- **Flutter SDK**: >= 3.5.0
- **Dart SDK**: >= 3.5.0
- **IDE**: VS Code / Android Studio / IntelliJ IDEA

## 安装依赖

```bash
flutter pub get
```

## 运行项目

### 桌面端（Windows）

```bash
flutter run -d windows
```

### 移动端（Android）

```bash
flutter run -d android
```

### Web 端

```bash
flutter run -d chrome
```

## 项目配置

### 国际化

修改翻译后需重新生成：

```bash
flutter gen-l10n
```

配置文件：
- `l10n.yaml` - 国际化配置
- `lib/l10n/app_zh.arb` - 中文翻译
- `lib/l10n/app_en.arb` - 英文翻译

生成的文件位置：`lib/l10n/generated/`

### 状态管理（Riverpod）

使用 Riverpod 的代码生成功能：

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

监听模式（自动重新生成）：

```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

## 项目结构说明

```
lib/
├── main.dart                 # 应用入口
│   ├── GoRouter 配置
│   ├── MaterialApp 配置
│   └── AppBootstrapGate 初始化（笔记缓存、Git 配置、提醒调度）
│
├── layout/                   # 布局
│   └── app_shell.dart       # 应用外壳（侧边/底部导航）
│
├── pages/                    # 页面
│   ├── notes_page.dart      # 笔记列表
│   ├── editor_page.dart     # 编辑器
│   ├── reminder_page.dart   # 定时提醒
│   ├── repo_page.dart       # 仓库管理
│   ├── settings_page.dart   # 设置
│   ├── token_help_page.dart # Token 获取帮助
│   └── search_page.dart     # 搜索（遗留代码，已被助手功能取代）
│
├── providers/                # 状态管理
│   ├── notes_provider.dart  # 笔记状态
│   ├── git_provider.dart    # Git 状态
│   ├── search_provider.dart # 搜索状态
│   └── reminder_provider.dart # 提醒状态
│
├── services/                 # 应用服务
│   └── reminder_service.dart # 提醒调度（跨平台通知）
│
├── data/                     # 数据层
│   ├── services/            # 数据服务
│   └── repositories/        # 仓储层
│
├── domain/                   # 领域模型
│   └── models/              # 数据模型
│
├── ui/                       # 视图模型与 UI 扩展
│   ├── core/extensions/     # 国际化扩展等
│   └── features/            # 各功能 view_models
│
├── theme/                    # 主题
│   ├── app_theme.dart       # 主题配置
│   └── constants.dart       # 设计常量
│
├── l10n/                     # 国际化（.arb 与生成文件）
│
└── utils/                    # 工具类
    ├── common_utils.dart    # 通用工具
    └── markdown_utils.dart  # Markdown 处理
```

## 调试技巧

### 1. 查看状态变化

使用 Riverpod DevTools：

```dart
// 在 main.dart 中添加
ProviderScope(
  observers: [ProviderLogger()],
  child: GitNoteApp(),
);
```

### 2. 网络请求日志

在 `github_service.dart` 中添加日志：

```dart
import 'package:flutter/foundation.dart';

Future<void> someMethod() async {
  debugPrint('Request: $url');
  final response = await http.get(url);
  debugPrint('Response: ${response.statusCode}');
}
```

### 3. 清除本地数据

```dart
// 在应用中执行
final prefs = await SharedPreferences.getInstance();
await prefs.clear();
```

或手动清除：
- Windows: `%APPDATA%\Roaming\com.example\gitnote_flutter\shared_preferences.json`
- Android: `/data/data/com.example.gitnote_flutter/shared_prefs/`

## 常见问题

### 1. 国际化文件未生成

**问题**: 修改 `.arb` 文件后没有生效

**解决方案**:
```bash
flutter clean
flutter pub get
flutter gen-l10n
```

### 2. Riverpod Provider 未找到

**问题**: `ProviderNotFoundException` 或类型错误

**解决方案**:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. 路由跳转失败

**问题**: `GoRouter` 路由未定义或参数错误

**检查**:
- 确认路由已在 `main.dart` 中注册
- 确认路径参数正确（如 `/notes/:noteId`）
- 使用 `context.go()` 而非 `Navigator.push()`

### 4. Git 同步失败

**常见原因**:
- Token 无效或已过期
- 仓库名/分支名配置错误
- 网络连接问题
- API 权限不足

**调试步骤**:
1. 检查 Token 是否有效：访问 GitHub/Gitee 设置页面
2. 检查网络：使用浏览器访问 `https://api.github.com/user`
3. 查看控制台日志获取详细错误信息

### 5. 定时提醒不触发

**排查步骤**（按顺序检查）:

1. **应用是否在运行**：Windows 端提醒依赖应用内 Timer（5 秒轮询），应用完全退出后不会触发。Android/iOS/Linux 端使用系统通知调度，应用退到后台仍可触发，但被用户强杀或被部分 ROM 后台管控时可能被系统拦截。
2. **提醒是否处于启用状态**：提醒页中对应条目的开关需为打开状态。
3. **是否为历史遗留的过期单次提醒**：现版本新建单次提醒默认下一分钟；选择当前分钟会调度到当前时间后 10 秒；更早时间会自动顺延到明天同一时间（`Reminder.rescheduledIfExpired()`）。修复前创建、一直未操作过的过期单次提醒不会补发，重新保存或开关一次即可。
4. **Android 系统权限**：
   - Android 13+ 需要在系统弹窗或「设置 → 通知」中允许 casual 发送通知
   - Android 通知渠道使用「Assistant alarms」，需要在系统通知设置里允许该渠道的横幅/声音/锁屏提醒
   - Android 12+ 若拒绝精确闹钟权限，应用会降级为非精确调度，提醒可能延迟但不应完全丢失
   - 部分国产 ROM 需要额外允许后台运行/自启动/电池无限制，否则系统可能拦截后台提醒
5. **Windows 主窗口状态**：
   - Windows 端到点后会优先在屏幕右下角弹出独立提醒小窗口，主窗口保持隐藏、最小化或后台状态
   - 如果独立小窗口创建失败，会回退到恢复主窗口并展示应用内闹钟弹窗，避免提醒静默丢失
   - 如果程序已完全退出，应用内 Timer 不再运行，提醒不会触发
6. **查看调试日志**：debug 模式下 `ReminderService` 会输出关键日志，过滤 `[ReminderService]` 前缀可看到 Timer 启动和触发：
   ```
   [ReminderService] tick timer started
   [ReminderService] firing reminder "标题" (id=xxx) at ...
   ```

**代码位置**: `lib/services/reminder_service.dart`（调度与触发逻辑详见[数据流文档](./data-flow.md)）

### 6. 移动端提醒时间偏移（已修复）

**历史缺陷**: 曾经只调用 `tz.initializeTimeZones()` 而未设置本地时区，`tz.local` 默认为 UTC，非 UTC 时区设备上 `zonedSchedule` 的触发时间会偏移。

**修复方式**: `ReminderService.initialize()` 现通过 `flutter_timezone` 获取设备时区并调用 `tz.setLocalLocation()`（获取失败时降级保持 UTC 并输出调试日志）。Windows 路径使用 `DateTime.now()`，不受时区设置影响。

## 构建发布

### Windows 桌面应用

```bash
flutter build windows --release
```

输出位置：`build/windows/x64/runner/Release/`

### Android APK

```bash
flutter build apk --release
```

输出位置：`build/app/outputs/flutter-apk/app-release.apk`

### Web 应用

```bash
flutter build web --release
```

输出位置：`build/web/`

## 代码规范

### 命名规范

- **文件名**: 小写下划线分隔（`notes_page.dart`）
- **类名**: 大驼峰（`NotesPage`）
- **变量/函数**: 小驼峰（`currentNote`）
- **常量**: 大驼峰（`AppColors`）
- **私有成员**: 前缀下划线（`_buildHeader`）

### 目录组织

- 一个功能一个文件
- 相关文件放在同一目录
- Widget 超过 200 行考虑拆分
- Provider 与对应的 Model 放在同一层级

### Git 提交规范

```
feat: 新增笔记标签功能
fix: 修复同步时的空指针异常
docs: 更新 README 文档
refactor: 重构 Git 同步逻辑
style: 格式化代码
test: 添加笔记删除单元测试
```

## 测试

### 单元测试

```bash
flutter test
```

测试文件位置：`test/`

### 集成测试

```bash
flutter drive --target=test_driver/app.dart
```

## 相关文档

- [架构设计](./architecture.md) - 整体架构说明
- [核心功能](./features.md) - 功能详细说明
- [API 文档](./api.md) - Git 平台 API 调用
