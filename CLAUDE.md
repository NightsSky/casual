# GitNote Flutter 项目规范

本项目是一个基于 Git 同步的跨平台笔记应用（Flutter，支持 Android/iOS 和 Windows 桌面）。

## 开发规范（必须遵守）

进行任何功能性开发或逻辑调整时，**必须**遵循以下三条规则。完整细则见 `.agents/skills/enforce-dev-standards/SKILL.md`。

### 规则 1：功能文档完整性

每个功能都必须有对应文档，且可从 `README.md` 的文档导航进入查阅：

- 新增功能 → 在 `doc/features.md` 中添加章节
- 涉及架构变更 → 更新 `doc/architecture.md`
- 涉及数据流变化 → 更新 `doc/data-flow.md`
- 涉及 API 调用 → 更新 `doc/api.md`
- 确保 `README.md` 文档导航链接准确

### 规则 2：功能变更文档同步

修改以下内容属于"较大逻辑调整"，代码完成后**必须**同步更新相关文档：

- 修改 `providers/` 状态管理逻辑、`data/` 或 `domain/` 数据模型/数据源
- 改变数据流向或同步机制 → 更新 `doc/data-flow.md`
- 新增或修改 API 调用 → 更新 `doc/api.md`
- 修改功能行为 → 更新 `doc/features.md`
- 重构架构 → 更新 `doc/architecture.md` 和 `doc/development.md`

### 规则 3：跨平台兼容性

所有功能若未注明平台限制，必须同时兼容 **App（Android/iOS）** 和 **Windows 桌面**：

- 优先使用 Flutter 跨平台 API；平台特定功能须用 `Platform.isXxx` 条件判断并提供降级方案
- UI 须适配移动端（最小 360px）和桌面端（最小 1024px），使用 `LayoutBuilder`/`MediaQuery`
- 文件路径使用 `path` 包处理，避免硬编码分隔符
- 仅支持特定平台的功能，必须在代码注释和 `doc/features.md` 中明确标注

### 执行流程

1. 编写跨平台兼容代码
2. 代码完成后，检查并更新 `doc/` 下相关文档（规则 1 & 2）
3. 验证：`flutter run -d windows` 和 `flutter run -d android` 两个平台测试
4. 提交前确认：文档已更新、README 导航准确、双平台测试通过
