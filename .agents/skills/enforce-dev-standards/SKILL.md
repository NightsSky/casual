---
name: enforce-dev-standards
description: Enforce project development standards for Flutter feature work, refactors, and core logic changes. Use when adding functionality, changing providers/data/domain logic, updating documentation requirements, or checking cross-platform compatibility for Android, iOS, and Windows.
globs:
  - "**/*.dart"
  - "**/*.md"
trigger: |
  在以下情况下自动触发此 skill：
  - 新增功能代码（检测到新文件或大量新增代码）
  - 修改核心逻辑（providers/、data/、domain/ 目录下的文件）
  - 用户明确要求添加功能或重构代码
runStyle: instructions
---

# 开发规范强制执行

在进行任何功能性开发或逻辑调整时，你**必须**遵循以下三条规则：

## 规则 1：功能文档完整性

**要求**：每个功能都必须有对应的文档，可从项目 README.md 进入查阅。

**执行标准**：
- 新增功能时，必须在 `doc/features.md` 中添加相应章节
- 如果功能涉及架构变更，必须更新 `doc/architecture.md`
- 如果功能涉及数据流变化，必须更新 `doc/data-flow.md`
- 如果功能涉及 API 调用，必须更新 `doc/api.md`
- 确保 `README.md` 中的文档导航链接准确指向对应文档

**执行时机**：在完成代码实现后、提交前

**验证方式**：
1. 检查 `doc/features.md` 是否包含新功能的使用说明
2. 确认 README.md 中能通过文档导航找到该功能说明
3. 如果涉及技术实现细节，确认对应的技术文档已更新

---

## 规则 2：功能变更文档同步

**要求**：进行功能性改动或较大逻辑调整后，**必须**更新相关文档。

**判定标准**（满足以下任一条件即为"较大逻辑调整"）：
- 修改 `providers/` 下的状态管理逻辑
- 修改 `data/` 或 `domain/` 下的数据模型或数据源
- 改变数据流向或同步机制
- 新增或修改 API 调用
- 修改页面核心交互逻辑
- 重构影响多个模块的代码

**执行标准**：
- 修改数据模型 → 更新 `doc/architecture.md` 和 `doc/data-flow.md`
- 修改同步逻辑 → 更新 `doc/data-flow.md`
- 修改 API 调用 → 更新 `doc/api.md`
- 修改功能行为 → 更新 `doc/features.md`
- 重构架构 → 更新 `doc/architecture.md` 和 `doc/development.md`

**执行时机**：代码修改完成后、验证功能正常前

---

## 规则 3：跨平台兼容性

**要求**：所有功能若未注明平台限制，开发时**必须**兼容 **App（Android/iOS）** 和 **Windows 桌面** 平台。

**执行标准**：
- 避免使用平台特定的 API，优先使用 Flutter 跨平台 API
- 如需使用平台特定功能，必须提供条件判断和降级方案
- UI 布局必须适配不同屏幕尺寸（移动端和桌面端）
- 文件路径处理使用 `path` 包，避免硬编码分隔符
- 网络请求、本地存储等核心功能必须在两个平台上测试通过

**平台特定代码示例**：
```dart
import 'dart:io' show Platform;

if (Platform.isAndroid || Platform.isIOS) {
  // 移动端特定实现
} else if (Platform.isWindows) {
  // Windows 桌面端特定实现
}
```

**响应式布局要求**：
- 使用 `LayoutBuilder` 或 `MediaQuery` 适配屏幕尺寸
- 桌面端最小宽度支持 1024px，移动端最小宽度支持 360px
- 确保触摸和鼠标操作都能正常工作

**验证方式**：
1. 代码审查时检查是否使用平台特定 API
2. 在 Windows 和 Android 两个平台上运行并测试功能
3. 如果功能确实只支持特定平台，必须在代码注释和文档中明确标注

---

## 执行流程

当你进行功能开发或逻辑修改时，按以下顺序执行：

1. **开发阶段**：编写跨平台兼容代码，避免平台特定 API
2. **代码完成**：
   - 检查是否需要更新文档（规则 1 & 2）
   - 更新 `doc/features.md`、`doc/architecture.md`、`doc/data-flow.md` 或 `doc/api.md`
