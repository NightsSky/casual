# 数据流

## 笔记数据流

### 创建笔记

```
用户点击新建按钮
    ↓
NotesViewModel.createNote()
    ↓
生成新笔记对象（UUID、时间戳）
    ↓
添加到内存状态（notesProvider）
    ↓
保存到本地存储（shared_preferences）
    ↓
导航到编辑页
```

**代码位置**：
- UI 触发：`lib/main.dart:284-289` (FloatingActionButton onPressed)
- ViewModel：`lib/providers/notes_provider.dart` (`createNote`)
- 本地持久化：`lib/data/services/storage_service.dart`

### 更新笔记

```
用户输入文本
    ↓
TextField onChanged 触发
    ↓
EditorPage._saveNote()
    ↓
NotesViewModel.updateNote()
    ↓
更新内存状态
    ↓
自动保存到本地存储
```

**代码位置**：
- UI 触发：`lib/pages/editor_page.dart:228` (title), `lib/pages/editor_page.dart:297` (content)
- 保存逻辑：`lib/pages/editor_page.dart:79-91` (`_saveNote`)
- ViewModel：`lib/providers/notes_provider.dart` (`updateNote`)

### 删除笔记

```
用户选择删除
    ↓
显示确认对话框
    ↓
用户确认
    ↓
如果已配置 Git：
    ├─> GitViewModel.deleteRemoteNote()
    │       ↓
    │   调用 GitHub/Gitee API 删除远程文件
    │       ↓
    └─> 删除成功后
            ↓
NotesViewModel.deleteNote()
    ↓
从内存状态移除
    ↓
从本地存储移除
```

**代码位置**：
- UI 触发：`lib/pages/notes_page.dart:241-262` (`_confirmDelete`)
- 删除逻辑：`lib/pages/notes_page.dart:264-291` (`_deleteNote`)
- ViewModel：`lib/providers/notes_provider.dart` (`deleteNoteWithRemote`)

## Git 同步数据流

> 自 v2 起，同步不再区分「推送 / 拉取 / 全量」三个动作，统一为**一次双向同步会话**（`SyncEngine`）。完整设计见 [同步策略设计](./sync-design.md)；本节描述数据在会话中的流向。

### 双向同步会话（v2 引擎）

任意入口（笔记列表同步按钮、仓库页同步、编辑页保存后同步）都调用 `GitNotifier.runSync()`，进而驱动一次 `SyncEngine.sync()` 会话。引擎不理解 UI，只经 `SyncNotesPort` 读写内存状态权威（`NotesNotifier`），再由其持久化——引擎**不直写存储**（多窗口不变量）。

```
用户触发同步（列表 / 仓库页 / 编辑页）
    ↓
GitNotifier.runSync()（置 isSyncing，写同步日志）
    ↓
SyncEngine.sync(config)
    ├─ ① fetchHead()            远端分支 head commit（空仓库为 null）
    ├─ ② listTree(head)         一次拿全仓库 path→blobSha 清单，按 notesDir/.md/.txt 过滤
    │                           （清单被截断则抛异常中止，不误判删除）
    ├─ 合成 base（v1 迁移吸收）  老数据有 filePath 无 base → 以远端当前版本合成共识 base
    ├─ ③ 判定（sync_planner）    对「本地 ∪ base ∪ 远端清单」每个身份键套用判定表：
    │       ├─ 只有本地变 → 推送
    │       ├─ 只有远端变 → 拉取覆盖
    │       ├─ 双端都变 → 冲突（规则 4）
    │       │       └─ 收集到 SyncReport.pendingConflicts，UI 二选一裁决（§7）
    │       ├─ base 有本地无 → 传播删除到远端
    │       └─ base 有远端无 → 传播删除到本地
    ├─ ④ 按需下载变更文件的 blob（sha 与 base 相同者不下载）
    ├─ ⑤ 本地落盘：applyRemoteUpsert / applyRemoteDelete / rewriteNoteId
    ├─ ⑥ 远端提交：GitHub 走 Git Data API 单提交原子写入；Gitee 逐文件 contents API
    ├─ ⑦ head 移动（updateRef 非 fast-forward）→ 回到 ① 重试（≤3 次，仓库级乐观锁）
    └─ ⑧ 更新 base 表（本次共识版本）
            ↓
返回 SyncReport（pushed/pulled/conflicts/deleted/restored/failures）
    ↓
UI 若有冲突：逐篇弹二选一对话框，收集裁决后调 engine.resolveConflicts()，再同步一次
    ↓
GitNotifier 写同步日志（report.summary()）、更新 lastSyncTime
    ↓
UI 关闭进度弹窗，SnackBar 显示同步完成
```

