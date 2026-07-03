# API 文档

本文档说明 GitNote 如何调用 GitHub 和 Gitee API 进行远程同步。

## GitHub API

### 基础信息

- **Base URL**: `https://api.github.com`
- **认证方式**: Bearer Token
- **API 版本**: v3

### 请求头

```http
Accept: application/vnd.github.v3+json
Authorization: Bearer {token}
Content-Type: application/json
```

**代码位置**: `lib/data/services/github_service.dart:170-174` (`_headers`)

### 1. 测试连接

**接口**: `GET /user`

**用途**: 验证 Token 是否有效

**响应示例**:
```json
{
  "login": "username",
  "id": 12345,
  "name": "User Name"
}
```

**代码位置**: `lib/data/services/github_service.dart:14-24` (`testConnection`)

### 2. 列出文件

**接口**: `GET /repos/{owner}/{repo}/contents/{path}?ref={branch}`

**用途**: 列出指定路径下的文件和目录

**参数**:
- `owner` - 仓库所有者
- `repo` - 仓库名
- `path` - 文件路径（可选，默认根目录）
- `branch` - 分支名

**响应示例**:
```json
[
  {
    "name": "note.md",
    "path": "notes/note.md",
    "type": "file",
    "sha": "abc123",
    "size": 1234,
    "download_url": "https://..."
  },
  {
    "name": "category",
    "path": "notes/category",
    "type": "dir"
  }
]
```

**递归逻辑**:
- 遇到 `type: "file"` 直接添加到结果
- 遇到 `type: "dir"` 递归调用 `listFiles(path: item['path'])`

**代码位置**: `lib/data/services/github_service.dart:26-61` (`listFiles`)

### 3. 获取文件内容

**接口**: `GET /repos/{owner}/{repo}/contents/{path}?ref={branch}`

**用途**: 获取单个文件的内容

**响应示例**:
```json
{
  "name": "note.md",
  "path": "notes/note.md",
  "sha": "abc123",
  "size": 1234,
  "encoding": "base64",
  "content": "IyDnrKblirrov4YK..."
}
```

**Base64 解码**:
```dart
String _decodeBase64(String base64) {
  return utf8.decode(base64Decode(base64));
}
```

**代码位置**: `lib/data/services/github_service.dart:63-88` (`getFileContent`)

### 4. 创建或更新文件

**接口**: `PUT /repos/{owner}/{repo}/contents/{path}`

**用途**: 创建新文件或更新已有文件

**请求体**:
```json
{
  "message": "Create/Update note",
  "content": "IyDnrKblirrov4Y=",
  "branch": "main",
  "sha": "abc123"  // 更新时必填，创建时省略
}
```

**Base64 编码**:
```dart
String _encodeBase64(String content) {
  return base64Encode(utf8.encode(content));
}
```

**响应示例**:
```json
{
  "content": {
    "name": "note.md",
    "path": "notes/note.md",
    "sha": "def456",
    "size": 1234
  },
  "commit": {
    "sha": "789abc",
    "message": "Create/Update note"
  }
}
```

**代码位置**: `lib/data/services/github_service.dart:90-122` (`createOrUpdateFile`)

### 5. 查询文件 SHA

**接口**: `GET /repos/{owner}/{repo}/contents/{path}?ref={branch}`

**用途**: 查询文件的最新 SHA 值，用于冲突检测

**返回**:
- `String` - 文件的 SHA 值
- `null` - 文件不存在（404）

**代码位置**: `lib/data/services/github_service.dart:125-143` (`getFileSha`)

### 6. 删除文件

**接口**: `DELETE /repos/{owner}/{repo}/contents/{path}`

**用途**: 删除远程文件

**请求体**:
```json
{
  "message": "Delete note: notes/note.md",
  "sha": "abc123",
  "branch": "main"
}
```

**注意**: `sha` 参数必填，必须是最新的 SHA 值

**代码位置**: `lib/data/services/github_service.dart:145-168` (`deleteFile`)

## Gitee API

### 基础信息

- **Base URL**: `https://gitee.com/api/v5`
- **认证方式**: Query Parameter (`access_token`)
- **API 版本**: v5

### 与 GitHub API 的差异

1. **认证方式**:
   - GitHub: Header `Authorization: Bearer {token}`
   - Gitee: Query `?access_token={token}`

2. **文件写入方法**:
   - GitHub: 创建和更新均使用 `PUT /contents/{path}`，更新时携带 `sha`
   - Gitee: 创建使用 `POST /contents/{path}`，更新已有文件必须使用 `PUT /contents/{path}` 并携带 `sha`

