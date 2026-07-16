# 核心功能

## 1. 笔记管理

### 笔记列表页 (`lib/pages/notes_page.dart`)

**功能**：
- 新建笔记，支持 TXT / Markdown 两种格式：Windows 窗口宽度 ≥ 1024px（其他平台 ≥ 1200px）使用桌面顶栏「+」按钮弹出格式选择菜单；移动布局通过右下角悬浮按钮展开格式选择。创建后自动跳转编辑器
- 展示所有笔记列表，支持按更新时间、创建时间、标题排序；每张卡片标题左侧显示 Markdown 代码图标或 TXT 文档图标，无需打开即可区分格式
- 支持按标签筛选笔记
- 展示笔记同步状态（已同步/本地/冲突）
- 顶栏文件夹按钮可通过系统文件选择器打开电脑中的 `.md` / `.markdown` / `.mdown` / `.mkdn` 文件（完整规则见下方“外部 Markdown 文件”）
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
- Markdown 提供**仅编辑、编辑与预览分屏、仅预览**三种视图，顶部只显示一个当前模式按钮，点击即循环切换。Windows 桌面端打开 Markdown 笔记时默认进入分屏；空间不足时分屏自动改为上下排列，保证源码和预览仍可同时查看
- 点击全屏按钮进入专注视图：隐藏应用侧栏、笔记列表、标题、标签和统计栏，让当前编辑/预览区域占满应用内容区；悬浮控制可恢复普通布局
- Windows 默认收起格式工具栏，减少占用；可通过顶部按钮随时显示。移动端继续保留工具栏，确保触摸输入可用
- 预览样式：内容左对齐占满宽度（不居中）；h1/h2/h3 标题带整行浅色背景 + 左侧主色竖条（统一由 `MarkdownPreview` 自定义渲染，标题内行内格式按纯文本显示）
- 富文本工具栏（标题、粗体、斜体、链接、图片等）
- 自动保存（输入时触发）
- 标签管理
- 字数统计
- 单条笔记同步到远程
- 空笔记自动清理（dispose 时或返回时）
- **标题处理按格式区分**：
  - **Markdown**：保留独立标题输入框，标题由用户显式填写
  - **txt**：**不提供标题输入框**，标题从正文首行派生（首个非空行、截断至 80 字符，见 `deriveTxtTitle`）。派生标题仅用于列表卡片显示与同步文件名（`allocatePath`）；导航栏顶部与列表卡片在标题为空（正文全空）时回退显示「无标题」文案

**关键代码位置**：
- 自动保存：`lib/pages/editor_page.dart:79-91` (`_saveNote`)
- 三种 Markdown 视图与专注视图：`lib/pages/editor_page.dart` (`_buildMarkdownModeButton`、`_buildSplitEditor`、`_buildFocusWorkspace`)
- 工具栏：`lib/pages/editor_page.dart` (`_buildToolbar`)
- 插入文本：`lib/pages/editor_page.dart` (`_insertText`)
- 预览模式：`lib/widgets/markdown_preview.dart` (`MarkdownPreview`)
- 空笔记清理：`lib/pages/editor_page.dart:94-115` (`_isEmptyNote`, `_shouldDiscard`, `_discardIfEmpty`)
- 单条同步：`lib/pages/editor_page.dart:475-536` (`_syncNote`)

**状态管理**：
- Provider: `notesProvider`
- 本地状态：
  - `_titleController` - 标题文本控制器
  - `_contentController` - 正文文本控制器
  - `_markdownViewMode` - 当前 Markdown 视图（编辑 / 分屏 / 预览）
  - `markdownEditorFocusProvider` - 控制桌面端专注视图是否隐藏全局导航与列表

### 外部 Markdown 文件 (`lib/pages/external_markdown_page.dart`)

**使用方法**：

1. 在笔记列表顶栏点击“打开 Markdown 文件”文件夹按钮
2. 从系统文件选择器选择 `.md`、`.markdown`、`.mdown` 或 `.mkdn` 文件
3. Windows 桌面端默认分屏浏览源码和渲染结果，可通过单个模式按钮循环切换仅编辑、分屏、仅预览，并可进入全屏专注视图
4. 编辑后按顶部保存按钮或 `Ctrl+S`，将完整 Markdown 原文写回所选的同一文件

