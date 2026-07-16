# Component Spec for Redesign

## App Shell

### Mobile Bottom Navigation

Items:
- 笔记：article icon
- 助手：alarm icon
- 计划：event-note icon
- 设置：settings icon

Rules:
- 编辑器页面隐藏底部导航。
- 当前 Tab 需要有明显激活态。
- 文案最长为 2 个中文字符，英文环境需要支持更长标签。

### Desktop Sidebar

Items:
- App 品牌：casual
- 笔记
- 助手
- 计划
- 设置
- 版本号：v0.1.0

Rules:
- 当前宽度是 240px，可在重设计中调整，但不能影响主区域信息密度。
- 选中笔记或编辑器时，侧栏的“笔记”保持激活。

## Notes

### Note Card

Content:
- 标题
- 正文摘要，Markdown 需要剥离格式后展示
- 最多 3 个标签
- 更新时间
- 同步状态：本地、冲突
- Windows 独立窗口角标

States:
- normal
- pressed
- local
- conflict
- detached
- dragging

### Tag Filter

Content:
- 全部
- 用户标签

States:
- selected
- default
- overflow horizontal scroll

### Create Note

Desktop:
- 顶部加号弹出菜单：TXT / Markdown

Mobile:
- 右下角 FAB
- 展开后显示 TXT / Markdown 选择器
- 再次点击确认创建

## Editor

### Editor Top Bar

Content:
- 返回按钮
- 当前标题
- 编辑/预览切换
- 更多菜单

Menu:
- 同步到远程
- 管理标签
- 导出 Markdown
- 转换为 TXT
- 转换为 Markdown
- 删除笔记

### Markdown Toolbar

Actions:
- H1
- H2
- H3
- Bold
- Italic
- List
- Quote
- Code
- Link

Rules:
- 仅 Markdown 编辑模式展示。
- 移动端可横向滚动。

### Editor Body

Modes:
- TXT edit
- Markdown edit
- TXT preview
- Markdown preview

Rules:
- 桌面端正文区域限制最大宽度，保证阅读行长。
- 独立窗口编辑时主编辑器只读并展示提示横幅。

## Plan

### Plan Card

Content:
- 计划标题与目标摘要
- 整体生命周期状态标签
- 自动进度和“已完成 X/Y 步”
- 最近未完成步骤
- 最后步骤的预计完成时间

States:
- not-started
- in-progress
- overdue
- completed
- terminated
- selected（桌面双栏）

### Step Timeline

Content:
- 步骤序号、标题和局部状态
- 预计完成时间和独立提醒方式
- 实际完成时间和完成说明
- 完成步骤 / 撤销完成操作

Rules:
- 步骤按用户顺序正序展示，预计时间必须非递减。
- 允许跳过前序步骤完成后续步骤。
- 早期步骤逾期使用局部红色状态，不提前改变计划整体状态。
- 已终止计划的步骤轴只读。

### Activity Timeline

Content:
- 创建、计划信息修改、步骤集合修改
- 步骤完成、步骤撤销、计划级执行记录
- 计划自动完成和终止

Rules:
- 动态按发生时间倒序展示。
- 步骤动态保留动作发生时的步骤标题，后续重命名不覆盖历史语义。

### Plan Editor

Content:
- 计划标题、目标和开始时间
- 至少一个步骤编辑卡
- 每步标题、预计完成时间、提醒预设和自定义分钟数
- 新增步骤的提醒预设默认为“到期时提醒”，用户可主动切换为“不提醒”
- 添加、删除和拖动排序操作

Validation:
- 计划标题、目标和每个步骤标题必填。
- 步骤预计时间不得早于计划开始时间。
- 后一步预计时间不得早于前一步。
- 最后一个步骤不可删除。
- 自定义提醒分钟数限制为 1-525600。

## Repository（设置内二级页）

### Status Card

States:
- 未配置
- 未连接
- 已连接
- 连接测试中
- 连接失败

Content:
- 状态点
- 状态标题
- 平台/owner/repo 或配置提示

### Sync Actions

Actions:
- 拉取远程
- 推送本地
- 全量同步
- 仓库设置

States:
- enabled
- disabled when unconfigured
- loading

### Sync Stats

Metrics:
- 总笔记
- 未同步
- 已同步
- 冲突

## Reminder

### Reminder Card

Content:
- 标题
- 时间或间隔
- 重复规则
- 启用开关

States:
- enabled
- disabled
- pressed

### Reminder Dialog

Fields:
- 标题
- 提醒时间
- 重复方式
- 间隔小时
- 间隔分钟

Actions:
- 取消
- 保存
- 删除助手

Rules:
- 当重复方式为“按间隔”时，隐藏固定时刻选择，显示小时和分钟。
- 间隔总时长至少 1 分钟。

## Settings Overview

### Repository Entries

Items:
- 仓库管理
- Git 平台配置

## Git Platform Config（设置内二级页）

### Git Config Form

Fields:
- 平台：GitHub / Gitee
- Access Token：隐藏
- 用户名/组织
- 仓库名
- 分支
- 笔记目录

Actions:
- 如何获取 Access Token
- 测试连接
- 保存配置

### Sync Toggles

Fields:
- 自动同步
- 编辑时自动推送

### Windows Window Settings

Options:
- 每次询问
- 最小化到系统托盘
- 退出程序

Rules:
- 仅 Windows 桌面展示。

### Dangerous Action

Action:
- 清除所有数据

Rules:
- 必须二次确认。
- 文案要明确不可恢复。
