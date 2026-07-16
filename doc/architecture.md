# 架构设计

## 目录结构

```
lib/
├── main.dart                    # 应用入口，路由配置，启动引导（AppBootstrapGate）
├── layout/                      # 布局组件
│   └── app_shell.dart          # 应用外壳（桌面侧边导航 / 移动端底部导航）
├── pages/                       # 页面
│   ├── notes_page.dart         # 笔记列表页
│   ├── editor_page.dart        # 笔记编辑页
│   ├── external_markdown_page.dart # 外部 Markdown 文件独立编辑会话（不进入笔记仓库）
│   ├── note_window_page.dart   # 独立笔记窗口（仅 Windows，desktop_multi_window 子引擎入口页）
│   ├── reminder_page.dart      # 定时提醒页
│   ├── plan_page.dart          # 多步骤计划编辑、步骤时间轴与执行动态
│   ├── repo_page.dart          # 设置分支下的仓库管理页
│   ├── platform_config_page.dart # Git 平台配置页
│   ├── settings_page.dart      # 设置总览页
│   ├── token_help_page.dart    # Token 获取帮助页
│   └── search_page.dart        # 搜索页（遗留代码，已被助手功能取代，未接入路由）
├── providers/                   # 状态管理（Riverpod）
│   ├── notes_provider.dart     # 笔记状态管理
│   ├── git_provider.dart       # Git 同步状态管理
│   ├── search_provider.dart    # 搜索状态管理
│   ├── note_window_provider.dart # 独立笔记窗口状态转发（实现在 services/note_window_service.dart）
│   ├── reminder_provider.dart  # 提醒状态管理
│   ├── plan_provider.dart      # 多步骤状态、自动进度与逐步骤提醒联动
│   └── markdown_editor_focus_provider.dart # Markdown 专注视图开关，驱动侧栏/列表隐藏
├── services/                    # 应用服务层
│   ├── reminder_service.dart   # 提醒调度服务（跨平台通知）
│   ├── note_window_service.dart # 独立笔记窗口管理（仅 Windows，多窗口创建/去重/轮询对账/IPC）
│   └── external_markdown_file_service.dart # 系统文件选择器 + 外部 Markdown 原路径读写
├── domain/                      # 领域层
│   └── models/                 # 数据模型
│       ├── models.dart         # 模型统一导出（barrel 文件）
│       ├── note.dart           # 笔记模型
│       ├── git_config.dart     # Git 配置模型
│       ├── search_result.dart  # 搜索结果模型
│       ├── sync_log.dart       # 同步日志模型
│       ├── note_sync_base.dart # 同步 base 快照模型（上次共识版本，三方合并输入）
│       ├── reminder.dart       # 提醒模型（Reminder + RepeatType）
│       └── plan.dart           # Plan/PlanStep、自动进度、状态与动态事件模型
├── data/                        # 数据层
│   ├── repositories/           # 仓储层
│   │   ├── notes_repository.dart
│   │   ├── git_config_repository.dart
│   │   ├── git_sync_repository.dart
│   │   └── plans_repository.dart    # 计划 JSON 快照持久化
│   ├── services/               # 服务层
│   │   ├── storage_service.dart    # 本地存储服务
│   │   ├── github_service.dart     # GitHub API 服务
│   │   └── gitee_service.dart      # Gitee API 服务
│   └── sync/                   # 同步引擎 v2（见 doc/sync-design.md，M1/M2/M3 已实施）
│       ├── blob_sha.dart       # git blob sha 本地计算（内容寻址变更检测）
│       ├── diff3.dart          # 三方行级合并（node-diff3 移植，与 git merge-file 语义一致）
│       ├── sync_planner.dart   # 判定表 + 重命名对账 + 路径分配（§6）
│       ├── note_file_codec.dart # Note ↔ 仓库文件编解码（front-matter 注入/剥离）
│       ├── sync_base_store.dart # base 快照表持久化（key gitnote_sync_base）
│       ├── sync_engine.dart    # 同步会话状态机（§8：判定→下载→落盘→提交→重试→落 base）
│       ├── sync_engine_provider.dart # 引擎 provider + SyncNotesPort 适配 + 可注入 remote 工厂
│       └── remote/             # 远端仓库抽象（§8.4）
│           ├── remote_repo.dart    # 接口 + 请求/结果模型 + 类型化异常
│           ├── github_remote.dart  # Git Data API 原子提交实现
│           └── gitee_remote.dart   # contents API 逐文件降级实现
├── ui/                          # UI 组件
│   ├── core/
│   │   └── extensions/
│   │       └── build_context_l10n.dart  # 国际化扩展
│   └── features/
│       ├── notes/
│       │   └── view_models/
│       ├── git/
│       │   └── view_models/
│       └── search/
│           └── view_models/
├── theme/                       # 主题
│   ├── app_theme.dart          # 应用主题配置
│   └── constants.dart          # 设计常量（颜色、字号、间距等）
├── utils/                       # 工具类
│   ├── common_utils.dart       # 通用工具（时间格式化、屏幕判断等）
│   ├── markdown_utils.dart     # Markdown 处理工具
│   └── front_matter.dart       # YAML front-matter 子集解析/序列化（同步 v2，外来字段无损保留）
├── widgets/
│   └── markdown_preview.dart   # 主编辑器与外部文件会话复用的 Markdown 预览样式
└── l10n/                        # 国际化
    └── generated/              # 自动生成的多语言文件
```