**保存与边界**：

- 外部文件使用独立会话，不创建 `Note`、不写入 `notesProvider` / `shared_preferences`，也不会进入 GitHub/Gitee 同步
- 保存原样写入编辑器的完整源码，因此 YAML front matter、注释和换行不会被应用的笔记编解码逻辑转换
- 预览会隐藏文件开头的 YAML front matter，并以所选文件所在目录解析 Markdown 相对图片；保存仍保留完整原文
- 返回前如有未保存修改，会要求用户确认继续编辑或放弃修改；保存失败时保留编辑内容并提示错误
- 当前不监听其他程序对该文件的后续改动；需要重新读取时可再次通过文件选择器打开
- 当前不注册 Windows 文件关联；请从应用内“打开 Markdown 文件”入口选择文档

**平台支持**：

- ✅ Windows：选择、编辑、保存原文件、分屏和专注视图
- ✅ macOS / Linux：使用支持原路径的文件选择器时可编辑保存（未纳入本次重点验证）
- ⚠️ Android / iOS：可通过系统选择器以只读方式预览，避免受 SAF / 文件授权限制时误写第三方文件

**关键代码位置**：

- 选择与读写：`lib/services/external_markdown_file_service.dart`
- 独立编辑会话：`lib/pages/external_markdown_page.dart`
- 打开入口与路由：`lib/pages/notes_page.dart`、`lib/main.dart` (`/external-markdown`)

## 2. Git 同步

> 自 v2 起，同步机制重新设计为**基于 base 快照的双向同步会话**。完整设计与决策见 [同步策略设计](./sync-design.md)。

### 同步逻辑 (`lib/data/sync/sync_engine.dart`)

**支持平台**：
- GitHub（Git Data API 单提交原子写入）
- Gitee（v5 无 git-data 写端点，降级为逐文件 contents API）

**功能**：
- **单一同步动作**：不再区分「拉取 / 推送 / 全量」，一次「同步」= 一个完整双向会话，自动判定每篇笔记该拉、该推、该合并还是该删除
- **文档身份**：Markdown 以文件头 front-matter `id` 标识身份，改标题不会产生重复文件；txt 降级为路径身份
- **变更判定**：以本地自算的 git blob sha 与 base 快照、远端清单三方比对（内容寻址，不依赖设备时钟）
- **冲突处理**：双端都改过同一篇（判定表规则 4）时绝不静默覆盖。当前 M3 代码为「diff3 自动合并 + 合不动则生成冲突副本」；M4 起冲突策略已定为**二选一**——弹窗展示本地与远端最后更新时间，用户逐篇选「保留本地 / 用远程覆盖 / 取消跳过」，不再自动合并或留副本（见 [同步策略设计 §7](./sync-design.md)，代码待 M4 替换）
- **删除传播**：本地删除只删本地、base 表留作墓碑，下次同步传播到远端；本地删+远端改时保守恢复（删除让位于修改）
- **原子性 / 乐观锁**：GitHub 单提交全成或全败，updateRef 失败自动重试（≤3 次）；Gitee 逐文件失败隔离不中断批次

**关键代码位置**：
- 同步入口（笔记页）：`lib/pages/notes_page.dart` (`_handleSync`)
- 同步入口（设置 → 仓库管理）：`lib/pages/repo_page.dart` (`_sync`)
- 会话驱动：`lib/ui/features/git/view_models/git_view_model.dart` (`runSync`)
- 会话状态机：`lib/data/sync/sync_engine.dart` (`SyncEngine.sync`)
- 判定表：`lib/data/sync/sync_planner.dart` (`planSync`)
- 三方合并：`lib/data/sync/diff3.dart`
- 远端抽象：`lib/data/sync/remote/`（`github_remote.dart` / `gitee_remote.dart`）
- 状态回写口：`lib/ui/features/notes/view_models/notes_view_model.dart`（`applyRemoteUpsert` 等 `SyncNotesPort` 方法）
- base 表持久化：`lib/data/sync/sync_base_store.dart`