3. **响应格式**:
   - 基本一致，但部分字段名称不同
   - Gitee 返回的 `content` 字段可能已解码

4. **Base64 处理**:
   - GitHub: 始终返回 Base64 编码
   - Gitee: 部分接口直接返回明文

**代码位置**: `lib/data/services/gitee_service.dart`

## 数据模型映射

### 远程文件 → 笔记对象

```dart
// GitHub API 返回的文件
{
  "path": "notes/category/uuid.md",
  "sha": "abc123",
  "content": "IyDnrKblirrov4Y="  // Base64
}

// 解析为笔记对象
Note(
  id: "uuid",  // 从文件名提取
  title: "笔记标题",  // 从 Markdown 第一行提取
  content: "笔记正文",  // 解码后的内容
  category: "category",  // 从路径提取
  filePath: "notes/category/uuid.md",
  sha: "abc123",
  syncStatus: SyncStatus.synced,
)
```

### 笔记对象 → 远程文件

```dart
Note note = ...;

// 生成文件路径
String filePath = "notes/${note.category}/${note.id}.md";

// 生成 Markdown 内容
String markdown = """
# ${note.title}

${note.content}

---
tags: ${note.tags.join(', ')}
created: ${note.createdAt.toIso8601String()}
updated: ${note.updatedAt.toIso8601String()}
""";

// Base64 编码
String encoded = base64Encode(utf8.encode(markdown));
```

## 同步策略

### 全量同步（Push local then Pull）

```
1. 读取本地 syncStatus=local 的笔记快照
2. 逐条调用 getFileSha() 查询远程当前 SHA，补齐本地缺失的更新凭据
3. SHA 无冲突后调用 createOrUpdateFile() 将本地未同步内容写入远程
4. 推送成功后写回本地 filePath、sha，并标记为 synced
5. 调用 listFiles() 获取远程最新 .md/.txt 文件
6. 调用 getFileContent() 下载所有文件内容
7. 解析每个文件为 Note 对象
8. 比对本地笔记：
   - 本地不存在：导入
   - 本地存在 && 本地仍为 local 且远程内容不同：标记冲突，保留本地内容
   - 本地存在 && 本地已同步或远程版本更新：写入远程内容和最新 sha
9. 保存到本地存储
```

### 单条推送（Push）

```
1. 生成文件路径（如果是首次推送）
2. 调用 getFileSha() 查询远程最新 SHA
3. 比对 SHA：
   - 远程不存在：调用 createOrUpdateFile() 创建
   - 远程存在 && SHA 相同：调用 createOrUpdateFile() 更新
   - 远程存在 && SHA 不同：抛出冲突异常
4. 更新本地笔记的 filePath 和 sha
5. 标记同步状态为 synced
```

### 冲突检测

**基于 Git SHA 值**:
- 每次创建/更新文件后，GitHub 返回新的 SHA
- 本地保存笔记时同时保存 SHA
- 推送前比对本地 SHA 与远程 SHA
- 不一致则说明远程文件已被修改，存在冲突

## 错误处理

### 常见错误码

| 状态码 | 含义 | 处理方式 |
|-------|------|---------|
| 401 | Token 无效 | 提示用户重新配置 |
| 404 | 文件不存在 | 创建新文件 |
| 409 | SHA 冲突 | 提示用户解决冲突 |
| 422 | 参数错误 | 检查请求参数 |
| 500 | 服务器错误 | 提示用户稍后重试 |

### 异常捕获

```dart
try {
  await githubService.createOrUpdateFile(...);
} catch (e) {
  if (e.toString().contains('409')) {
    // 冲突处理
    throw Exception('远程文件已被修改，请先同步');
  } else {
    // 其他错误
    throw Exception('同步失败: ${e.toString()}');
  }
}
```

## 性能优化

### 1. 并发下载

```dart
// 使用 Future.wait 并发下载多个文件
final contents = await Future.wait(
  files.map((file) => getFileContent(path: file['path']))
);
```

### 2. 增量同步

**当前实现**: 全量同步（每次拉取所有文件）

**优化方案**: 
- 保存最后同步的 Commit SHA
- 下次仅拉取该 Commit 之后的变更
- GitHub API: `GET /repos/{owner}/{repo}/commits?since={sha}`

### 3. 限流处理

GitHub API 限流：
- 认证请求：5000 次/小时
- 未认证请求：60 次/小时

建议：
- 添加请求计数器
- 接近限额时提示用户
- 使用 `X-RateLimit-Remaining` 响应头监控

## 相关文档

- [架构设计](./architecture.md) - 整体架构说明
- [数据流](./data-flow.md) - 同步流程详解
- [核心功能](./features.md) - 功能详细说明