**代码位置**：
- 引擎主入口：`lib/data/sync/sync_engine.dart` (`SyncEngine.sync` / `_attempt` / `resolveConflicts`)
- 判定表：`lib/data/sync/sync_planner.dart` (`planSync`)
- 远端抽象：`lib/data/sync/remote/`（`github_remote.dart` 原子提交 / `gitee_remote.dart` 逐文件）
- base 表持久化：`lib/data/sync/sync_base_store.dart`（key `gitnote_sync_base`）
- 状态回写口：`lib/ui/features/notes/view_models/notes_view_model.dart`（`applyRemoteUpsert` / `applyRemoteDelete` / `rewriteNoteId` / `markPushed`）
- ViewModel 入口：`lib/ui/features/git/view_models/git_view_model.dart` (`runSync` / `resolveConflicts`)
- 冲突对话框：`lib/ui/widgets/conflict_resolution_dialog.dart`
- UI 触发：`lib/pages/notes_page.dart` (`_handleSync` / `_handleConflicts`)、`lib/pages/repo_page.dart` (`_sync` / `_handleConflicts`)、`lib/pages/editor_page.dart` (`_syncNote`)

### 删除（本地墓碑，会话传播）

v2 删除不再即时删远端。删除只移除本地笔记，**base 表保留该条目作为墓碑**，下次同步会话由引擎按判定表传播：

```
用户删除笔记 → NotesViewModel.deleteNote(id)（仅删本地内存 + 持久化）
    ↓
下次同步会话，引擎发现「base 有该键、本地快照没有」
    ├─ 远端相对 base 未变 → 推送删除到远端，清 base（规则 5）
    └─ 远端相对 base 已变（改删冲突）→ 远端新版拉回本地并计入 restored，
                                       用户可再删（删除让位于修改，不静默丢另一端修改，规则 8）
```

**代码位置**：
- 删除逻辑：`lib/pages/notes_page.dart` (`_deleteNote`)、`lib/pages/editor_page.dart` (`_deleteNote`)，均为纯本地 `deleteNote`
- 传播判定：`lib/data/sync/sync_planner.dart`（规则 5/6/7/8）

## 提醒数据流

### 创建/编辑提醒

```
用户在提醒页点击 + / 点击提醒卡片
    ↓
_ReminderDialog 填写标题、时间、重复方式（新建单次提醒默认下一分钟）
（重复方式选「按间隔」时改为选择小时/分钟间隔，不再选择时刻）
    ↓
单次提醒若选择当前分钟：调度到当前时间后 10 秒；
单次提醒若所选时分早于当前分钟：自动顺延到明天同一时间；
间隔提醒：计时锚点（time 字段）重置为当前时刻，下次触发 = 现在 + 间隔
（Reminder.rescheduledIfExpired()，重新启用开关时同样处理）
    ↓
ReminderNotifier.addReminder() / updateReminder()
    ↓
更新内存状态（reminderProvider）
    ↓
ReminderService.saveReminders() 持久化到 shared_preferences
    ↓
ReminderService.scheduleReminder() 注册调度
    ├─> Windows：计算下次触发时间 → 存入内存表 → 启动 5 秒轮询 Timer
    │   （interval 型触发点 = 锚点 + N × 间隔，取未来最近一个）
    └─> Android/iOS/Linux：
        ├─> Android：检查精确闹钟能力；未授权时降级为非精确 idle 调度
        ├─> 时刻型：flutter_local_notifications.zonedSchedule() 注册系统调度
        └─> interval 型：periodicallyShowWithDuration() 注册系统周期通知
```

