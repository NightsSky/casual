# casual

基于 GitHub/Gitee 的笔记本应用 - Flutter 版

## 功能特性

- ✅ **Markdown 工作区** - 编辑、分屏实时预览、专注全屏视图；Windows 可直接打开并保存电脑中的 Markdown 文件
- ✅ **Git 同步** - 支持 GitHub 和 Gitee，双向同步
- ✅ **定时提醒** - 助手通知，支持单次/每天/每周/每月/工作日重复，桌面与移动端本地通知
- ✅ **多步骤计划** - 将目标拆成有序步骤，自动计算进度，支持逐步骤时间轴与独立提醒
- ✅ **标签管理** - 多标签分类，快速筛选
- ✅ **响应式布局** - 桌面/移动端自适应
- ✅ **国际化** - 支持中文/英文切换
- ✅ **本地优先** - 本地存储，离线可用
- ✅ **应用内更新** - 检测 GitHub 最新发布版本，Android/Windows 可直接下载安装

## 快速开始

### 环境要求

- Flutter SDK >= 3.5.0
- Dart SDK >= 3.5.0

### 安装依赖

```bash
git clone https://github.com/yourusername/casual.git
cd gitnote_flutter
flutter pub get
```

### 运行项目

```bash
# Windows 桌面端
flutter run -d windows

# Android
flutter run -d android

# Web
flutter run -d chrome
```

## 打开电脑中的 Markdown 文件（Windows）

在笔记列表顶部点击文件夹按钮，选择 `.md`、`.markdown`、`.mdown` 或 `.mkdn` 文件即可打开。Windows 桌面端默认提供源码与渲染结果分屏，点击单个模式按钮可在仅编辑、分屏和仅预览之间循环切换，也可进入全屏专注视图；按 `Ctrl+S` 会将完整原文保存回所选文件。外部文件不会加入 Git 笔记仓库或自动同步。

## 配置 Git 同步

1. 进入**设置 → Git 平台配置**页面
2. 选择 Git 平台（GitHub 或 Gitee）
3. 填写仓库信息：
   - 用户名
   - 仓库名
   - 分支（默认 main）
   - Access Token
4. 点击**测试连接**验证配置
5. 保存配置

### 获取 Access Token

#### GitHub

1. 访问 [GitHub Settings - Tokens](https://github.com/settings/tokens)
2. 点击 **Generate new token (classic)**
3. 勾选权限：`repo` (所有子权限)
4. 生成并复制 Token

#### Gitee

1. 访问 [Gitee Settings - Tokens](https://gitee.com/profile/personal_access_tokens)
2. 点击**生成新令牌**
3. 勾选权限：`projects`
4. 生成并复制 Token

## 使用定时提醒

1. 进入**提醒**页面（导航栏闹钟图标）
2. 点击 **+** 新建提醒，填写标题、时间、重复方式
3. 到达设定时间后会弹出提醒：Windows 端在屏幕右下角显示独立小弹窗，移动端显示系统通知「casual 助手」

**注意事项**：

- Windows 端提醒依赖应用进程：**应用必须处于运行状态**（可以最小化），完全退出后不会触发通知
- Windows 端到点时只弹出右下角提醒小窗口，不会把完整主界面从托盘或后台拉出来
- Android 端提醒使用系统通知调度；请允许通知权限，Android 12+ 若拒绝精确闹钟权限，提醒可能延迟但不应完全丢失
- Android/MIUI 若通知只进通知栏不弹出，请在系统通知设置里允许「Assistant alarms」渠道的横幅/声音
- 新建单次提醒默认下一分钟；选择当前分钟会在约 10 秒后触发，更早时间会顺延到明天同一时间

## 项目结构

```
lib/
├── main.dart                # 应用入口（路由配置、启动引导）
├── layout/                  # 布局
│   └── app_shell.dart       # 应用外壳（侧边/底部导航）
├── pages/                   # 页面
│   ├── notes_page.dart      # 笔记列表
│   ├── editor_page.dart     # 编辑器
│   ├── external_markdown_page.dart # 电脑中外部 Markdown 文件的独立编辑会话
│   ├── reminder_page.dart   # 定时提醒
│   ├── plan_page.dart       # 多步骤计划编辑、步骤时间轴与执行动态
│   ├── repo_page.dart       # 设置中的仓库管理
│   ├── platform_config_page.dart # Git 平台配置
│   ├── settings_page.dart   # 设置总览
│   ├── token_help_page.dart # Token 获取帮助
│   └── search_page.dart     # 搜索（遗留代码，已被助手功能取代，未接入导航）
├── providers/               # 状态管理（Riverpod）
├── services/                # 应用服务（提醒调度、外部 Markdown 文件读写等）
├── data/                    # 数据层（仓储 + 本地/远程服务）
├── domain/                  # 领域模型
├── ui/                      # 视图模型与 UI 扩展
├── theme/                   # 主题
├── utils/                   # 工具类
└── l10n/                    # 国际化

doc/                       # 📚 项目文档
├── architecture.md        # 架构设计
├── features.md            # 核心功能
├── data-flow.md           # 数据流
├── sync-design.md         # 同步策略设计（v2，设计稿）
├── figma-redesign/        # Figma 重设计交付资料
├── api.md                 # API 文档
└── development.md         # 开发指南
```

## 📚 文档导航

### 新手入门
- [功能说明](./doc/features.md) - 了解各功能模块的使用方法
- [开发指南](./doc/development.md) - 本地开发环境搭建与调试

### 架构设计
- [架构设计](./doc/architecture.md) - 整体架构、目录结构、设计模式
- [数据流](./doc/data-flow.md) - 笔记同步、数据存储、冲突处理逻辑
- [同步策略设计 v2](./doc/sync-design.md) - 多端同步重新设计：文档身份、拉推判定、冲突三层处理（设计稿）

### 设计交付
- [Figma 重设计资料包](./doc/figma-redesign/README.md) - 当前界面描述、Figma 直用 Prompt 与组件覆盖清单

### API 集成
- [API 文档](./doc/api.md) - GitHub/Gitee API 调用说明与示例

## 技术栈

- **框架**: Flutter 3.5+
- **状态管理**: Riverpod 2.5
- **路由**: go_router 14.8
- **本地存储**: shared_preferences 2.2
- **网络请求**: http 1.2
- **Markdown**: flutter_markdown_plus 1.0
- **提醒调度**: flutter_local_notifications 18.0（Android/iOS/Linux）、应用内轮询 + desktop_multi_window 弹窗（Windows）
- **时区处理**: timezone 0.9 + flutter_timezone 3.0

## 开发计划

- [ ] 主题切换（暗色模式）
- [ ] 笔记导出（PDF/HTML）
- [ ] 图片上传（图床集成）
- [ ] 笔记加密
- [ ] 版本历史
- [ ] 协作编辑
- [ ] 提醒自定义重复规则（RepeatType.custom）

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 联系方式

如有问题或建议，请提交 [Issue](https://github.com/yourusername/gitnote_flutter/issues)。