### 遗留结构（技术债）

以下目录/文件是历史遗留的重复实现，仍被部分页面引用，待统一清理：

- `lib/models/models.dart` — 仅 re-export `lib/domain/models/models.dart`，被 `notes_page`、`editor_page`、`repo_page`、`settings_page` 引用。新代码应直接引用 `domain/models/`。
- `lib/services/storage_service.dart`、`lib/services/github_service.dart`、`lib/services/gitee_service.dart` — 与 `lib/data/services/` 下同名文件重复。`settings_page` 仍引用 `lib/services/storage_service.dart`；`reminder_service` 已使用 `lib/data/services/storage_service.dart`。新代码应统一使用 `data/services/`。
- `lib/pages/search_page.dart` — 搜索页已被助手（定时提醒）功能取代，未接入任何路由，不再维护。`searchProvider`（`lib/ui/features/search/view_models/search_view_model.dart`）仍被笔记页与编辑页少量引用，暂不可直接删除。

## 架构模式

本项目采用 **MVVM (Model-View-ViewModel)** 架构模式，结合 **Repository Pattern** 和 **Clean Architecture** 思想：

### 1. 表现层 (Presentation Layer)
- **View**: `pages/` - 页面组件，负责 UI 展示
- **ViewModel**: `providers/` - 使用 Riverpod 管理状态，处理业务逻辑

### 2. 领域层 (Domain Layer)
- **Models**: `domain/models/` - 核心数据模型，业务实体

### 3. 数据层 (Data Layer)
- **Repositories**: `data/repositories/` - 数据仓储，统一数据访问接口
- **Services**: `data/services/` - 具体数据源实现（本地存储、远程 API）

### 4. 应用服务层 (Application Services)
- **Services**: `services/` - 跨页面的应用级服务，如 `ReminderService`（提醒调度，封装 Windows/移动端两套通知实现）、`NoteWindowService`（独立笔记窗口管理，仅 Windows）、`UpdateService`（应用内更新，封装 GitHub Release 检测/下载/安装的跨平台差异）

## 应用内更新架构

更新功能沿用项目分层：`UpdateService`（`data/services/`，网络与文件 IO）→ `updateProvider`（`providers/`，状态机）→ `UpdateDialog`/设置页（表现层）。`AppRelease`（`domain/models/`）封装 Release 解析与语义化版本比较，纯逻辑无副作用，便于单测。

平台差异集中在 `UpdateService` 内用 `Platform.isXxx` 判定：Android 下载 APK 调起系统安装器，Windows 下载 exe/zip 交由系统默认程序处理，其他平台降级为打开 Release 页面。详见 [功能说明 §9](./features.md) 与 [数据流](./data-flow.md)。

## 多窗口架构（仅 Windows 桌面端）

独立笔记窗口基于 `desktop_multi_window` 实现，是本项目唯一的多 Flutter 引擎场景：