**代码位置**：
- UI 触发：`lib/pages/reminder_page.dart:427` (`_saveReminder`)、间隔选择器 `lib/pages/reminder_page.dart:355` (`_buildIntervalPicker`)
- 过期顺延/锚点重置：`lib/domain/models/reminder.dart:63-85` (`rescheduledIfExpired`)
- 状态管理：`lib/providers/reminder_provider.dart:70-112` (`addReminder`, `updateReminder`, `toggleReminder`)
- 持久化：`lib/services/reminder_service.dart:102-105` (`saveReminders`)
- 调度分发：`lib/services/reminder_service.dart:107-121` (`scheduleReminder`)

### 提醒触发（Windows）

```
5 秒周期 Timer 轮询（应用内）
    ↓
_onTick()：遍历内存表中各提醒的下次触发时间
    ↓
到期（距现在 ≤ 5 秒）
    ├─> 从存储重读提醒，校验仍存在且启用
    ├─> 去重检查（同一触发点只发一次）
    ├─> local_notifier 弹出系统 Toast（「casual 助手」+ 提醒标题）
    └─> 计算下一次触发时间
            ├─> 有下次（重复提醒）：更新内存表
            └─> 无下次（单次提醒）：从内存表移除，表空则停止 Timer
```

**代码位置**：
- 轮询与触发：`lib/services/reminder_service.dart:186-250` (`_onTick`)
- 弹出通知：`lib/services/reminder_service.dart:252-268` (`_showWindowsNotification`)

### 应用启动时恢复调度

```
应用启动
    ↓
AppBootstrapGate._bootstrap()（lib/main.dart:198-204）
    ↓
ref.read(reminderProvider) 触发 ReminderNotifier 构造
    ↓
loadReminders()：从 shared_preferences 读取提醒列表
    ↓
遍历启用的提醒逐个 scheduleReminder()
    ↓
注意：历史数据中已过期的单次提醒不会补发（静默跳过）；
在界面上重新保存或开关一次会自动顺延到未来；
Android 端还依赖 Manifest 中的 ScheduledNotificationBootReceiver，
用于设备重启或应用更新后由插件恢复已注册的系统提醒
```

**代码位置**：
- 启动引导：`lib/main.dart:198-204` (`_bootstrap`)
- 恢复调度：`lib/providers/reminder_provider.dart:47-68` (`loadReminders`)

## 独立笔记窗口数据流（仅 Windows 桌面端）

独立窗口运行在单独的 Flutter 引擎/isolate 中，与主窗口不共享内存状态。**主窗口是唯一数据权威**：子窗口不直接读写 shared_preferences（两引擎缓存独立，直接写会整表覆盖），所有变更经窗口间 method channel 回流主窗口统一持久化。

### 拖出与打开

```
用户拖出 txt / Markdown 笔记卡片（或右键「在新窗口打开」）
    ↓
NoteWindowService.openNoteWindow(note)
    ├─> 已有该笔记窗口且存活：聚焦既有窗口，结束
    └─> DesktopMultiWindow.createWindow(json{noteId, title, content, format})
            ↓
        新 Flutter 引擎以 ['multi_window', windowId, args] 重新执行 main()
            ↓
        main() 检测到 multi_window 参数 → runApp(NoteWindowApp)
            ↓
        NoteWindowEditorPage 用参数中的 title/content/format 初始化编辑器
        （Markdown 默认进入预览，切换编辑后显示 Markdown 工具栏）
            ↓
        主窗口记录 noteId → windowId 映射，externallyOpenNotesProvider 加入该 noteId
            ↓
        主窗口编辑器（若打开同一笔记）进入只读模式
```

### 子窗口编辑回传

