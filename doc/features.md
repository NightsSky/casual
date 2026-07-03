# 核心功能

## 1. 笔记管理

### 笔记列表页 (`lib/pages/notes_page.dart`)

**功能**：
- 新建笔记，支持 TXT / Markdown 两种格式：桌面布局（窗口宽度 ≥ 1200px）通过顶栏「+」按钮弹出格式选择菜单；移动布局通过右下角悬浮按钮展开格式选择。创建后自动跳转编辑器
- 展示所有笔记列表，支持按更新时间、创建时间、标题排序
- 支持按标签筛选笔记
- 展示笔记同步状态（已同步/本地/冲突）
- 长按笔记卡片显示操作菜单（编辑、置顶、删除）
- 拖出 txt / Markdown 笔记为独立窗口（仅 Windows 桌面端，详见[独立笔记窗口](#7-独立笔记窗口仅-windows-桌面端)）

**关键代码位置**：
- 新建入口（桌面顶栏）：`lib/pages/notes_page.dart:540` (`_CreatePopup`)
- 新建入口（移动悬浮按钮）：`lib/main.dart:265` (`_MobileNotesWithFab`)
- 创建并跳转编辑器：`lib/main.dart:482` (`NotesRoutePage` 内 `createNote`，两种入口共用)
- 列表渲染：`lib/pages/notes_page.dart:148-164` (`_buildNoteList`)
- 标签筛选：`lib/pages/notes_page.dart:118-146` (`_buildTagsBar`)
- 排序逻辑：`lib/providers/notes_provider.dart` (`setSortBy`)
- 删除笔记：`lib/pages/notes_page.dart:339-366` (`_deleteNote`)

**状态管理**：
- Provider: `notesProvider`
- 状态字段：
  - `sortedNotes` - 排序后的笔记列表
  - `allTags` - 所有标签集合
  - `filterTag` - 当前筛选的标签
  - `sortBy` - 排序方式

### 笔记编辑页 (`lib/pages/editor_page.dart`)

**功能**：
- Markdown 编辑器，支持实时预览
- 预览样式：内容左对齐占满宽度（不居中）；h1/h2/h3 标题带整行浅色背景 + 左侧主色竖条（`_HeadingBackgroundBuilder` 自定义渲染，标题内行内格式按纯文本显示）
- 富文本工具栏（标题、粗体、斜体、链接、图片等）
- 自动保存（输入时触发）
- 标签管理
- 字数统计
- 单条笔记同步到远程
- 空笔记自动清理（dispose 时或返回时）

**关键代码位置**：
- 自动保存：`lib/pages/editor_page.dart:79-91` (`_saveNote`)
- 工具栏：`lib/pages/editor_page.dart:306-332` (`_buildToolbar`)
- 插入文本：`lib/pages/editor_page.dart:334-353` (`_insertText`)
- 预览模式：`lib/pages/editor_page.dart:437-596` (`_buildPreview`)
- 空笔记清理：`lib/pages/editor_page.dart:94-115` (`_isEmptyNote`, `_shouldDiscard`, `_discardIfEmpty`)
- 单条同步：`lib/pages/editor_page.dart:475-536` (`_syncNote`)

**状态管理**：
- Provider: `notesProvider`
- 本地状态：
  - `_titleController` - 标题文本控制器
  - `_contentController` - 正文文本控制器
  - `_isPreview` - 是否预览模式

## 2. Git 同步

### 同步逻辑 (`lib/ui/features/git/view_models/git_view_model.dart`)

**支持平台**：
- GitHub
- Gitee

**功能**：
- 全量同步：先推送本地未同步笔记并记录远程 sha，再拉取远程最新文件导入本地
- 单条推送：推送单条笔记到远程
- 远程删除：删除远程仓库中的笔记文件
- 冲突检测：推送基于文件 SHA 检测远程变化，拉取时保护本地未同步差异

**关键代码位置**：
- 全量同步入口：`lib/pages/notes_page.dart:368-422` (`_handleSync`)
- 全量同步顺序：`lib/ui/features/git/view_models/git_view_model.dart:152-176` (`fullSync`)
- 远程导入冲突保护：`lib/ui/features/notes/view_models/notes_view_model.dart:269-350` (`importNote`)
- 单条推送：`lib/pages/editor_page.dart:475-536` (`_syncNote`)
- 远程删除：`lib/pages/notes_page.dart:339-366` (`_deleteNote` with `deleteRemote`)

**API 服务**：
- GitHub: `lib/data/services/github_service.dart`
- Gitee: `lib/data/services/gitee_service.dart`

**核心方法**：
- `listFiles()` - 递归列出仓库中所有文件
- `getFileContent()` - 获取文件内容（Base64 解码）
- `createOrUpdateFile()` - 创建或更新文件（Base64 编码）
- `deleteFile()` - 删除文件
- `getFileSha()` - 查询文件当前 SHA 值

## 3. 搜索功能（遗留代码，已废弃）

### 搜索页 (`lib/pages/search_page.dart`)

> ⚠️ **现状**：搜索页已被**助手（定时提醒）功能**取代——导航第二个位置现为提醒页，`SearchPage` 未接入任何路由，用户无法从界面进入。相关代码保留但不再维护。`searchProvider` 仍被笔记页（清除搜索）与编辑页（笔记变更后刷新结果）引用，暂不可直接删除。

**已实现的能力**（供后续复用参考）：
- 全文搜索（标题 + 正文 + 标签），防抖输入（300ms）
- 搜索历史记录、高亮匹配结果

**相关代码**：
- 页面：`lib/pages/search_page.dart`
- 状态管理：`lib/ui/features/search/view_models/search_view_model.dart`（`searchProvider`）

## 4. 定时提醒（助手）

### 提醒页 (`lib/pages/reminder_page.dart`)

**功能**：
- 提醒列表展示（标题、时间/间隔、重复方式）
- 新建/编辑提醒（对话框：标题 + 时间选择器 + 重复方式下拉框；选择「按间隔」时改为小时/分钟间隔选择器）
- 开关单条提醒（Switch）
- 删除提醒（二次确认）
- 到达设定时间后弹出系统通知，标题为「GitNote 助手」

**重复方式**（`RepeatType`，见 `lib/domain/models/reminder.dart:3-11`）：

| 类型 | 说明 |
|------|------|
| `none` | 单次提醒（时间已过则不触发） |
| `daily` | 每天 |
| `weekly` | 每周（按创建时间的星期几） |
| `monthly` | 每月（按创建时间的日期） |
| `weekdays` | 工作日（周一至周五） |
| `interval` | 按间隔重复（每隔 N 分钟/小时，如「每隔 1 小时提醒喝水」）。间隔存于 `intervalMinutes` 字段，界面可选 1 分钟～24 小时；保存或重新启用时从当前时刻开始计时，首次触发 = 当前时刻 + 间隔 |
| `custom` | 自定义（**未实现**，界面未提供该选项） |

**状态管理**：
- Provider: `reminderProvider`（`lib/providers/reminder_provider.dart`）
- 状态字段：
  - `reminders` - 提醒列表
  - `isLoading` - 是否加载中
  - `error` - 错误信息
- 操作方法：`addReminder` / `updateReminder` / `deleteReminder` / `toggleReminder`

### 调度实现 (`lib/services/reminder_service.dart`)

通知调度按平台走两条完全不同的路径（分支判断见 `lib/services/reminder_service.dart:29`）：

**Windows 桌面端**（`local_notifier` + 应用内轮询）：
- 不使用系统级定时调度，而是维护一个**应用内 5 秒周期的轮询 Timer**
- 每个启用的提醒计算下次触发时间存入内存表，轮询到期后调用 `local_notifier` 弹出系统 Toast
- `interval` 类型以 `time` 字段为计时锚点，触发点为「锚点 + N × 间隔」；应用重启后延续原节奏，不会立即补发
- 关键代码：
  - 调度入口：`lib/services/reminder_service.dart:166-184`（`_scheduleWindowsReminder`、`_ensureTickTimer`）
  - 轮询触发：`lib/services/reminder_service.dart:186-250`（`_onTick`）
  - 弹出通知：`lib/services/reminder_service.dart:252-268`（`_showWindowsNotification`）
  - 下次触发时间计算：`lib/services/reminder_service.dart:399-461`（`_computeNextFire`）

**Android / iOS / Linux**（`flutter_local_notifications` 系统调度）：
- 初始化时通过 `flutter_timezone` 获取设备时区并调用 `tz.setLocalLocation()`（否则 `tz.local` 默认 UTC，非 UTC 时区的触发时间会偏移）
- 时刻型重复使用 `zonedSchedule` 注册到系统通知调度，按重复类型设置 `matchDateTimeComponents`
- `interval` 类型使用 `periodicallyShowWithDuration` 注册系统级周期通知，首次触发为注册后一个间隔
- Android 使用 `AndroidScheduleMode.exactAllowWhileIdle` 精确调度，启动时请求通知权限
- 关键代码：`lib/services/reminder_service.dart:270-397`（`_scheduleMobileReminder`）

**启动恢复**：
- 应用启动时 `AppBootstrapGate._bootstrap()` 读取 `reminderProvider`（`lib/main.dart:198-204`）
- `ReminderNotifier` 构造时调用 `loadReminders()`，从本地存储读取提醒并对所有启用项重新调度

**存储方式**：
- `shared_preferences`，Key 为 `reminders`，JSON 数组格式（详见[数据流文档](./data-flow.md)）

### 已知限制与注意事项

1. **应用必须保持运行**：Windows 端提醒完全依赖应用内 Timer，应用退出后不会触发任何通知；最小化不影响。移动端由系统调度，但应用被强杀后部分 ROM 可能不触发。
2. **过期单次提醒自动顺延**：保存或重新启用 `RepeatType.none` 的提醒时，若所选时分已过会自动顺延到明天同一时间（`Reminder.rescheduledIfExpired()`，见 `lib/domain/models/reminder.dart`）。历史数据中已过期且一直未操作过的单次提醒仍不会触发，重新保存或开关一次即可。
3. **间隔提醒的计时起点**：保存或重新启用 `RepeatType.interval` 的提醒时，计时锚点重置为当前时刻（同为 `rescheduledIfExpired()` 处理）。Windows 端应用重启后按原锚点延续节奏；移动端重启会重新注册 `periodicallyShowWithDuration`，周期从重启时刻重新计（平台差异）。iOS 系统要求周期不低于 60 秒，界面已限制最小间隔为 1 分钟。
4. **Windows 通知受系统设置影响**：需要在 Windows「设置 → 系统 → 通知」中允许 GitNote 通知；「勿扰模式/专注助手」开启时 Toast 会被抑制。
5. **`custom` 重复类型未实现**：调度时直接返回 `null`（不调度），界面未提供该选项。

## 5. 设置管理

### 设置页 (`lib/pages/settings_page.dart`)

**功能**：
- Git 平台配置（GitHub/Gitee）
- 仓库信息配置（用户名、仓库名、分支）
- Access Token 配置
- 窗口设置（仅 Windows）：配置关闭主面板时的行为（每次询问 / 最小化到系统托盘 / 退出程序）
- 主题切换（待实现）
- 语言切换（待实现）

**关键代码位置**：
- 配置表单：`lib/pages/settings_page.dart`
- 配置持久化：`lib/data/repositories/git_config_repository.dart`
- 关闭行为偏好：`lib/providers/window_provider.dart`

**存储方式**：
使用 `shared_preferences` 持久化配置信息到本地。

## 6. 窗口与系统托盘（仅 Windows 桌面端）

> 平台限制：本功能仅在 Windows 桌面端启用；Android/iOS/Web 上相关代码均为空操作，不注册任何监听。

### 关闭按钮行为 (`lib/widgets/window_close_handler.dart`)

点击窗口右上角关闭按钮时，不会直接退出，而是按用户偏好执行（类似微信）：

- **每次询问**（默认）：弹出确认对话框，可单选"最小化到系统托盘"或"退出程序"，并可勾选"不再询问"记住选择
- **最小化到系统托盘**：隐藏主窗口并从任务栏移除，程序保留在右下角托盘区继续运行
- **退出程序**：尽力销毁托盘图标后直接结束进程，避免 Windows 窗口消息循环回包慢导致退出卡住

偏好通过 `shared_preferences` 持久化（键 `gitnote_window_close_action`），可随时在「设置 → 窗口设置 → 关闭主面板时」修改。

### 系统托盘 (`lib/services/window_service.dart`)

应用启动后常驻托盘图标（图标资源 `assets/tray_icon.ico`）：

- **左键单击**：恢复并聚焦主窗口
- **右键单击**：弹出菜单（显示主界面 / 退出）

**实现要点**：
- `WindowService.init()` 在 `main()` 中于 `runApp` 之前调用，通过 `window_manager` 的 `setPreventClose(true)` 拦截关闭事件
- `WindowCloseHandler` 以 `WindowListener` 身份接收 `onWindowClose` 回调并弹窗（挂载在路由 Shell 外层，见 `lib/main.dart`）
- 托盘由 `tray_manager` 实现，菜单文案走 l10n，在首帧后由 `WindowCloseHandler` 初始化
- 用户选择退出时，`WindowService.exitApp()` 只给窗口/托盘插件短暂清理时间，随后主动 `exit(0)`，不再依赖 `window_manager.destroy()` 投递的 `PostQuitMessage` 完成退出
- 依赖：`window_manager`、`tray_manager`

## 7. 独立笔记窗口（仅 Windows 桌面端）

> 平台限制：本功能仅在 Windows 桌面端启用（`NoteWindowService.isSupported`），支持 **txt / Markdown** 笔记。Android/iOS/Web 上不出现任何相关交互，行为不变。

像 Windows 记事本一样，把一篇 txt 或 Markdown 笔记"拖出"主界面，变成一个单独的轻量级原生窗口继续编辑。

### 交互入口 (`lib/pages/notes_page.dart`)

- **拖出**：在笔记列表按住 txt / Markdown 笔记卡片拖动，拖离列表区域（右侧编辑栏或应用窗口之外）松手即弹出独立窗口；在列表区域内松手视为取消（列表整体是 `DragTarget`，见 `_buildNoteList` / `_buildDraggableCard`）
- **右键菜单**：右键点击 txt / Markdown 笔记卡片 →「在新窗口打开」（`_showNoteContextMenu`）
- **去重**：同一笔记重复拖出时聚焦已有窗口，不会重复创建
- 已拖出的笔记卡片标题旁显示 `open_in_new` 角标

### 独立窗口 (`lib/pages/note_window_page.dart`)

记事本风格的轻量编辑页：标题输入 + 正文 + 底部字数统计。txt 保持纯文本编辑；Markdown 笔记打开时默认显示渲染预览，在标题栏右侧可切换编辑/预览；标题栏图钉按钮可把当前独立窗口置顶在桌面，再次点击取消置顶；透明度按钮可打开滑块，把当前窗口调整为 35% - 100% 不透明度，关闭窗口后恢复默认。切到编辑后显示紧凑 Markdown 工具栏（标题、加粗、斜体、引用、列表、任务、代码块、链接、图片、分隔线），预览内容可选中复制。窗口可自由移动、调整大小，窗口标题栏实时跟随笔记标题。

### 多窗口架构 (`lib/services/note_window_service.dart`)

基于 `desktop_multi_window` 实现。**每个独立窗口是一个独立的 Flutter 引擎 + 独立 isolate**，与主窗口不共享任何内存状态，因此采用"主窗口单一数据权威"架构：

- 子窗口启动参数携带笔记初始内容与格式（noteId/title/content/format），入口分流见 `lib/main.dart`（`main` 函数检测 `multi_window` 参数）
- 子窗口每次输入都通过窗口间 method channel（`noteWindow.update`）实时回传主窗口，由主窗口 `notesProvider.updateNote()` 统一更新与持久化；**子窗口自身绝不读写 SharedPreferences**（两引擎缓存独立，直接写会整表覆盖）
- 子窗口被关闭时 Dart 侧无回调，主窗口以 2 秒周期轮询 `getAllSubWindowIds()` 对账（`_reconcile`），同时负责关闭"笔记已被删除"的孤儿窗口
- 原生侧：`windows/runner/main.cpp` 通过 `DesktopMultiWindowSetWindowCreatedCallback` 只为子窗口引擎额外注册 `window_manager`，用于独立窗口桌面置顶与透明度调整；不能调用完整 `RegisterPlugins()`，否则会破坏子窗口回传主窗口的事件通道

### 并发编辑保护 (`lib/pages/editor_page.dart`)

笔记拖出期间，主窗口编辑器若打开同一笔记会进入**只读模式**：

- 顶部显示横幅"此笔记正在独立窗口中编辑"，附「聚焦窗口」按钮（`_buildDetachedBanner`）
- 独立窗口的编辑内容经 provider 回流后实时镜像到主窗口编辑器（`ref.listen(notesProvider)`）
- 只读期间 `_saveNote` / 空笔记清理（`_shouldDiscard`）均被跳过，防止旧快照覆盖或误删
- 独立窗口关闭后（轮询检测，最多约 2 秒延迟），主窗口编辑器自动加载最新内容并解除只读

**状态管理**：
- `externallyOpenNotesProvider`（`StateProvider<Set<String>>`）—— 当前已拖出的笔记 id 集合
- `noteWindowServiceProvider` —— 窗口管理服务单例

### 已知限制与注意事项

1. **Markdown 独立窗口默认预览**：Markdown 笔记拖出后先显示渲染效果，切到编辑态后提供紧凑工具栏；更完整的笔记操作菜单仍保留在主编辑页。
2. **主窗口是数据通道**：独立窗口的保存依赖主窗口 isolate 存活。主窗口最小化到系统托盘不受影响（isolate 仍在运行）；通过托盘「退出」则整个进程结束，所有独立窗口随之关闭——已输入内容因实时回传不会丢失。
3. **远程同步覆盖**：独立窗口编辑期间执行全量同步（importNote），若远程版本更新会按现有冲突规则覆盖或标记冲突，独立窗口内不感知，继续编辑会以"最后写入者胜"回写。
4. **窗口位置不持久化**：独立窗口按打开顺序阶梯错开排列，应用重启后不恢复上次位置与大小。
5. **macOS/Linux 未开放**：`desktop_multi_window` 本身支持，但本项目未做原生入口与窗口样式适配验证，`isSupported` 仅放行 Windows。

## 8. 国际化

### 多语言支持 (`lib/l10n/`)

**支持语言**：
- 中文 (zh)
- 英文 (en)

**配置文件**：
- `l10n.yaml` - 国际化配置
- `lib/l10n/app_zh.arb` - 中文翻译
- `lib/l10n/app_en.arb` - 英文翻译

**生成命令**：
```bash
flutter gen-l10n
```

**使用方式**：
```dart
// 通过扩展方法访问
context.l10n.appTitle
context.l10n.syncSuccess
```

详见：`lib/ui/core/extensions/build_context_l10n.dart:3`

## 相关文档

- [架构设计](./architecture.md) - 整体架构说明
- [数据流](./data-flow.md) - 数据同步流程
- [API 文档](./api.md) - Git 平台 API 调用说明
