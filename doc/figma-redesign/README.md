# Figma Redesign Handoff

这份资料包用于把 casual 当前 Flutter 界面交给 Figma AI、Figma Make 或设计师重新设计。它不是业务功能文档，而是 UI 重设计输入材料。

## 使用方式

1. 打开 Figma，新建文件：`casual redesign`。
2. 建议创建 4 个 Page：
   - `00 Brief`
   - `01 Text Specification`
   - `02 Redesign Directions`
   - `03 Final Components`
3. 最省事的方式：直接复制 `figma-ready-brief.md` 的完整 Prompt 给 Figma AI / Figma Make。
4. 如果要拆分工作流，把 `product-brief.md` 放到 `00 Brief`，把 `screen-inventory.md` 和 `component-spec.md` 放到 `01 Text Specification`。
5. 使用 `figma-prompts.md` 里的分模块 Prompt 继续细化笔记、编辑器、仓库、设置和提醒模块。
6. 用 `component-spec.md` 校验最终组件是否覆盖当前 Flutter App 的真实状态。

## 资料包文件

- `product-brief.md`：产品定位、用户、设计目标、约束。
- `screen-inventory.md`：当前页面、路由、核心状态和交互。
- `figma-ready-brief.md`：不依赖截图、可直接复制给 Figma 的完整重设计说明。
- `figma-prompts.md`：可直接复制到 Figma AI / Figma Make 的 Prompt。
- `component-spec.md`：重设计时必须覆盖的导航、列表、编辑器、同步、提醒、设置组件。

## 关键判断

当前项目是 Flutter App，无法可靠地从代码一键转换成 Figma 可编辑图层。现在这套资料包改为纯文字输入：用完整页面描述、业务状态、组件规范和 Prompt 让 Figma 生成重设计方向。最终组件仍需在 Figma 中整理成可复用组件。