**远端层核心方法**（`RemoteRepo` 接口）：
- `fetchHead()` - 取分支 head commit sha
- `listTree()` - 递归列出全仓库 `path → blobSha` 清单（一个请求）
- `fetchBlob()` - 按 blob sha 读取内容（不受 contents API 1MB 限制）
- `commitChanges()` - 提交一批写入/删除（GitHub 原子 / Gitee 逐文件）

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
- 到达设定时间后触发提醒：Windows 桌面端在屏幕右下角弹出独立提醒小窗口；Android/iOS/Linux 走系统通知

**重复方式**（`RepeatType`，见 `lib/domain/models/reminder.dart:3-11`）：

| 类型 | 说明 |
|------|------|
| `none` | 单次提醒（新建默认下一分钟；选择当前分钟时按马上提醒处理；更早时间会顺延到明天） |
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

通知调度按平台走两条完全不同的路径（分支判断见 `lib/services/reminder_service.dart`）：

**Windows 桌面端**（应用内轮询 + 独立提醒小窗口）：
- 不使用系统级定时调度，而是维护一个**应用内 5 秒周期的轮询 Timer**
- 每个启用的提醒计算下次触发时间存入内存表，轮询到期后通过 `windowsAlarmStream` 向 UI 发出提醒事件
- `ReminderAlarmHost` 监听提醒事件后优先通过 `ReminderAlarmWindowService` 创建 `desktop_multi_window` 子窗口，只展示右下角提醒卡片，不恢复完整主窗口；子窗口不可用时回退到主窗口右下角 Dialog，避免提醒静默丢失
- `interval` 类型以 `time` 字段为计时锚点，触发点为「锚点 + N × 间隔」；应用重启后延续原节奏，不会立即补发
- 关键代码：
  - 调度入口：`lib/services/reminder_service.dart`（`_scheduleWindowsReminder`、`_ensureTickTimer`）
  - 轮询触发：`lib/services/reminder_service.dart`（`_onTick`）
  - 弹窗宿主：`lib/widgets/reminder_alarm_host.dart`（`ReminderAlarmHost`）
  - 独立提醒窗口：`lib/services/reminder_alarm_window_service.dart`、`lib/pages/reminder_alarm_window_page.dart`
  - 下次触发时间计算：`lib/services/reminder_service.dart`（`_computeNextFire`）

**Android / iOS / Linux**（`flutter_local_notifications` 系统调度）：
- 初始化时通过 `flutter_timezone` 获取设备时区并调用 `tz.setLocalLocation()`（否则 `tz.local` 默认 UTC，非 UTC 时区的触发时间会偏移）
- 时刻型重复使用 `zonedSchedule` 注册到系统通知调度，按重复类型设置 `matchDateTimeComponents`
- `interval` 类型使用 `periodicallyShowWithDuration` 注册系统级周期通知，首次触发为注册后一个间隔
- Android 启动时请求通知权限；保存提醒时优先使用 `AndroidScheduleMode.exactAllowWhileIdle`，若系统未授予精确闹钟权限，则降级为 `inexactAllowWhileIdle`，避免提醒完全不触发
- Android 使用 `assistant_alarm_channel` 闹钟提醒渠道，通知类别为 `alarm`，重要性为 `max`，用于提升横幅、声音和锁屏提醒的优先级
- Android Manifest 声明了 `SCHEDULE_EXACT_ALARM`、`RECEIVE_BOOT_COMPLETED` 以及 `flutter_local_notifications` 的定时接收器，支持系统到点唤醒和重启/应用更新后恢复已注册提醒
- 关键代码：`lib/services/reminder_service.dart:270-427`（`_scheduleMobileReminder`、`_resolveAndroidScheduleMode`）

**启动恢复**：
- 应用启动时 `AppBootstrapGate._bootstrap()` 读取 `reminderProvider`（`lib/main.dart:198-204`）
- `ReminderNotifier` 构造时调用 `loadReminders()`，从本地存储读取提醒并对所有启用项重新调度