```
用户在独立窗口输入
    ↓
TextField onChanged
    ↓
DesktopMultiWindow.invokeMethod(0, 'noteWindow.update', {noteId, title, content})
    ↓                                    （0 = 主窗口 windowId）
主窗口 NoteWindowService 的 method handler
    ↓
NotesViewModel.updateNote()（更新时间戳、置 syncStatus=local、提取标签）
    ↓
更新主窗口内存状态（notesProvider）→ 保存到 shared_preferences
    ↓
主窗口列表/只读编辑器经 provider 监听实时镜像刷新
```

> ⚠️ **原生注册陷阱（务必遵守）**：上面这条回传链路依赖**子窗口引擎的事件通道**（`mixin.one/flutter_multi_window_channel`）始终有效。`windows/runner/main.cpp` 的 `DesktopMultiWindowSetWindowCreatedCallback` **绝不能**对子窗口调用完整的 `RegisterPlugins()`——那会重新执行 desktop_multi_window 自身的注册（用 windowId 0 重注册事件通道，又因主窗口已存在而在析构时把该通道 handler 置空），导致子窗口通道失效。此后 `invokeMethod(0, ...)` 抛 `MissingPluginException`（注意它**不是** `PlatformException` 的子类），编辑无法回传主窗口，且若捕获不当会**静默丢失**。子窗口只应按需逐个注册真正用到的插件；当前仅额外注册 `window_manager`，用于独立窗口的桌面置顶与透明度调整。

### 窗口关闭与对账

```
主窗口 2 秒周期轮询（仅存在独立窗口时运行）
    ↓
NoteWindowService._reconcile()
    ├─> getAllSubWindowIds() 对账：窗口已被用户关闭 → 移除映射，
    │   externallyOpenNotesProvider 移除该 noteId → 主窗口编辑器解除只读并加载最新内容
    └─> 笔记已在主窗口被删除 → 主动 close 对应子窗口（孤儿窗口清理）
```

**代码位置**：
- 窗口管理与 IPC handler：`lib/services/note_window_service.dart`
- 子窗口入口分流：`lib/main.dart`（`main` 函数开头）
- 子窗口编辑器：`lib/pages/note_window_page.dart`
- 拖出交互：`lib/pages/notes_page.dart`（`_buildDraggableCard`、`_showNoteContextMenu`）
- 主窗口只读保护：`lib/pages/editor_page.dart`（`_buildDetachedBanner`、`_isDetached`）

**边界情况**：
- 独立窗口打开期间执行全量同步：远程内容按现有 importNote 规则写入主窗口状态，独立窗口不感知，继续编辑以"最后写入者胜"回写
- 主窗口经托盘「退出」：进程结束，所有独立窗口随之关闭；已输入内容因每次 onChanged 实时回传，不会丢失
- 主窗口最小化到托盘：isolate 仍运行，独立窗口编辑与保存不受影响

## 本地存储机制

使用 `shared_preferences` 存储 JSON 格式数据：

### 笔记存储

**Key**: `notes`
**格式**:
```json
[
  {
    "id": "uuid",
    "title": "笔记标题",
    "content": "笔记正文",
    "category": "分类",
    "tags": ["tag1", "tag2"],
    "createdAt": "ISO8601时间",
    "updatedAt": "ISO8601时间",
    "filePath": "notes/category/uuid.md",
    "sha": "git-sha-hash",
    "syncStatus": "synced|local|conflict"
  }
]
```

### 同步 base 快照存储（v2）

**Key**: `gitnote_sync_base`
**格式**:
```json
[
  {
    "key": "笔记身份键（md=front-matter id；txt=远端路径）",
    "path": "上次共识时的远端路径",
    "blobSha": "共识版本的 git blob sha",
    "content": "共识版本全文（三方合并的 base 输入）",
    "syncedAt": "ISO8601 时间（UTC）"
  }
]
```

> base 表记录「每篇笔记上次同步成功时双方共识的版本」，是判定拉/推/合并与识别删除的依据（见 [同步策略设计](./sync-design.md) §9.1）。与笔记表分开存储：清空 base 等价于「忘记同步历史」，下轮同步按迁移路径重新对齐，不影响笔记数据本身。base 表损坏时按空表处理（引擎走「合成 base」重新对齐），不丢笔记。

