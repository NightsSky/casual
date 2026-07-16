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
- UI 触发：`lib/pages/editor_page.dart` (content)
- 保存逻辑：`lib/pages/editor_page.dart:79-91` (`_saveNote`)
- ViewModel：`lib/providers/notes_provider.dart` (`updateNote`)

> **txt 标题派生**：txt 笔记无独立标题字段，编辑器不显示标题输入框。
> `updateNote` / `createNote` 对 txt 始终从正文首行派生 `Note.title`（首个非空行、
> 截断 80 字符，`deriveTxtTitle`，见 `lib/utils/markdown_utils.dart`），忽略调用方
> 传入的 title；Markdown 仍沿用显式标题。派生标题用于列表卡片显示与同步文件名
> 分配（`allocatePath`），空内容回退为「无标题」文案 / `untitled` 文件名。独立窗口
> 回传主窗口的 title 对 txt 无效（主窗口按正文重新派生）。

### 打开与保存外部 Markdown 文件（Windows）

外部电脑文件和应用笔记是两条隔离的数据流，避免外部绝对路径被错误当成 Git 仓库相对路径：

```text
笔记列表顶栏「打开 Markdown 文件」
    ↓
ExternalMarkdownFileService.pickMarkdownFile()
    ↓
file_selector 系统文件选择器（.md / .markdown / .mdown / .mkdn）
    ↓
读取完整原文，作为 ExternalMarkdownFile(path, content)
    ↓
路由 /external-markdown（route extra）
    ↓
ExternalMarkdownPage 的独立 TextEditingController
    ├─> 编辑 / 分屏实时预览 / 仅预览 / 专注视图
    └─> Ctrl+S 或保存按钮
            ↓
        ExternalMarkdownFileService.saveMarkdownFile()
            ↓
        File.writeAsString(选择时的原路径)
```

该路径**不经过** `NotesNotifier.createNote/updateNote`、`shared_preferences`、`note_file_codec` 或 `SyncEngine`：不会写入 `notesProvider`，不会被 GitHub/Gitee 同步，也不会追加或剥离 YAML front matter。预览路径会剥离 front matter 后的正文，并以原文件目录解析相对图片；保存路径始终写回完整原文。保存失败时编辑器保留当前内容并提示错误；退出时如果仍有未保存修改，用户可选择继续编辑或放弃。Android/iOS 以只读预览降级，避免系统文件授权失效时把修改错误写入临时副本。

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
    ├─> ReminderService.windowsAlarmStream 发出提醒事件
    ├─> ReminderAlarmHost 优先创建右下角独立提醒小窗口（主窗口不恢复到前台）
    ├─> 展示钉钉风格提醒卡片（内容 = 提醒标题）
    ├─> 子窗口不可用时回退到主窗口 Dialog，避免提醒丢失
    └─> 计算下一次触发时间
            ├─> 有下次（重复提醒）：更新内存表
            └─> 无下次（单次提醒）：从内存表移除，表空则停止 Timer
```

**代码位置**：
- 轮询与触发：`lib/services/reminder_service.dart:186-250` (`_onTick`)
- 弹窗调度：`lib/widgets/reminder_alarm_host.dart` (`ReminderAlarmHost`)
- 独立提醒窗口：`lib/services/reminder_alarm_window_service.dart`、`lib/pages/reminder_alarm_window_page.dart`

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

Markdown 子窗口默认采用编辑/预览分屏：左侧 `TextField` 和右侧 `MarkdownPreview` 共享同一 controller。输入触发 `_pushUpdate()` 时先刷新子窗口的预览，再经 `noteWindow.update` 回传主窗口；因此无论用户停留在仅编辑、分屏或仅预览，内容都沿用同一条 IPC 持久化链路。

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
        主窗口编辑器（若打开同一笔记）进入只读占位模式
        仅显示"此笔记正在独立窗口中编辑，此处为只读"与"聚焦窗口"
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
主窗口列表经 provider 监听刷新，主窗口编辑器只更新缓存，不展示预览或编辑界面
```