**存储方式**：
- `shared_preferences`，Key 为 `reminders`，JSON 数组格式（详见[数据流文档](./data-flow.md)）

### 已知限制与注意事项

1. **应用必须保持运行**：Windows 端提醒完全依赖应用内 Timer，应用退出后不会触发；最小化到系统托盘或主窗口位于后台时，到点后只在屏幕右下角弹出独立提醒小窗口。移动端由系统调度，但应用被强杀后部分 ROM 可能不触发。
2. **单次提醒的过期处理**：新建提醒对话框默认选中下一分钟；保存或重新启用 `RepeatType.none` 时，若选择的是当前分钟，会调度到当前时间后 10 秒，便于马上验证提醒；若所选时分早于当前分钟，则自动顺延到明天同一时间（`Reminder.rescheduledIfExpired()`，见 `lib/domain/models/reminder.dart`）。历史数据中已过期且一直未操作过的单次提醒仍不会触发，重新保存或开关一次即可。
3. **间隔提醒的计时起点**：保存或重新启用 `RepeatType.interval` 的提醒时，计时锚点重置为当前时刻（同为 `rescheduledIfExpired()` 处理）。Windows 端应用重启后按原锚点延续节奏；移动端重启会重新注册 `periodicallyShowWithDuration`，周期从重启时刻重新计（平台差异）。iOS 系统要求周期不低于 60 秒，界面已限制最小间隔为 1 分钟。
4. **Android 通知受系统权限影响**：Android 13+ 需要允许通知权限；Android 12+ 若未授予精确闹钟权限，提醒会按系统允许的非精确模式触发，可能有轻微延迟。MIUI 等系统还可能按渠道单独控制横幅/声音，需要允许「Assistant alarms」渠道的弹出和铃声。
5. **`custom` 重复类型未实现**：调度时直接返回 `null`（不调度），界面未提供该选项。

## 5. 计划与设置管理

### 计划页 (`lib/pages/plan_page.dart`)

计划模块将一个目标拆成有顺序的执行步骤，并分别展示“计划步骤”时间轴和“执行动态”。主导航进入 `/plan`：

- **移动端/窄窗口**：单列计划列表，点击后进入独立详情页
- **桌面端/宽窗口**：左侧计划列表、右侧步骤时间轴与执行动态双栏展示
- **列表筛选**：全部、进行中、已逾期、已完成、已终止

主要能力：

1. 每个计划保留唯一标题、目标和开始时间，至少包含一个步骤
2. 每个步骤填写标题、预计完成时间，并可设置独立提醒
3. 支持添加、删除和拖动排序步骤；步骤预计时间必须按顺序非递减
4. 允许跳过前序步骤完成后续步骤，完成时可填写步骤完成说明
5. 整体进度按“已完成步骤数 / 总步骤数”自动计算，不再手动填写百分比
6. 全部步骤完成时计划自动完成；撤销任一步完成状态后计划自动恢复进行中
7. 保留计划级执行记录、终止和删除能力
8. 详情上方展示步骤计划轴，下方展示创建、编辑、完成、撤销、记录和终止动态

**状态规则**：

- 步骤未完成且达到预计时间：该步骤显示已逾期
- 早期步骤逾期但最后步骤时间未到：计划整体仍显示进行中
- 当前时间达到最后步骤预计时间且计划未完成：计划整体显示已逾期
- 所有步骤完成：计划自动变为已完成，进度为 100%
- 撤销已完成步骤或给已完成计划新增未完成步骤：计划恢复进行中
- 已终止计划保持只读，保留步骤完成情况和全部历史

**提醒规则**：

- 每个步骤独立支持不提醒、到期时、提前 1 小时、提前 1 天和自定义分钟数
- 与助手提醒一致，新建步骤默认启用“到期时提醒”；只有用户显式选择“不提醒”时才关闭
- 步骤提醒使用 `plan-{planId}-step-{stepId}` 独立标识，互不覆盖
- 提前提醒时间已错过但步骤时间仍在未来时，降级为步骤到期时提醒
- 选择当前分钟作为步骤到期时间时，会在当前时间约 10 秒后触发，给 Windows 轮询和移动端调度留出缓冲
- Windows 在内存调度表中保留步骤提醒的完整标题和时间；步骤提醒无需写入普通助手提醒列表也能正常弹窗
- 完成、删除步骤或终止、删除计划时取消对应提醒；撤销完成后按有效时间恢复提醒
- Android/iOS 使用系统本地通知；Windows 复用应用内独立提醒小窗口