3. **验证阶段**：
   - 在 Windows 桌面端运行：`flutter run -d windows`
   - 在 Android 设备/模拟器运行：`flutter run -d android`
   - 确认功能在两个平台上都能正常工作
4. **提交前检查**：
   - 文档是否已更新？
   - README.md 文档导航是否准确？
   - 功能是否在两个平台上测试通过？

---

## 豁免情况

以下情况可豁免规则 3（跨平台兼容）：
- 功能明确标注为"仅 Android"或"仅 Windows"
- 功能依赖平台特定硬件（如 Android 的通知推送）
- 用户明确要求开发平台特定功能

**豁免时必须**：
- 在代码中添加注释说明平台限制原因
- 在 `doc/features.md` 中标注平台支持情况
- 提供降级方案或提示信息（如在不支持的平台上显示"该功能仅在 Windows 上可用"）

---

## 示例：添加新功能"笔记导出为 PDF"

### 步骤 1：开发代码（lib/services/pdf_export_service.dart）
```dart
// 使用跨平台的 PDF 生成库
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io' show Platform;

class PdfExportService {
  Future<void> exportNote(Note note) async {
    final pdf = pw.Document();
    // ... PDF 生成逻辑
    
    // 跨平台保存文件
    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/${note.title}.pdf');
    await file.writeAsBytes(await pdf.save());
  }
}
```

### 步骤 2：更新文档（doc/features.md）
在 `doc/features.md` 中新增章节：
```markdown
## 笔记导出

### 导出为 PDF

支持将单篇笔记导出为 PDF 文件。

**使用方法**：
1. 在笔记详情页点击右上角"更多"按钮
2. 选择"导出为 PDF"
3. 文件保存在应用文档目录

**平台支持**：✅ Windows | ✅ Android | ✅ iOS

**技术实现**：参见 `doc/api.md` - PDF 导出
```

### 步骤 3：更新 README.md（如果是重要功能）
```markdown
- ✅ **笔记导出** - 支持导出为 PDF 格式
```

### 步骤 4：跨平台测试
```bash
# 测试 Windows
flutter run -d windows
# 导出笔记并验证文件生成

# 测试 Android
flutter run -d android
# 导出笔记并验证文件生成
```

---

## 不合规示例与纠正

### ❌ 不合规示例 1：未更新文档
```dart
// 仅修改代码，未更新 doc/features.md
class NoteProvider {
  // 新增了自动保存功能
  void autoSave() { ... }
}
```

**纠正**：在 `doc/features.md` 中添加"自动保存"功能说明。

---

### ❌ 不合规示例 2：平台特定代码未适配
```dart
// 仅支持 Windows，未提供移动端实现
import 'package:window_manager/window_manager.dart';

void setWindowSize() {
  windowManager.setSize(Size(1200, 800)); // 移动端无法运行
}
```

**纠正**：
```dart
import 'dart:io' show Platform;

void setWindowSize() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    windowManager.setSize(Size(1200, 800));
  }
  // 移动端不调用，或提供响应式布局方案
}
```

---

### ❌ 不合规示例 3：重构后未更新架构文档
```dart
// 将 NoteRepository 从 SQLite 迁移到 Hive，但未更新 doc/architecture.md
class NoteRepository {
  final Box<Note> _box; // 之前是 Database _db
}
```

**纠正**：在 `doc/architecture.md` 和 `doc/data-flow.md` 中更新数据存储方案说明。

---

## 你的职责

作为开发助手，你必须：
1. **主动提醒**：当用户提出功能需求时，先告知这三条规则
2. **执行检查**：完成代码后，主动检查文档是否需要更新
3. **验证兼容性**：提醒用户在两个平台上测试，或询问是否需要平台限制
4. **拒绝不合规代码**：如果用户要求跳过文档或跨平台测试，明确指出违反规则并说明风险

**示例回复**：
> "我已完成 [功能名称] 的代码实现。根据项目规范：
> 1. ✅ 代码已兼容 Windows 和 Android 平台
> 2. ✅ 已更新 `doc/features.md` 添加功能说明
> 3. ⏳ 请在两个平台上测试后确认功能正常
>
> 建议测试命令：
> ```bash
> flutter run -d windows
> flutter run -d android
> ```"
