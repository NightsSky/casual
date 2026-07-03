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

### 主界面/全量同步（Push local then Pull）

```
用户点击同步按钮
    ↓
检查 Git 配置是否完整
    ↓
显示加载进度弹窗
    ↓
GitViewModel.fullSync()
    ├─> 读取 syncStatus=local 的本地笔记快照
    ├─> 逐条调用 GitHubService/GiteeService.getFileSha() 查询远程 sha
    ├─> sha 无冲突后调用 GitHubService/GiteeService.createOrUpdateFile()
    ├─> 推送成功后 NotesViewModel.markSynced() 写回 filePath/sha/synced
    ├─> 本地推送全部完成后调用 GitHubService/GiteeService.listFiles()
    ├─> 下载远程最新文件内容
    └─> 返回远程最新笔记列表
            ↓
遍历每条远程笔记
    ↓
NotesViewModel.importNote()
    ├─> 比对本地是否存在（基于 filePath）
    ├─> 如果本地不存在：直接导入
    ├─> 如果本地存在：
    │       ├─> 本地仍为 local 且远程内容不同：标记为冲突（conflict），保留本地内容
    │       └─> 本地已同步或远程版本更新：写入远程最新内容和 sha
    └─> 保存到本地存储
            ↓
关闭进度弹窗
    ↓
显示同步成功提示
```

**代码位置**：
- UI 触发：`lib/pages/notes_page.dart:368-422` (`_handleSync`)
- 同步顺序：`lib/ui/features/git/view_models/git_view_model.dart:152-176` (`fullSync`)
- 远程导入：`lib/ui/features/notes/view_models/notes_view_model.dart:269-350` (`importNote`)
- API 调用：`lib/data/repositories/git_sync_repository.dart:111-169` (`pushNote`), `lib/data/services/github_service.dart:26-61` (`listFiles`), `lib/data/services/github_service.dart:63-88` (`getFileContent`)

### 单条推送（Push）

```
用户在编辑页选择"同步到远程"
    ↓
EditorPage._saveNote() 保存最新内容
    ↓
显示加载进度弹窗
    ↓
GitViewModel.pushNote(note)
    ├─> 如果笔记已有 filePath：
    │       ├─> 调用 GitHubService.getFileSha() 查询远程 SHA
    │       ├─> 如果远程存在且 SHA 不同：抛出冲突异常
    │       └─> 调用 GitHubService.createOrUpdateFile() 更新
    └─> 如果笔记无 filePath（首次推送）：
            ├─> 生成文件路径（notes/{category}/{uuid}.md）
            └─> 调用 GitHubService.createOrUpdateFile() 创建
                    ↓
返回 {filePath, sha}
    ↓
NotesViewModel.markSynced(noteId, filePath, sha)
    ├─> 更新笔记的 filePath 和 sha 字段
    ├─> 同步状态改为 synced
    └─> 保存到本地存储
            ↓
关闭进度弹窗
    ↓
显示同步成功提示
```

**代码位置**：
- UI 触发：`lib/pages/editor_page.dart:458-473` (菜单选择 'sync')
- 同步逻辑：`lib/pages/editor_page.dart:475-536` (`_syncNote`)
- API 调用：`lib/data/services/github_service.dart:90-122` (`createOrUpdateFile`)
- 标记已同步：通过 `notesProvider.notifier.markSynced`

### 远程删除

```
用户删除笔记
    ↓
显示确认对话框
    ↓
用户确认
    ↓
NotesViewModel.deleteNoteWithRemote(noteId, deleteRemote)
    ├─> 调用 deleteRemote 回调函数
    │       ↓
    │   GitViewModel.deleteRemoteNote(filePath, sha)
    │       ↓
    │   GitHubService.deleteFile()
    │       ↓
    └─> 远程删除成功后
            ↓
NotesViewModel.deleteNote(noteId)
    ↓
从本地移除
```

**代码位置**：
- 删除逻辑：`lib/pages/notes_page.dart:264-291` (`_deleteNote`)
- ViewModel：`lib/providers/notes_provider.dart` (`deleteNoteWithRemote`)
- API 调用：`lib/data/services/github_service.dart:145-168` (`deleteFile`)

## 提醒数据流

### 创建/编辑提醒

```
用户在提醒页点击 + / 点击提醒卡片
    ↓
_ReminderDialog 填写标题、时间、重复方式
（重复方式选「按间隔」时改为选择小时/分钟间隔，不再选择时刻）
    ↓
单次提醒若所选时分已过：自动顺延到明天同一时间；
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
        ├─> 时刻型：flutter_local_notifications.zonedSchedule() 注册系统调度
        └─> interval 型：periodicallyShowWithDuration() 注册系统周期通知
```

**代码位置**：
- UI 触发：`lib/pages/reminder_page.dart:427` (`_saveReminder`)、间隔选择器 `lib/pages/reminder_page.dart:355` (`_buildIntervalPicker`)
- 过期顺延/锚点重置：`lib/domain/models/reminder.dart:63-75` (`rescheduledIfExpired`)
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
    ├─> local_notifier 弹出系统 Toast（「GitNote 助手」+ 提醒标题）
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
在界面上重新保存或开关一次会自动顺延到未来
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

## 冲突处理

当本地笔记与远程笔记的 SHA 值不一致时，标记为冲突状态：

1. **全量同步时**：远程 SHA ≠ 本地 SHA → 标记为 `conflict`
2. **单条推送时**：远程 SHA ≠ 本地 SHA → 抛出异常，推送失败

**未来改进方向**：
- 提供冲突解决界面（选择保留本地/远程/合并）
- 支持三方合并算法
- 显示差异对比

## 相关文档

- [架构设计](./architecture.md) - 整体架构说明
- [核心功能](./features.md) - 功能详细说明
- [API 文档](./api.md) - Git 平台 API 调用说明