> txt 笔记无独立标题：子窗口回传的 `title` 对 txt 无效，主窗口 `updateNote()` 一律按正文首行重新派生标题（`deriveTxtTitle`）。子窗口 txt 标题行也只读展示派生结果，不提供标题输入框。

> ⚠️ **原生注册陷阱（务必遵守）**：上面这条回传链路依赖**子窗口引擎的事件通道**（`mixin.one/flutter_multi_window_channel`）始终有效。`windows/runner/main.cpp` 的 `DesktopMultiWindowSetWindowCreatedCallback` **绝不能**对子窗口调用完整的 `RegisterPlugins()`——那会重新执行 desktop_multi_window 自身的注册（用 windowId 0 重注册事件通道，又因主窗口已存在而在析构时把该通道 handler 置空），导致子窗口通道失效。此后 `invokeMethod(0, ...)` 抛 `MissingPluginException`（注意它**不是** `PlatformException` 的子类），编辑无法回传主窗口，且若捕获不当会**静默丢失**。子窗口只应按需逐个注册真正用到的插件；当前仅额外注册 `window_manager`，用于独立窗口隐藏原生标题栏、窗口控制、桌面置顶与透明度调整。

### 窗口关闭与对账

```
主窗口 2 秒周期轮询（仅存在独立窗口时运行）
    ↓
NoteWindowService._reconcile()
    ├─> getAllSubWindowIds() 对账：窗口已被用户关闭 → 移除映射，
    │   externallyOpenNotesProvider 移除该 noteId → 主窗口编辑器解除只读占位并加载最新内容
    └─> 笔记已在主窗口被删除 → 主动 close 对应子窗口（孤儿窗口清理）
```

**代码位置**：
- 窗口管理与 IPC handler：`lib/services/note_window_service.dart`
- 子窗口入口分流：`lib/main.dart`（`main` 函数开头）
- 子窗口编辑器：`lib/pages/note_window_page.dart`
- 拖出交互：`lib/pages/notes_page.dart`（`_buildDraggableCard`、`_showNoteContextMenu`）
- 主窗口只读保护：`lib/pages/editor_page.dart`（`_buildDetachedNotice`、`_isDetached`）

**边界情况**：
- 独立窗口打开期间执行全量同步：远程内容按现有 importNote 规则写入主窗口状态，独立窗口不感知，继续编辑以"最后写入者胜"回写
- 主窗口经托盘「退出」：进程结束，所有独立窗口随之关闭；已输入内容因每次 onChanged 实时回传，不会丢失
- 主窗口最小化到托盘：isolate 仍运行，独立窗口编辑与保存不受影响

## 计划数据流

### 创建与编辑多步骤计划

```text
用户填写计划标题、目标、开始时间和有序步骤
    ↓
每个步骤填写标题、预计完成时间和独立提醒（新建步骤默认到期时提醒）
    ↓
Plan.validateSteps() 校验至少一步、时间不早于开始且按顺序非递减
    ↓
Plan.create() / Plan.updatePlan()
    ↓
写入 created / detailsUpdated / stepsUpdated 执行动态
    ↓
PlanNotifier 持久化包含 steps 的完整计划快照
    ↓
为每个开启提醒且未完成的步骤注册 plan-{planId}-step-{stepId} 通知
    ↓
Riverpod 刷新列表、自动进度、步骤时间轴和执行动态
```

`Plan.progress` 由已完成步骤数量自动计算，`Plan.deadline` 取最后步骤预计完成时间，两者不单独持久化。应用启动时 `AppBootstrapGate` 初始化 `planProvider`，恢复所有仍有效的步骤提醒。

Windows 调度同时在 `_nextFireAt` 和 `_scheduledReminders` 中保存触发点与完整提醒载荷。计划步骤提醒不进入普通 `reminders` 存储，轮询到点时优先读取内存载荷并通过 `windowsAlarmStream` 发送弹窗事件；选择当前分钟时按当前时间后 10 秒注册，避免分钟选择器产生的时间已经过期。

### 完成、撤销和终止