**旧数据兼容**：

第一版没有 `steps` 的计划会自动迁移为单步骤计划：步骤标题取原目标、预计时间取原截止时间、提醒继承原提醒；原手动进度作为迁移动态保留，后续保存统一写入新结构。 若原计划开启过整体提醒，启动迁移时会先取消旧 `plan-{id}` 调度，再注册新的步骤提醒，避免重复通知。

**关键代码位置**：

- 计划与步骤领域规则：`lib/domain/models/plan.dart`
- 本地持久化和旧数据读取：`lib/data/repositories/plans_repository.dart`
- 步骤状态与提醒联动：`lib/providers/plan_provider.dart`
- 响应式步骤时间轴：`lib/pages/plan_page.dart`

**平台支持**：✅ Windows | ✅ Android | ✅ iOS

### 设置页 (`lib/pages/settings_page.dart`)

设置页作为配置总览，保留同步偏好、Windows 窗口设置和关于信息，并提供两个独立入口：

- **仓库管理**：进入 `/settings/repository`，执行同步、查看同步统计与同步记录
- **Git 平台配置**：进入 `/settings/platform-config`，维护 GitHub/Gitee、Access Token、用户名/组织、仓库名、分支和笔记目录
- **窗口设置**（仅 Windows）：配置关闭主面板时的行为（每次询问 / 最小化到系统托盘 / 退出程序）
- 主题切换（待实现）
- 语言切换（待实现）

### 仓库管理页 (`lib/pages/repo_page.dart`)

仓库管理能力从主导航迁入设置分支，原有连接状态、全量同步、同步统计、冲突处理和同步日志保持不变。“仓库设置”快捷操作会进入独立 Git 平台配置页。

### Git 平台配置页 (`lib/pages/platform_config_page.dart`)

平台与仓库连接表单从设置总览拆出。连接测试会先保存当前表单，再使用最新配置验证远端连接；Token 帮助页位于 `/settings/platform-config/token-help`。

**关键代码位置**：
- 设置总览：`lib/pages/settings_page.dart`
- 仓库管理：`lib/pages/repo_page.dart`
- 平台配置表单：`lib/pages/platform_config_page.dart`
- 配置持久化：`lib/data/repositories/git_config_repository.dart`
- 关闭行为偏好：`lib/providers/window_provider.dart`

**存储方式**：
Git 连接信息和窗口偏好继续使用 `shared_preferences` 持久化到本地。
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
- **右键菜单**：右键点击 txt / Markdown 笔记卡片 →「在新窗口打开」；txt 笔记额外提供「打开为便签标签」入口（`_showNoteContextMenu`）
- **去重**：同一笔记重复拖出时聚焦已有窗口，不会重复创建（标签模式与普通独立窗口共用同一登记表，同一笔记二者互斥）
- 已拖出的笔记卡片标题旁显示 `open_in_new` 角标

### 独立窗口 (`lib/pages/note_window_page.dart`)

记事本风格的轻量编辑页：标题栏 + 正文 + 底部字数统计。txt 保持原有编辑/预览切换，默认进入只读预览；**无独立标题输入框**——标题栏只读展示从正文首行派生的标题（空内容回退「无标题」文案），用于窗口辨识与拖动；txt 预览态在受限宽度阅读纸张上以可选中纯文本渲染正文。

