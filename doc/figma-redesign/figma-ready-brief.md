# Figma Ready Brief

下面这段可以直接复制给 Figma AI / Figma Make / 设计师。它不依赖截图，全部基于当前 Flutter 项目的页面结构、功能状态和视觉约束描述。

```text
请为一个名为 casual 的 Flutter App 重新设计完整 UI。不要依赖截图，请完全基于以下产品、页面、状态和组件描述生成设计稿。

一、产品定位

casual 是一个本地优先的 Git 笔记应用。用户可以创建 TXT 或 Markdown 笔记，在本地离线编辑，并通过 GitHub 或 Gitee 仓库同步笔记文件。应用还包含一个轻量提醒助手，用来创建单次、周期或间隔提醒。

目标用户：
- 个人开发者
- 技术写作者
- Markdown 用户
- 使用 Git 管理笔记、文档或知识库的人

设计气质：
- 专业、克制、清爽
- 有开发者工具感
- 信息密度适中
- 不要做成营销页
- 不要使用装饰性插画或大面积花哨渐变
- 不要让界面变成普通待办/备忘录 App，要保留 Git、Markdown、本地优先的产品特征

二、当前信息架构

App 有 4 个一级模块：
1. 笔记
2. 助手
3. 仓库
4. 设置

另有两个重要二级页面：
1. 笔记编辑器
2. Access Token 帮助页

移动端导航：
- 底部 Tab：笔记、助手、仓库、设置
- 编辑器页面隐藏底部 Tab，使用顶部返回

桌面端导航：
- 左侧侧边栏
- 侧边栏包含品牌 casual、笔记、助手、仓库、设置、版本号
- 笔记模块在桌面端支持分栏：左侧笔记列表，右侧编辑器

三、页面设计要求

1. 笔记列表页

页面目标：
让用户快速浏览、筛选、创建和同步笔记。

核心元素：
- 顶部标题：casual
- 新建笔记入口
- 同步按钮
- 排序菜单：最近更新、创建时间、标题排序
- 同步状态条：同步中、上次同步、同步失败
- 标签筛选条：全部、具体标签
- 笔记卡片列表
- 空状态

笔记卡片内容：
- 笔记标题
- 正文摘要
- 最多 3 个标签
- 更新时间
- 同步状态标签：本地、冲突
- 桌面端独立窗口角标

移动端新建笔记交互：
- 右下角 FAB
- 点开后选择 TXT 或 Markdown
- 再次确认创建

桌面端新建笔记交互：
- 顶部加号按钮
- 弹出 TXT / Markdown 菜单

必须设计的状态：
- 空列表
- 普通列表
- 本地未同步
- 冲突
- 同步失败
- 同步中
- 标签筛选激活
- 排序菜单
- 删除确认
- 桌面端“在新窗口打开”

2. 编辑器页

页面目标：
提供高可读性的 Markdown/TXT 编辑与预览体验。

核心元素：
- 顶部返回按钮
- 当前笔记标题
- 编辑/预览切换
- 更多菜单
- 标题输入或标题预览
- 标签行
- 正文编辑区
- Markdown 工具条
- Markdown 预览区
- 底部字数和更新时间

更多菜单内容：
- 同步到远程
- 管理标签
- 导出 Markdown
- 转换为 TXT
- 转换为 Markdown
- 删除笔记

Markdown 工具条动作：
- H1
- H2
- H3
- 加粗
- 斜体
- 列表
- 引用
- 代码
- 链接

必须设计的状态：
- 新建笔记编辑态
- 已有笔记预览态
- Markdown 编辑态
- TXT 编辑态
- Markdown 预览态
- 添加标签弹窗
- 删除确认弹窗
- 单条同步中
- 单条同步失败
- 独立窗口编辑时主编辑器只读

桌面端编辑器要求：
- 与笔记列表分栏
- 阅读/预览模式限制正文最大宽度，避免长行
- 编辑器主体像专业文档编辑工具，不像普通输入框

移动端编辑器要求：
- 顶部返回
- 隐藏底部 Tab
- 工具条可以横向滚动
- 标题和正文输入需要足够舒适

3. 助手/提醒页

页面目标：
让用户创建和管理提醒，但不要抢占笔记主功能的视觉权重。

核心元素：
- 提醒列表
- 提醒卡片
- 启用/停用开关
- 新建提醒入口
- 新建/编辑提醒弹窗
- 删除确认

提醒卡片内容：
- 标题
- 时间或间隔
- 重复规则
- 启用状态

重复规则：
- 无
- 每天
- 每周
- 每月
- 工作日
- 按间隔

按间隔模式：
- 隐藏固定时刻选择
- 显示小时选择
- 显示分钟选择
- 最小间隔为 1 分钟
- 文案提示：保存后开始计时，按所选间隔重复提醒

必须设计的状态：
- 空状态
- 提醒列表
- 启用提醒
- 停用提醒
- 新建提醒弹窗
- 编辑提醒弹窗
- 按间隔提醒设置
- 删除提醒确认
- 保存失败提示

4. 仓库管理页

页面目标：
清楚表达 Git 仓库连接状态、同步操作和同步结果。

核心元素：
- 顶部标题：仓库管理
- 连接状态卡片
- 快捷操作区
- 同步统计区
- 同步记录区

连接状态：
- 未配置
- 未连接
- 已连接
- 连接测试中
- 连接失败

快捷操作：
- 拉取远程
- 推送本地
- 全量同步
- 仓库设置

同步统计：
- 总笔记
- 未同步
- 已同步
- 冲突

同步记录：
- 成功
- 失败
- 警告
- 空记录

设计要求：
- 未配置时给出清楚的下一步入口
- 冲突状态要醒目但不要吓人
- 同步失败需要能表达原因和重试方向

5. 设置页

页面目标：
帮助用户完成 GitHub/Gitee 同步配置，并管理同步偏好和危险操作。

核心元素：
- Git 平台配置
- Token 帮助入口
- 测试连接
- 保存配置
- 同步设置
- Windows 窗口设置
- 关于
- 清除所有数据

Git 平台配置字段：
- 平台：GitHub / Gitee
- Access Token，必须隐藏输入
- 用户名/组织
- 仓库名
- 分支，默认 main
- 笔记目录，默认 notes

同步设置：
- 自动同步
- 编辑时自动推送

Windows 窗口设置：
- 关闭主面板时：每次询问、最小化到系统托盘、退出程序
- 此设置仅 Windows 桌面展示

危险操作：
- 清除所有数据
- 必须使用红色危险样式
- 必须二次确认
- 文案明确不可恢复

必须设计的状态：
- 平台选择弹窗
- 关闭行为选择弹窗
- 测试连接成功
- 测试连接失败
- 保存成功
- 清空所有数据确认

6. Access Token 帮助页

页面目标：
让用户知道如何获取 GitHub/Gitee Token，并理解 Token 安全风险。

核心元素：
- 返回按钮
- 页面标题：Access Token 帮助
- 简短说明：casual 需要 Access Token 读取和更新笔记仓库
- GitHub 获取方式卡片
- Gitee 获取方式卡片
- Token 安全说明卡片
- 官方入口链接

GitHub 步骤：
- 打开 GitHub Settings
- 进入 Developer settings > Personal access tokens > Fine-grained tokens
- Generate new token
- Repository access 选择 casual 使用的仓库
- Contents 权限设置为 Read and write

Gitee 步骤：
- 打开 Gitee 设置
- 进入安全设置 > 私人令牌
- 生成新令牌
- 勾选 project 权限
- 完成校验后复制私人令牌

四、组件系统要求

请设计一套完整组件库，至少包含：

导航：
- Mobile Bottom Navigation
- Desktop Sidebar
- Editor Top Bar

按钮：
- Primary Button
- Secondary Button
- Text Button
- Icon Button
- Floating Action Button
- Danger Button

输入：
- Text Field
- Password/Token Field
- Dropdown
- Switch
- Time Picker Entry
- Hour/Minute Selector

数据展示：
- Note Card
- Reminder Card
- Repository Status Card
- Sync Stat Item
- Sync Log Item
- Token Help Step

状态组件：
- Empty State
- Loading State
- Error Banner
- Success Snackbar
- Error Snackbar
- Local Badge
- Conflict Badge
- Detached Window Badge
- Readonly Banner

弹窗：
- Add Tag Dialog
- Delete Note Confirm
- Reminder Dialog
- Delete Reminder Confirm
- Platform Picker Bottom Sheet
- Window Close Action Bottom Sheet
- Clear All Data Confirm

五、视觉规范建议

当前主色是暖棕色 #C4612F，可以保留为品牌强调色，但不要让全局都被暖棕/米色控制。

请重新设计色彩系统：
- 背景以中性色为主
- 主色用于主要操作和激活态
- 成功、警告、错误、冲突要有清楚区分
- Git 同步相关状态需要有专业、可靠的视觉表达

建议方向：
- 专业工具类 App
- 类似 GitHub / Linear / Notion 的克制信息层级
- 不要一味做成 Material 默认样式
- 不要使用大圆角卡片堆叠
- 卡片圆角建议 8px 左右
- 页面区域尽量使用清晰布局，不要把所有内容都包进大卡片

六、响应式要求

请输出两个主要尺寸：
- Mobile：390x844
- Desktop：1440x900

移动端要求：
- 单手可用
- 底部导航清晰
- 列表可快速扫描
- 编辑器工具条不挤压正文

桌面端要求：
- 左侧导航稳定
- 笔记列表和编辑器分栏高效
- 预览模式有良好阅读宽度
- 设置和仓库页避免空旷，信息密度合理

七、最终输出

请生成：
1. 移动端完整页面设计
2. 桌面端完整页面设计
3. 组件库
4. 颜色、字号、间距、圆角规范
5. 关键交互状态
6. 适合 Flutter 落地的布局建议

请特别检查：
- 不要遗漏冲突、本地未同步、同步失败、独立窗口只读这些状态
- 不要只画静态页面，要覆盖弹窗、菜单、空状态和错误状态
- 不要新增当前产品没有的复杂功能
- 不要把提醒助手做得比笔记主功能更突出
```