### Git 配置存储

**Key**: `git_config`
**格式**:
```json
{
  "platform": "github|gitee",
  "owner": "用户名",
  "repo": "仓库名",
  "branch": "分支名",
  "token": "access_token",
  "lastSyncTime": "ISO8601时间"
}
```

### 提醒存储

**Key**: `reminders`
**格式**:
```json
[
  {
    "id": "uuid",
    "title": "提醒标题",
    "time": "ISO8601时间（时刻型为触发时间；interval 型为计时锚点）",
    "repeat": "none|daily|weekly|monthly|weekdays|interval|custom",
    "intervalMinutes": 60,
    "enabled": true,
    "createdAt": "ISO8601时间",
    "updatedAt": "ISO8601时间"
  }
]
```

> `intervalMinutes` 仅 `repeat == "interval"` 时写入（间隔分钟数，≥ 1），其余类型省略该字段；旧版本数据无此字段，反序列化为 `null`，向后兼容。

**代码位置**：
- 笔记存储：`lib/data/services/storage_service.dart`
- Git 配置存储：`lib/data/repositories/git_config_repository.dart`
- 提醒存储：`lib/services/reminder_service.dart:88-105`（`loadReminders`, `saveReminders`）、模型序列化 `lib/domain/models/reminder.dart:77-104`

## 冲突处理（v2）

同步引擎对每篇笔记按「base 快照 / 本地相对 base / 远端相对 base」三方判定（判定表见 [同步策略设计 §6.2](./sync-design.md)）。当本地与远端都相对 base 发生改动（分叉，判定表规则 4）时进入冲突处理。

> ⚠️ **冲突策略正在切换（2026-07-06 定稿，代码待跟进）**：设计已将冲突处理从「diff3 自动合并 + 冲突副本」简化为**用户二选一**——弹窗展示本地与远端最后更新时间，用户选「保留本地」或「用远程覆盖」，取消则跳过该篇（详见 [同步策略设计 §7](./sync-design.md)）。下方描述的是**当前 M3 代码的实际行为**（diff3 + 冲突副本），将在 M4 落地二选一时替换。

**当前 M3 代码行为**：

1. **diff3 行级自动合并**（`lib/data/sync/diff3.dart`）：以 base 为共同祖先合并双方改动。改动不重叠 → 干净合并，合并结果同时落盘并推送远端，无需用户介入。
2. **冲突副本**（`SyncEngine._applyMerge` 合并失败分支）：改动重叠无法自动合并时，正身采纳远端版本，本地版另存为一篇新笔记（新 id、追加 `conflict` 标签、标题带「（冲突 时间 @设备）」），置为 `local` 状态，下一轮会话自动推送到远端。

**M4 目标行为**（二选一）：分叉时不自动合并、不生成副本，逐篇弹窗展示双方最后更新时间，用户裁决保留本地或用远程覆盖；取消则保持本地不动、跳过该篇，下次同步再次提示。

> 关键原则（两种策略共通）：v2 **绝不静默覆盖**用户数据。删除让位于修改（判定表规则 7/8）——本地删 + 远端改会把远端版恢复到本地并提示，不自动重删。

**代码位置**：
- 三方判定：`lib/data/sync/sync_planner.dart`（`planSync`）
- 冲突处理（§7 二选一）：`lib/data/sync/sync_engine.dart`（`resolveConflicts`）、`lib/ui/widgets/conflict_resolution_dialog.dart`
- 冲突标签常量：`lib/data/sync/sync_engine.dart`（`kConflictTag`，保留用于向前兼容）

## 相关文档

- [架构设计](./architecture.md) - 整体架构说明
- [核心功能](./features.md) - 功能详细说明
- [API 文档](./api.md) - Git 平台 API 调用说明
- [同步策略设计 v2](./sync-design.md) - 同步机制完整设计
