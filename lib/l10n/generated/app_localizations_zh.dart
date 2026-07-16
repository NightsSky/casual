// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'casual';

  @override
  String get notes => '笔记';

  @override
  String get search => '搜索';

  @override
  String get repository => '仓库';

  @override
  String get plan => '计划';

  @override
  String get settings => '设置';

  @override
  String get versionLabel => 'v0.1.0';

  @override
  String get untitledNote => '无标题笔记';

  @override
  String get uncategorized => '未分类';

  @override
  String get newNote => '新笔记';

  @override
  String get edit => '编辑';

  @override
  String get preview => '预览';

  @override
  String get openMarkdownFile => '打开 Markdown 文件';

  @override
  String get markdownEditOnly => '仅编辑';

  @override
  String get markdownSplitView => '编辑与预览分屏';

  @override
  String get markdownPreviewOnly => '仅预览';

  @override
  String get showMarkdownToolbar => '显示格式工具栏';

  @override
  String get hideMarkdownToolbar => '隐藏格式工具栏';

  @override
  String get enterMarkdownFocus => '全屏编辑/预览';

  @override
  String get exitMarkdownFocus => '退出全屏编辑/预览';

  @override
  String get saveMarkdownFile => '保存（Ctrl+S）';

  @override
  String get externalMarkdownReadOnly =>
      '当前平台以只读方式打开外部 Markdown 文件；请在 Windows 桌面端编辑并保存原文件。';

  @override
  String get externalMarkdownContentHint => 'Markdown 内容';

  @override
  String get externalMarkdownSaved => '已保存到原 Markdown 文件';

  @override
  String externalMarkdownSaveFailed(String error) {
    return '保存 Markdown 文件失败：$error';
  }

  @override
  String externalMarkdownOpenFailed(String error) {
    return '打开 Markdown 文件失败：$error';
  }

  @override
  String get discardUnsavedChangesTitle => '放弃未保存的修改？';

  @override
  String get discardExternalMarkdownMessage => '这篇外部 Markdown 文件尚未保存到电脑。';

  @override
  String get continueEditing => '继续编辑';

  @override
  String get discardChanges => '放弃修改';

  @override
  String get missingExternalMarkdown => '未选择要打开的 Markdown 文件';

  @override
  String get syncToRemote => '同步到远程';

  @override
  String get manageTags => '管理标签';

  @override
  String get exportMarkdown => '导出 Markdown';

  @override
  String get deleteNote => '删除笔记';

  @override
  String get enterTitle => '输入标题...';

  @override
  String get addTag => '添加标签';

  @override
  String get addTagButton => '+ 标签';

  @override
  String get enterTagName => '输入标签名称';

  @override
  String get cancel => '取消';

  @override
  String get add => '添加';

  @override
  String get startWriting => '开始写笔记... (支持 Markdown)';

  @override
  String wordCountFooter(int count, String time) {
    return '$count 字 · $time';
  }

  @override
  String get configureGitFirst => '请先配置 Git';

  @override
  String get syncSuccess => '同步完成';

  @override
  String syncFailedMessage(String error) {
    return '同步失败: $error';
  }

  @override
  String deleteFailedMessage(String error) {
    return '删除失败: $error';
  }

  @override
  String get markdownReady => 'Markdown 内容已准备好导出';

  @override
  String get confirmDelete => '确认删除';

  @override
  String confirmDeleteNote(String title) {
    return '确定要删除「$title」吗？';
  }

  @override
  String get delete => '删除';

  @override
  String get all => '全部';

  @override
  String get noNotesYet => '还没有笔记';

  @override
  String get createFirstNote => '点击右下角 + 创建第一篇笔记';

  @override
  String get pin => '置顶';

  @override
  String get localStatus => '本地';

  @override
  String get conflictStatus => '冲突';

  @override
  String get noContent => '暂无内容';

  @override
  String get sortByUpdated => '最近更新';

  @override
  String get sortByCreated => '创建时间';

  @override
  String get sortByTitle => '标题排序';

  @override
  String get syncInProgress => '同步中...';

  @override
  String get syncFailedShort => '同步失败';

  @override
  String lastSyncedAt(String date) {
    return '上次同步: $date';
  }

  @override
  String get neverSynced => '未同步';

  @override
  String get repositoryManagement => '仓库管理';

  @override
  String get repositoryManagementDescription => '同步笔记、查看同步统计与记录';

  @override
  String get notConnected => '未连接';

  @override
  String get connected => '已连接';

  @override
  String get configureGitPlatformInSettings => '请先在设置中配置 Git 平台';

  @override
  String get quickActions => '快捷操作';

  @override
  String get syncStats => '同步统计';

  @override
  String get syncLogs => '同步记录';

  @override
  String get pullRemote => '拉取远程';

  @override
  String get pushLocal => '推送本地';

  @override
  String get fullSync => '全量同步';

  @override
  String get repositorySettings => '仓库设置';

  @override
  String get totalNotes => '总笔记';

  @override
  String get unsyncedNotes => '未同步';

  @override
  String get syncedNotes => '已同步';

  @override
  String get conflicts => '冲突';

  @override
  String get syncConflictTitle => '同步冲突';

  @override
  String get syncConflictLocalTime => '本地版本';

  @override
  String get syncConflictRemoteTime => '远程版本';

  @override
  String get syncConflictTimeUnknown => '时间未知';

  @override
  String get syncConflictDescription => '本地与远程都修改了这篇笔记，请选择保留哪个版本。';

  @override
  String get syncConflictKeepLocal => '保留本地';

  @override
  String get syncConflictTakeRemote => '用远程覆盖';

  @override
  String get noSyncLogs => '暂无同步记录';

  @override
  String pulledRemoteNotes(int count) {
    return '成功拉取 $count 篇远程笔记';
  }

  @override
  String pushSummary(int successCount, int totalCount) {
    return '成功推送 $successCount/$totalCount 篇笔记';
  }

  @override
  String fullSyncSummary(int count) {
    return '全量同步完成，拉取 $count 篇远程笔记';
  }

  @override
  String get searchNotes => '搜索笔记...';

  @override
  String get enterKeywordToSearch => '输入关键词搜索笔记';

  @override
  String get recentSearches => '最近搜索';

  @override
  String get clear => '清空';

  @override
  String get noSearchResults => '未找到相关笔记';

  @override
  String searchResultsCount(int count) {
    return '$count 条结果';
  }

  @override
  String get gitPlatformConfig => 'Git 平台配置';

  @override
  String get gitPlatformConfigDescription => '配置 GitHub 或 Gitee 连接信息';

  @override
  String get platform => '平台';

  @override
  String get accessToken => 'Access Token';

  @override
  String get enterToken => '请输入 Token';

  @override
  String get ownerOrOrg => '用户名/组织';

  @override
  String get ownerHint => '例如: username';

  @override
  String get repoName => '仓库名';

  @override
  String get repoHint => '例如: my-notes';

  @override
  String get branch => '分支';

  @override
  String get branchHint => '默认: main';

  @override
  String get notesDirectory => '笔记目录';

  @override
  String get notesDirectoryHint => '默认: notes';

  @override
  String get testConnection => '测试连接';

  @override
  String get connectedShort => '已连接';

  @override
  String get saveConfig => '保存配置';

  @override
  String get syncSettings => '同步设置';

  @override
  String get autoSync => '自动同步';

  @override
  String get autoSyncDescription => '打开应用时自动拉取远程笔记';

  @override
  String get autoPush => '编辑时自动推送';

  @override
  String get autoPushDescription => '保存笔记后自动推送到远程';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get checkForUpdate => '检查更新';

  @override
  String get checkingForUpdate => '正在检查更新...';

  @override
  String get updateAvailable => '发现新版本';

  @override
  String get upToDate => '已是最新版本';

  @override
  String updateNewVersion(String version) {
    return '版本 $version';
  }

  @override
  String updateCurrentVersion(String version) {
    return '当前版本 $version';
  }

  @override
  String get updateReleaseNotes => '更新说明';

  @override
  String get updateDownloadInstall => '下载并安装';

  @override
  String get updateDownloading => '正在下载...';

  @override
  String get updateInstallNow => '立即安装';

  @override
  String get updateOpenReleasePage => '打开发布页面';

  @override
  String get updateCheckFailed => '检查更新失败';

  @override
  String get updateLater => '稍后';

  @override
  String get updateWindowsZipHint => '下载完成后，请解压压缩包并覆盖现有应用文件。';

  @override
  String get clearAllData => '清除所有数据';

  @override
  String get choosePlatform => '选择平台';

  @override
  String get saved => '已保存';

  @override
  String get connectionSuccess => '连接成功';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get warning => '警告';

  @override
  String get clearAllConfirm => '确定要清除所有本地数据吗？此操作不可恢复。';

  @override
  String get cleared => '已清除';

  @override
  String get loading => '加载中...';

  @override
  String get tokenHelpTitle => 'Access Token 帮助';

  @override
  String get tokenHelpButton => '如何获取 Access Token';

  @override
  String get tokenHelpIntro =>
      'casual 需要 Access Token 读取和更新你配置的笔记仓库。建议只给当前笔记仓库授权，并把 token 当作密码保管。';

  @override
  String get githubTokenTitle => 'GitHub 获取方式';

  @override
  String get githubTokenStep1 => '打开 GitHub，点击右上角头像，进入 Settings。';

  @override
  String get githubTokenStep2 =>
      '进入 Developer settings > Personal access tokens > Fine-grained tokens。';

  @override
  String get githubTokenStep3 =>
      '点击 Generate new token，填写 Token name 和 Expiration。';

  @override
  String get githubTokenStep4 => 'Repository access 选择 casual 使用的仓库。';

  @override
  String get githubTokenStep5 =>
      '在 Repository permissions 中将 Contents 设置为 Read and write，然后生成并复制 token。';

  @override
  String get githubClassicTokenTip =>
      '如果使用 classic token，请勾选 repo 权限；细粒度 token 更适合只授权单个笔记仓库。';

  @override
  String get githubTokenOfficialEntrance =>
      '官方入口：https://github.com/settings/personal-access-tokens';

  @override
  String get giteeTokenTitle => 'Gitee 获取方式';

  @override
  String get giteeTokenStep1 => '打开 Gitee，点击右上角头像，进入设置。';

  @override
  String get giteeTokenStep2 => '进入 安全设置 > 私人令牌，点击生成新令牌。';

  @override
  String get giteeTokenStep3 => '填写私人令牌描述，并设置合适的过期时间。';

  @override
  String get giteeTokenStep4 => '勾选 project 权限，用于读取、创建和更新笔记仓库文件。';

  @override
  String get giteeTokenStep5 => '点击提交，完成登录密码校验后复制生成的私人令牌。';

  @override
  String get giteeTokenTip =>
      'Gitee 的私人令牌就是这里要填写的 Access Token；如果仓库属于组织，请确认账号本身有该仓库权限。';

  @override
  String get giteeTokenOfficialEntrance =>
      '官方入口：https://gitee.com/profile/personal_access_tokens';

  @override
  String get tokenSafetyTitle => '保管与填写';

  @override
  String get tokenSafetyBody =>
      'Token 通常只在生成时完整显示一次，请立即复制保存。不要把 token 写进公开笔记、截图或提交记录；如果怀疑泄露，请在平台里删除旧 token 并重新生成。';

  @override
  String get tokenPasteTip => '复制后回到 Git 平台配置页，粘贴到 Access Token，保存配置并测试连接。';

  @override
  String get reminder => '助手';

  @override
  String get reminders => '助手';

  @override
  String get addReminder => '添加助手';

  @override
  String get editReminder => '编辑助手';

  @override
  String get reminderTitle => '标题';

  @override
  String get reminderTime => '提醒时间';

  @override
  String get reminderRepeat => '重复';

  @override
  String get reminderEnabled => '启用';

  @override
  String get reminderNone => '无';

  @override
  String get reminderDaily => '每天';

  @override
  String get reminderWeekly => '每周';

  @override
  String get reminderMonthly => '每月';

  @override
  String get reminderWeekdays => '工作日';

  @override
  String get reminderInterval => '按间隔';

  @override
  String reminderIntervalEvery(String duration) {
    return '每隔 $duration';
  }

  @override
  String durationHours(int count) {
    return '$count 小时';
  }

  @override
  String durationMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String get reminderIntervalHoursLabel => '小时';

  @override
  String get reminderIntervalMinutesLabel => '分钟';

  @override
  String get reminderIntervalHint => '保存后开始计时，按所选间隔重复提醒';

  @override
  String get reminderCustom => '自定义';

  @override
  String get noRemindersYet => '还没有助手';

  @override
  String get createFirstReminder => '点击右上角 + 创建第一个助手';

  @override
  String get deleteReminder => '删除助手';

  @override
  String confirmDeleteReminder(String title) {
    return '确定要删除「$title」吗？';
  }

  @override
  String get reminderSaved => '助手已保存';

  @override
  String reminderSaveFailed(String error) {
    return '助手保存失败：$error';
  }

  @override
  String get enterReminderTitle => '输入标题...';

  @override
  String get reminderAlarmTitle => '提醒时间到';

  @override
  String get reminderAlarmDefaultBody => '该处理这个助手了';

  @override
  String get reminderAlarmSource => '本地助手提醒';

  @override
  String get reminderAlarmLater => '稍后提醒';

  @override
  String get reminderAlarmAcknowledge => '我知道了';

  @override
  String get selectTime => '选择时间';

  @override
  String get save => '保存';

  @override
  String get confirm => '确定';

  @override
  String get windowSettings => '窗口设置';

  @override
  String get closeButtonAction => '关闭主面板时';

  @override
  String get closeActionAsk => '每次询问';

  @override
  String get closeActionMinimize => '最小化到系统托盘';

  @override
  String get closeActionExit => '退出程序';

  @override
  String get closeDialogTitle => '关闭 casual';

  @override
  String get closeDialogMessage => '请选择点击关闭按钮后的操作：';

  @override
  String get closeDialogRemember => '不再询问（可在设置中修改）';

  @override
  String get trayShowWindow => '显示主界面';

  @override
  String get trayExit => '退出';

  @override
  String get openInNewWindow => '在新窗口打开';

  @override
  String get noteDetachedTooltip => '已在独立窗口中打开';

  @override
  String get noteDetachedBanner => '此笔记正在独立窗口中编辑，此处为只读';

  @override
  String get focusNoteWindow => '聚焦窗口';

  @override
  String noteWindowWordCount(int count) {
    return '$count 字';
  }

  @override
  String get noteWindowPinToTop => '置顶在桌面';

  @override
  String get noteWindowUnpinFromTop => '取消桌面置顶';

  @override
  String get noteWindowOpacity => '窗口透明度';

  @override
  String noteWindowOpacityValue(int percent) {
    return '$percent%';
  }

  @override
  String get noteWindowMove => '拖动窗口';

  @override
  String get noteWindowMinimize => '最小化窗口';

  @override
  String get noteWindowMaximize => '最大化窗口';

  @override
  String get noteWindowRestore => '还原窗口';

  @override
  String get noteWindowClose => '关闭窗口';

  @override
  String get noteWindowUnreachable => '无法连接主窗口，当前编辑不会被保存';

  @override
  String get openAsTagWindow => '以标签模式打开';

  @override
  String get noteTagExpand => '展开笔记';

  @override
  String get noteTagCollapse => '收起为标签';

  @override
  String get planPageSubtitle => '把一个目标拆成有序步骤，在清晰的时间轴上逐步推进。';

  @override
  String get createPlan => '新建计划';

  @override
  String get planFilterActive => '进行中';

  @override
  String get planFilterOverdue => '已逾期';

  @override
  String get planFilterCompleted => '已完成';

  @override
  String get planFilterTerminated => '已终止';

  @override
  String get planNoPlansYet => '还没有计划';

  @override
  String get planCreateFirst => '创建一个计划，开始记录目标的推进过程。';

  @override
  String get planSelectPrompt => '选择一个计划查看执行时间轴';

  @override
  String get planTitleLabel => '计划标题';

  @override
  String get planTitleHint => '例如：发布 casual 1.0';

  @override
  String get planGoalLabel => '计划目标';

  @override
  String get planGoalHint => '描述最终希望达成的具体结果';

  @override
  String get planStartAt => '开始时间';

  @override
  String get planDeadline => '截止时间';

  @override
  String get planReminder => '截止提醒';

  @override
  String get planReminderOff => '不提醒';

  @override
  String get planReminderAtDeadline => '截止时提醒';

  @override
  String get planReminderOneHourBefore => '提前 1 小时';

  @override
  String get planReminderOneDayBefore => '提前 1 天';

  @override
  String get planReminderCustom => '自定义';

  @override
  String get planReminderMinutes => '提前分钟数';

  @override
  String get planReminderMinutesHint => '请输入 1 到 525600 之间的分钟数';

  @override
  String get planEdit => '编辑计划';

  @override
  String get planOverview => '计划概览';

  @override
  String get planProgress => '当前进度';

  @override
  String get planTimeline => '执行时间轴';

  @override
  String get planUpdateProgress => '更新进度';

  @override
  String get planAddRecord => '添加记录';

  @override
  String get planComplete => '完成计划';

  @override
  String get planTerminate => '终止计划';

  @override
  String get planDelete => '删除计划';

  @override
  String get planRecordHint => '记录阶段成果、遇到的问题或下一步安排……';

  @override
  String get planProgressNoteHint => '补充本次进度变化的说明（可选）……';

  @override
  String get planOptionalNote => '完成说明（可选）';

  @override
  String get planTerminationReason => '终止原因（可选）';

  @override
  String get planStatusNotStarted => '未开始';

  @override
  String get planStatusInProgress => '进行中';

  @override
  String get planStatusOverdue => '已逾期';

  @override
  String get planStatusCompleted => '已完成';

  @override
  String get planStatusTerminated => '已终止';

  @override
  String get planTimelineCreated => '创建计划';

  @override
  String get planTimelineDetailsUpdated => '更新计划信息';

  @override
  String planTimelineProgress(int progress) {
    return '进度更新至 $progress%';
  }

  @override
  String get planTimelineRecord => '执行记录';

  @override
  String get planTimelineCompleted => '完成计划';

  @override
  String get planTimelineTerminated => '终止计划';

  @override
  String planRemainingDays(int count) {
    return '剩余 $count 天';
  }

  @override
  String planRemainingHours(int count) {
    return '剩余 $count 小时';
  }

  @override
  String get planDueSoon => '即将截止';

  @override
  String planOverdueDays(int count) {
    return '已逾期 $count 天';
  }

  @override
  String get planValidateTitle => '请输入计划标题';

  @override
  String get planValidateGoal => '请输入明确的计划目标';

  @override
  String get planValidateDeadline => '截止时间必须晚于开始时间';

  @override
  String get planValidateReminder => '请输入有效的提醒分钟数';

  @override
  String get planSaveSuccess => '计划已保存';

  @override
  String get planDeleteSuccess => '计划已删除';

  @override
  String planOperationFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get planConfirmComplete => '确认完成该计划吗？完成后进度将自动设为 100%。';

  @override
  String get planConfirmTerminate => '确认终止该计划吗？当前进度和历史记录会被保留。';

  @override
  String planConfirmDelete(String title) {
    return '确定删除“$title”吗？对应时间轴也会一起删除。';
  }

  @override
  String get planRecordRequired => '请输入执行记录';

  @override
  String get planCreatedAt => '创建时间';

  @override
  String get planSteps => '计划步骤';

  @override
  String get planActivity => '执行动态';

  @override
  String get planAddStep => '添加步骤';

  @override
  String get planRemoveStep => '删除步骤';

  @override
  String get planReorderStep => '拖动调整顺序';

  @override
  String planStepNumber(int index) {
    return '第 $index 步';
  }

  @override
  String get planStepTitle => '步骤标题';

  @override
  String get planStepTitleHint => '描述这一步需要达成的结果';

  @override
  String get planStepTarget => '预计完成时间';

  @override
  String planCompletedSteps(int completed, int total) {
    return '已完成 $completed/$total 步';
  }

  @override
  String get planNextStep => '下一步';

  @override
  String get planNoNextStep => '全部步骤已完成';

  @override
  String get planFinalDeadline => '最终截止时间';

  @override
  String get planStepStatusPending => '待完成';

  @override
  String get planStepStatusOverdue => '已逾期';

  @override
  String get planStepStatusCompleted => '已完成';

  @override
  String get planCompleteStep => '完成步骤';

  @override
  String get planReopenStep => '撤销完成';

  @override
  String get planConfirmReopenStep => '确认撤销该步骤的完成状态吗？计划进度和状态将重新计算。';

  @override
  String get planStepCompletionNote => '完成说明（可选）';

  @override
  String planStepCompletedAt(String time) {
    return '完成于 $time';
  }

  @override
  String get planValidateStepTitle => '请填写每个计划步骤的标题';

  @override
  String get planValidateStepBeforeStart => '步骤预计时间不能早于计划开始时间';

  @override
  String get planValidateStepOrder => '后一步预计时间不能早于前一步';

  @override
  String get planAtLeastOneStep => '计划至少需要保留一个步骤';

  @override
  String get planTimelineStepsUpdated => '更新计划步骤';

  @override
  String planTimelineStepCompleted(String step) {
    return '完成步骤：$step';
  }

  @override
  String planTimelineStepReopened(String step) {
    return '撤销步骤完成：$step';
  }

  @override
  String planTimelineLegacyProgress(int progress) {
    return '原计划进度 $progress% 已迁移为计划步骤';
  }
}