Markdown 独立窗口默认进入**编辑 / 实时预览分屏**，标题栏的单个模式按钮可在仅编辑、分屏和仅预览之间循环切换；源码、预览和主窗口共享同一份内容更新链路，输入后立即回传主窗口并刷新渲染结果。Windows 默认收起 Markdown 格式工具栏，用户可按顶部按钮展开标题、加粗、斜体、引用、列表、任务、代码块、链接、图片和分隔线操作。为保证双栏体验，Markdown 新窗口优先使用 1120×760 初始尺寸，并会按显示器可见区域收缩；也可通过最大化/还原按钮将当前窗口作为全屏工作区使用。独立窗口隐藏原生 Windows 标题栏，笔记标题、拖动手柄、置顶、透明度、最小化、最大化/还原和关闭操作都放在内容标题行内；透明度按钮可打开滑块，把当前窗口调整为 35% - 100% 不透明度，关闭窗口后恢复默认。预览内容可选中复制。窗口可通过标题行拖动并自由调整大小。

### 标签模式窗口 (`lib/pages/note_tag_window_page.dart`)

> 平台限制：仅 Windows 桌面端、**仅 txt** 笔记（`NoteWindowService.canUseTagMode`）。

标签模式是独立窗口的优化形态，模拟"贴边便签"：

- **入口**：右键 txt 笔记卡片 →「打开为便签标签」（`openNoteWindow(note, asTag: true)`）
- **折叠胶囊态**：默认呈现为贴屏幕右侧、纵向居中的圆角胶囊（初始约 240×52），只显示正文首行（`deriveTxtTitle`，空内容回退「无标题」）；胶囊左侧有拖动手柄（`DragToMoveArea`），可自由移动
- **展开态**：点击胶囊在原窗口内展开为可编辑的完整正文（约 300×420），顶部保留拖动手柄、折叠、关闭；展开/折叠时窗口锚定右边缘缩放，贴边视觉位置不跳动
- **贴边常驻**：便签窗口常置顶（`setAlwaysOnTop`）且不占任务栏（`setSkipTaskbar`），切到其他应用也不会被遮住，符合桌面便签直觉；关闭走展开态右上角的关闭按钮
- **数据链路**：与普通独立窗口完全一致——无边框透明窗口（`window_manager.setAsFrameless`），每次输入经 `noteWindow.update` IPC 回传主窗口持久化，绝不直写本地存储；txt 标题仍由主窗口按首行派生
- **去重**：与普通独立窗口共用 `_noteWindows` 登记表，同一笔记已打开时聚焦既有窗口

### 多窗口架构 (`lib/services/note_window_service.dart`)

基于 `desktop_multi_window` 实现。**每个独立窗口是一个独立的 Flutter 引擎 + 独立 isolate**，与主窗口不共享任何内存状态，因此采用"主窗口单一数据权威"架构：

- 子窗口启动参数携带笔记初始内容与格式（noteId/title/content/format）及 `mode`（`window` 普通独立窗口 / `tag` 标签胶囊窗口），入口分流见 `lib/main.dart`（`main` 函数检测 `multi_window` 参数后按 `mode` 分发到 `NoteWindowApp` 或 `NoteTagWindowApp`）
- 子窗口每次输入都通过窗口间 method channel（`noteWindow.update`）实时回传主窗口，由主窗口 `notesProvider.updateNote()` 统一更新与持久化；**子窗口自身绝不读写 SharedPreferences**（两引擎缓存独立，直接写会整表覆盖）
- 子窗口被关闭时 Dart 侧无回调，主窗口以 2 秒周期轮询 `getAllSubWindowIds()` 对账（`_reconcile`），同时负责关闭"笔记已被删除"的孤儿窗口
- 原生侧：`windows/runner/main.cpp` 通过 `DesktopMultiWindowSetWindowCreatedCallback` 只为子窗口引擎额外注册 `window_manager`，用于独立窗口隐藏原生标题栏、窗口拖动/控制、桌面置顶与透明度调整；不能调用完整 `RegisterPlugins()`，否则会破坏子窗口回传主窗口的事件通道

### 并发编辑保护 (`lib/pages/editor_page.dart`)

笔记拖出期间，主窗口编辑器若打开同一笔记会进入**只读模式**：