```text
完成任意步骤
    ↓
Plan.completeStep(stepId, note)
    ↓
记录 completedAt、完成说明和 stepCompleted 动态
    ↓
取消该步骤提醒并重新计算整体进度
    ↓
全部步骤完成 → lifecycle=completed + completed 动态

撤销步骤完成
    ↓
Plan.reopenStep(stepId)
    ↓
清除完成时间和说明，写入 stepReopened 动态
    ↓
计划恢复 active，并按有效时间重新注册步骤提醒

终止计划
    ↓
保留步骤状态和执行动态，lifecycle=terminated
    ↓
取消该计划全部步骤提醒
```

步骤允许跳步完成。早期步骤达到预计时间后只计算为步骤逾期；只有到最后步骤时间仍未完成时，计划整体才进入已逾期状态。删除步骤会取消其提醒，最后一个步骤由领域层禁止删除。

### 第一版数据迁移

旧 JSON 没有 `steps` 时，`Plan.fromJson()` 创建确定标识的单个迁移步骤：标题取原目标、预计完成时间取原截止时间、提醒继承原计划提醒。原生命周期为完成时迁移步骤同步完成；原手动百分比写入 `stepsUpdated` 迁移动态，避免信息静默丢失。 `PlanNotifier` 恢复迁移数据时会取消第一版 `plan-{id}` 整体提醒，再注册 `plan-{planId}-step-{stepId}` 步骤提醒。

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

### 计划存储

**Key**: `gitnote_plans`

计划使用内嵌有序步骤保存，进度和最终截止时间由步骤实时派生：

```json
[
  {
    "id": "uuid",
    "title": "实施项目",
    "goal": "完成项目交付",
    "startAt": "ISO8601时间",
    "steps": [
      {
        "id": "uuid",
        "title": "完成项目创建",
        "targetAt": "ISO8601时间",
        "reminderEnabled": true,
        "reminderMinutesBefore": 60,
        "completedAt": "ISO8601时间或省略",
        "completionNote": "步骤完成说明或省略"
      }
    ],
    "lifecycle": "active|completed|terminated",
    "createdAt": "ISO8601时间",
    "updatedAt": "ISO8601时间",
    "endedAt": "ISO8601时间或省略",
    "timeline": [
      {
        "id": "uuid",
        "type": "created|detailsUpdated|stepsUpdated|stepCompleted|stepReopened|recordAdded|completed|terminated",
        "occurredAt": "ISO8601时间",
        "stepId": "关联步骤 id 或省略",
        "stepTitle": "动作发生时的步骤标题或省略",
        "note": "可选说明",
        "progress": 60
      }
    ]
  }
]
```

读取时单条损坏计划会被跳过，其余计划继续恢复；第一版顶层 `deadline`、`progress` 和提醒字段只用于兼容迁移，新版本保存不再写入这些派生或废弃字段。

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

## 应用内更新数据流

```
启动就绪 / 手动点击「检查更新」
  └─ updateProvider.checkForUpdate()
      └─ UpdateService.checkForUpdate()
          ├─ package_info_plus 读取当前版本
          └─ GET .../releases/latest → AppRelease.fromJson
      └─ AppRelease.isNewerVersion(远端 tag, 当前版本)
          ├─ true  → phase=available，弹出 UpdateDialog
          └─ false → phase=upToDate（静默检查则回到 idle）

用户点击「下载并安装」
  └─ updateProvider.download()
      └─ AppRelease.assetForPlatform() 选平台资产
      └─ UpdateService.downloadAsset(onProgress) 流式写入本地文件
          └─ phase=downloading（进度回传）→ readyToInstall

用户点击「立即安装」
  └─ UpdateService.installDownloadedFile()
      └─ open_filex 调起系统安装器（Android APK / Windows exe）
         或资源管理器打开 zip
```

- **单向、无持久化**：更新状态仅存于内存（`updateProvider`），不落 SharedPreferences；关闭对话框即 `reset()`。
- **失败降级**：无平台匹配资产或 `supportsInAppDownload` 为假时，改用 `url_launcher` 打开 Release 页面。
- **静默检查**：`main.dart` 启动检查失败不打扰用户（回到 `idle`），仅手动检查才展示错误。

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