- **一个窗口一个引擎**：每个独立窗口运行独立的 Flutter 引擎与 Dart isolate，与主窗口不共享内存状态（Riverpod 状态、SharedPreferences 缓存均各自独立）
- **入口分流**：子引擎以固定参数 `['multi_window', windowId, jsonArgs]` 重新执行 `main()`，`lib/main.dart` 检测到该参数后只运行轻量编辑器（`NoteWindowApp`），不初始化托盘/路由/主窗口服务
- **主窗口单一数据权威**：子窗口通过窗口间 method channel 把编辑实时回传主窗口，统一走 `notesProvider` 更新与持久化；子窗口不直接读写存储，规避多引擎缓存互相覆盖
- **原生集成**：`windows/runner/main.cpp` 通过 `DesktopMultiWindowSetWindowCreatedCallback` 仅为子窗口额外注册 `window_manager`，用于独立窗口隐藏原生标题栏、应用内窗口控制、桌面置顶与透明度调整；子窗口不能调用完整 `RegisterPlugins()`，以免破坏回传主窗口的多窗口事件通道

详见[核心功能 - 独立笔记窗口](./features.md#7-独立笔记窗口仅-windows-桌面端)与[数据流](./data-flow.md)。

## 状态管理

使用 **Riverpod** 进行状态管理：

- `notesProvider` - 管理笔记列表、当前笔记、排序、筛选等状态
- `gitProvider` - 管理 Git 配置、同步状态、同步错误等
- `searchProvider` - 管理搜索关键词、搜索结果、历史记录等
- `reminderProvider` - 管理提醒列表的增删改查与调度联动（`reminderServiceProvider` 提供底层调度服务）
- `planProvider` - 管理有序步骤增删改排、步骤完成/撤销、自动进度、本地持久化与独立步骤提醒
- `markdownEditorFocusProvider` - 主笔记 Markdown 专注视图状态；`AppShell` 与 `NotesRoutePage` 据此保留编辑器 State 的同时收起侧栏和列表
- `externallyOpenNotesProvider` / `noteWindowServiceProvider` - 独立笔记窗口的打开集合与管理服务（仅 Windows 桌面端有效，定义在 `services/note_window_service.dart`）

## 路由管理

使用 **go_router** 进行声明式路由管理：

```dart
/notes                                 # 笔记列表（默认首页）
/notes/:noteId                         # 笔记编辑（?isNew=true 表示新建）
/reminder                              # 定时提醒
/plan                                  # 计划列表、详情与执行时间轴
/settings                              # 设置总览
/settings/repository                   # 仓库管理
/settings/platform-config              # Git 平台配置
/settings/platform-config/token-help   # Token 获取帮助
/repo                                  # 兼容旧地址，重定向到仓库管理
/external-markdown                     # 外部 Markdown 文件会话（仅由文件选择结果携带 route extra 打开）
```

整体采用 `StatefulShellRoute.indexedStack` 实现四个分支（笔记/提醒/计划/设置）的多标签导航，各分支独立保留导航栈。仓库管理和 Git 平台配置作为设置分支的二级路由，进入二级页面时设置导航保持选中。外层由 `AppBootstrapGate` 完成启动引导（加载笔记缓存、Git 配置、初始化提醒调度）后再渲染 `AppShell`。

## 外部 Markdown 文件会话

`ExternalMarkdownFileService` 使用 `file_selector` 调用系统文件选择器，将路径与完整 UTF-8 文本作为路由 extra 交给 `ExternalMarkdownPage`。该页面使用独立的 `TextEditingController` 与 `MarkdownPreview`，不构造 `Note`，不触发 `NotesNotifier`，从结构上隔离了本地电脑文件与 Git 笔记仓库。

Windows/macOS/Linux 保存时，页面经服务直接 `File.writeAsString()` 回写选择时的原路径；外部文档不经过 `note_file_codec.dart`，所以不会注入 front matter、改写标题或分配仓库路径。预览从 `parseFrontMatter()` 取正文，并把文件所在目录传给 `MarkdownPreview` 解析相对图片；保存仍使用完整原文。Android/iOS 受系统文档授权模型影响，页面以只读预览降级。

## 响应式设计

通过 `getScreenType(context)` 判断屏幕类型；Windows 为适配可缩放桌面窗口，在宽度 ≥ 1024px 时额外启用桌面工作区：
- **Desktop**（其他平台 >= 1200px；Windows >= 1024px）：双栏布局，笔记列表 + 编辑器并排显示；Markdown 专注视图可收起侧栏与列表
- **Tablet / Mobile**（其余宽度）：单栏布局，页面间跳转；Markdown 保留编辑/预览切换

详见：`lib/utils/common_utils.dart:18`

## 相关文档

- [核心功能](./features.md) - 各功能模块详细说明
- [数据流](./data-flow.md) - 数据流转与同步逻辑
- [开发指南](./development.md) - 本地开发与调试指南