- 主窗口不再显示标题输入区、标签、预览、正文编辑器和页脚，只显示"此笔记正在独立窗口中编辑，此处为只读"以及「聚焦窗口」按钮（`_buildDetachedNotice`）
- 独立窗口的编辑内容经 provider 回流后只更新主窗口缓存，主窗口不展示正文内容，避免用户在两处同时阅读/编辑同一笔记产生误判
- 只读期间 `_saveNote` / 空笔记清理（`_shouldDiscard`）均被跳过，防止旧快照覆盖或误删
- 独立窗口关闭后（轮询检测，最多约 2 秒延迟），主窗口编辑器自动加载最新内容并解除只读

**状态管理**：
- `externallyOpenNotesProvider`（`StateProvider<Set<String>>`）—— 当前已拖出的笔记 id 集合
- `noteWindowServiceProvider` —— 窗口管理服务单例

### 已知限制与注意事项

1. **独立窗口默认预览**：txt 与 Markdown 笔记拖出后都先进入预览态（txt 为可选中纯文本纸张，Markdown 为渲染结果），与主编辑器"打开已有笔记默认预览"一致；切到编辑态后 Markdown 提供紧凑工具栏；更完整的笔记操作菜单仍保留在主编辑页。
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

## 9. 应用内更新

基于 GitHub Release 的版本检测与下载安装，支持 **Android** 与 **Windows 桌面**。

### 版本检测 (`lib/data/services/update_service.dart`)

- 通过 GitHub API `GET /repos/NightsSky/casual/releases/latest` 获取最新发布版本，无需 Token（公开仓库）。
- `AppRelease.isNewerVersion` 做语义化版本比较：去掉 `v` 前缀与 `+构建号`，逐段比较数字，缺失段补 0；无法解析时保守判定为“无更新”，避免误报。
- 当前版本号来自 `package_info_plus`（读取原生构建配置，与 `pubspec.yaml` 的 `version` 一致）。

### 平台下载策略（遵循跨平台规则）

| 平台 | 资产选择 | 安装方式 | 下载目录 |
| --- | --- | --- | --- |
| Android | 优先 `.apk` | `open_filex` 调起系统安装器（需授权“安装未知应用”） | 外部存储 `updates/` |
| Windows | 优先 `.exe`，退回 `.zip` | `open_filex` 运行安装器或在资源管理器打开压缩包 | 临时目录 `casual_updates/` |
| 其他 | 无自动下载 | 降级为 `url_launcher` 打开 Release 页面 | — |

下载带进度回传（`0~1`，总长未知时为不确定进度）；已存在且大小一致的文件会复用，避免重复下载。

### 交互入口

- **启动静默检查**：`main.dart` 的 `AppBootstrapGate` 就绪后静默检查，仅在发现新版本时弹出 `UpdateDialog`（子窗口引擎不参与）。
- **手动检查**：设置页“关于”区新增“检查更新”项，展示当前版本号；已是最新时 Snackbar 提示，出错给出错误信息。
- **更新对话框** (`lib/widgets/update_dialog.dart`)：展示新版本号、更新说明、下载进度与安装/打开发布页按钮，关闭时重置状态。

### 状态管理 (`lib/providers/update_provider.dart`)

`UpdateNotifier` 驱动 `idle → checking → available/upToDate → downloading → readyToInstall`（或 `error`）状态机，UI 按阶段渲染。

### 发布流程 (`.github/workflows/release.yml`)

推送形如 `v0.2.0` 的 tag 时触发，并行构建 Android APK 与 Windows zip，命名为 `casual-<版本>.apk` / `casual-windows-<版本>.zip` 上传到对应 Release，供应用检测下载。

### 已知限制与注意事项

- Android 首次安装需用户在系统设置中授予“安装未知应用”权限。
- Windows 若发布 `.zip`，应用只能打开压缩包，需用户手动解压覆盖（对话框有提示）；发布 `.exe` 安装包体验更佳。
- 版本比较依赖 tag 命名规范（`vX.Y.Z`），发布时务必与 `pubspec.yaml` 版本对齐。

## 相关文档

- [架构设计](./architecture.md) - 整体架构说明
- [数据流](./data-flow.md) - 数据同步流程
- [API 文档](./api.md) - Git 平台 API 调用说明
