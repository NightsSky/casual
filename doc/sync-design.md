# 笔记同步策略设计（v2）

> 状态：**已评审通过，实施中（M1、M2、M3 已完成）** · 设计 2026-07-03 · 冲突策略于 2026-07-06 简化
> 本文档是对现有 Git 同步机制的重新设计。现行实现的描述见 [数据流](./data-flow.md)。
> 实施进度见 [§14 分阶段实施计划](#14-分阶段实施计划)。
>
> **⚠️ 冲突策略变更（2026-07-06）**：原 §7 设计的「diff3 自动合并 → 冲突副本 → 三选一解决界面」三层策略经复盘认为过重，**已简化为「二选一」**：当同一篇笔记本地与远端都改动时，弹窗展示双方最后更新时间，由用户逐篇选择**保留本地**或**用远程覆盖**，不做自动合并、不生成冲突副本、不做逐块解决界面。§7 已按新策略重写；§4、§6.2 等处的「三方合并」表述以 §7 为准。

## 目录

1. [背景：现状与问题](#1-背景现状与问题)
2. [业界方案调研](#2-业界方案调研)
3. [设计目标与非目标](#3-设计目标与非目标)
4. [总体方案：基于 base 快照的三方状态同步](#4-总体方案基于-base-快照的三方状态同步)
5. [文档身份：怎么确定是同一篇笔记](#5-文档身份怎么确定是同一篇笔记)
6. [同步判定：怎么确定拉取还是推送](#6-同步判定怎么确定拉取还是推送)
7. [冲突处理：时间对照 + 用户二选一](#7-冲突处理时间对照--用户二选一)
8. [同步会话：端到端流程](#8-同步会话端到端流程)
9. [数据模型与存储变更](#9-数据模型与存储变更)
10. [平台能力矩阵与 API 效率](#10-平台能力矩阵与-api-效率)
11. [触发时机与并发控制](#11-触发时机与并发控制)
12. [迁移方案](#12-迁移方案)
13. [被否决的备选方案](#13-被否决的备选方案)
14. [分阶段实施计划](#14-分阶段实施计划)
15. [参考资料](#15-参考资料)

---

## 1. 背景：现状与问题

### 1.1 现状概述

当前同步不经过本地 git 仓库，而是直接调用 GitHub/Gitee **Contents REST API** 逐文件读写：

- **拉取**：递归 `listFiles` 列目录 → 逐文件 `getFileContent` 下载全部内容 → `importNote` 逐条合入本地（`lib/data/repositories/git_sync_repository.dart:39`）
- **推送**：按 `notesDir/{title}.{ext}` 生成路径 → 查远程 sha 做乐观锁 → `createOrUpdateFile`（`lib/data/repositories/git_sync_repository.dart:111`）
- **全量同步**：先推所有 `syncStatus == local` 的笔记，再拉全部远程笔记（`lib/ui/features/git/view_models/git_view_model.dart:152`）
- **冲突**：推送时远程 sha 与本地不一致 → 抛异常中断；拉取时本地有未同步修改且远程内容不同 → 标记 `conflict`（`lib/ui/features/notes/view_models/notes_view_model.dart:269`）

### 1.2 问题清单

| # | 问题 | 根因 | 后果 |
|---|------|------|------|
| P1 | **笔记身份靠文件路径，路径又由标题生成** | `pushNote` 用 `{notesDir}/{title}.{ext}` 作路径 | 改标题后推送会在远端产生**新文件**，旧文件残留，下次拉取变成两篇重复笔记 |
| P2 | **同名标题即同一路径** | 同上 | 两台设备各自新建同名笔记会互相覆盖或误判冲突；标题含 `/ \ : * ? " < > |` 等字符时路径非法 |
| P3 | **没有共同祖先（base），无法三方判定** | 本地只存"当前内容 + 远程 sha"两方 | 无法区分"远程变了/本地变了/都变了"，更无法做三方合并 |
| P4 | **远程文件修改时间不可得，时间戳比较失效** | Contents API 列表不返回 `updated_at`，代码 `file['updated_at']` 恒为 null，落到 `DateTime.now()` | `importNote` 里 `localNewer` 判定基于假时间，实际行为退化为"远程覆盖已同步笔记" |
| P5 | **冲突进入死角，实质是"后写者赢"** | 冲突笔记只有红色标签，没有解决界面；用户再次编辑会置回 `local`，且 `importNote` 已把远程 sha 写入本地，下次推送直接覆盖远端 | 用户从未看到远程版本内容，另一端的修改**静默丢失** |
| P6 | **远端删除不传播** | 拉取只增改不删 | 在 A 端删除的笔记永远留在 B 端（synced 状态），形同僵尸 |
| P7 | **全量拉取，N+1 请求** | 每次同步都 `listFiles` 递归 + 每文件一次 `getFileContent` | 笔记多时慢、耗流量、易触发 API 限流（GitHub 5000 次/时，Gitee 更严） |
| P8 | **逐文件推送非原子** | 每个文件一次 commit | 推 10 篇笔记产生 10 个 commit；中途断网留下"半同步"状态 |
| P9 | **tags / category / 时间元数据不同步** | 远端只有正文纯文本，元数据只在本地 shared_preferences | 换设备或重装后标签、分类、创建时间全部丢失（拉回来的笔记恒为"未分类"） |
| P10 | **fullSync 一条冲突中断全场** | `pushNote` 抛异常直接冒泡 | 一篇笔记冲突导致其余笔记也不同步 |
| P11 | 文档与代码不一致 | `data-flow.md` 记载路径为 `notes/{category}/{uuid}.md`，实际是 `{notesDir}/{title}.{ext}` | 维护误导 |

其中 P1/P2 是**身份问题**，P3/P4 是**判定问题**，P5/P10 是**冲突处理问题**，P6 是**删除语义问题**，P7/P8 是**效率问题**，P9 是**数据完整性问题**——本设计逐一解决。

---

## 2. 业界方案调研

### 2.1 Joplin（自研同步协议，非 Git）

[Joplin 官方同步规范](https://joplinapp.org/help/dev/spec/sync/)、[冲突说明](https://joplinapp.org/help/apps/conflict/)：

- 离线优先，每条笔记是同步目标上的一个独立 item 文件；**每条 item 有全局唯一 id**，与文件名解耦
- 编辑后数秒内即上传，"尽快上传"本身就是减少冲突的手段
- 冲突时：**本地版复制进 Conflicts 笔记本，远程版覆盖正身**——永不阻塞、永不丢数据，用户事后自行比对
- 近期 GSoC 项目正在引入 [node-diff3 三方合并做自动冲突解决](https://discourse.joplinapp.org/t/automatic-conflict-resolution/49050)，说明"冲突副本"之上叠加"自动三方合并"是社区公认的演进方向

**借鉴**：id 与文件名解耦；冲突副本不阻塞同步；三方合并作自动层。

### 2.2 Obsidian Sync（官方付费服务）

[社区讨论](https://forum.obsidian.md/t/robust-sync-conflict-resolution/93544)：

- Markdown 冲突用 Google diff-match-patch **字符级自动合并**；二进制文件"最后修改者赢"
- 实践中 diff-match-patch 偶发**把新数据合丢**，因此 1.9.7 起允许用户改为"生成冲突文件，人工比对"

**借鉴**：自动合并要可关闭/可回退；字符级合并激进易错，行级更可预测。

### 2.3 obsidian-git / GitJournal（真 Git 仓库）

[GitJournal](https://gitjournal.io/support/)、[obsidian-git 冲突处理讨论](https://github.com/Vinzent03/obsidian-git/issues/803)：

- 设备本地是完整 git 克隆，同步 = `pull --rebase` + `commit` + `push`，冲突交给 git 标准三方合并
- 语义最正确，但移动端嵌入 libgit2/自研 git 实现的**体积、内存、维护成本高**；obsidian-git 在移动端被作者标注"高度不稳定"
- 用户遇到冲突时直面 git conflict marker，对非程序员不友好

**借鉴**：三方合并的判定语义（正是 git merge 的语义）值得照搬到 API 层实现；但完整 git 运行时不适合本项目移动端。

### 2.4 Git Vault Sync（双引擎混合）

[插件介绍](https://community.obsidian.md/plugins/git-vault-sync)：

- 桌面用 isomorphic-git 真仓库，移动端走 **GitHub Data API 逐 blob 传输**，避免整包 packfile 撑爆内存
- 用 hash 对比做变更检测，只传变更文件

**借鉴**：REST API 引擎完全可以实现 git 语义的同步；用 blob sha 做变更检测避免全量下载（解 P7）。

### 2.5 结论

| 方案 | 身份 | 判定 | 冲突 | 是否采纳 |
|------|------|------|------|----------|
| Joplin | item id | 修改时间 + updatedTime 启发式 | 冲突副本（正在加 diff3） | ✅ 身份与冲突副本思路 |
| Obsidian Sync | 路径 | 服务端版本 | 字符级自动合并 | ⚠️ 仅借鉴"自动合并可关" |
| 真 Git（GitJournal 等） | 路径 + git 内容寻址 | commit DAG | git 三方合并 | ⚠️ 借鉴语义，不引入 git 运行时 |
| Git Vault Sync | 路径 | blob sha 对比 | git 合并/API 引擎受限 | ✅ API 引擎 + sha 变更检测 |

**没有现成"最优解"可直接套用**，但共识清晰：**稳定 id 标识文档、以共同祖先做三方判定、绝不静默覆盖**。本设计在现有 REST API 架构上落实这三点。

> 关于自动合并：调研中的 Joplin（diff3）、Obsidian（字符级）都在"自动合并"上投入，但也都踩过"合并把新内容合丢"的坑（§2.2）。本设计**刻意不做自动合并**——用 base 三方判定**准确识别"是否冲突"**，一旦冲突就把裁决权完整交给用户（二选一），而非替用户猜测如何合并。这是复杂度与可预测性的取舍：宁可让用户在极少数真冲突时手动选一次，也不引入一套可能悄悄丢数据的合并逻辑。

---

## 3. 设计目标与非目标

### 目标

1. **正确性**：任何操作序列下不静默丢失用户数据；删除、重命名跨端正确传播
2. **身份稳定**：重命名、改标题、移动分类不改变笔记身份
3. **判定确定性**：拉/推/合并/冲突的判定不依赖设备时钟，只依赖内容
4. **冲突不阻塞**：单篇冲突不影响其余笔记同步；冲突逐篇弹窗由用户裁决（保留本地 / 用远端覆盖），取消则跳过该篇、本地不动，其余笔记照常同步
5. **效率**：同步请求数与**变更量**成正比，而非笔记总量
6. **仓库可读**：远端仓库保持人类可读的 Markdown 文件树，可被任何编辑器/git 客户端直接使用
7. **跨平台**：App（Android/iOS）与 Windows 桌面行为一致；同步引擎纯 Dart 实现，无平台原生依赖

### 非目标

- 实时协同编辑（多人同时编辑同一笔记的操作级合并）
- 端到端加密（依赖私有仓库的访问控制；后续可另行立项）
- 同步 Git 提交历史到本地（本地不保存版本历史，历史留在远端仓库，可通过网页查看）

---

## 4. 总体方案：基于 base 快照的三方状态同步

### 4.1 核心思想

不引入本地 git 仓库，但**照搬 git 三方合并的判定语义**：本地为每篇已同步笔记额外保存一份 **base 快照**——上次同步成功时双方共识的版本。同步时对每篇笔记拿到三个状态：

```
        base（上次共识版本，本地缓存）
       /    \
  local      remote
（本地当前）  （远端当前，用 blob sha 探测）
```

- `local == base && remote == base` → 无事发生
- `local != base && remote == base` → 只有本地改了 → **推送**
- `local == base && remote != base` → 只有远端改了 → **拉取**
- `local != base && remote != base` → 双方都改了 → **冲突**，弹窗交用户裁决（§7）

这正是 git merge 的判定模型（区别在于最后一步不做自动合并，而是把裁决权交给用户）。base 快照一举解决 P3（有了共同祖先）、P4（判定不依赖时间戳）、P6（base 里有而远端没有 = 远端已删除，可传播删除）。

### 4.2 三个不变量

整个引擎围绕三条不变量构建，任何代码改动不得破坏：

- **I1（身份不变量）**：一篇笔记在所有端、整个生命周期内由同一个 `id` 标识；路径只是当前存放位置。
- **I2（base 不变量）**：`base` 只在"本地与远端就该笔记达成一致"的时刻更新（推送成功、拉取落盘、冲突裁决后按所选版本落定），其余任何时刻只读。
- **I3（无损不变量）**：引擎绝不在双方都改过时自动覆盖任何一方——此种情形一律交用户裁决（§7）。用户显式选择「用远程覆盖本地」时，被覆盖的本地版本仍可在远端 git 历史中找回。

---

## 5. 文档身份：怎么确定是同一篇笔记

### 5.1 方案：front-matter 内嵌 id（主）+ 路径（降级）

**Markdown 笔记**在文件头部嵌入 YAML front-matter，`id` 为身份主键：

```markdown
---
id: 550e8400e29b41d4a716446655440000
created: 2026-07-03T10:00:00+08:00
updated: 2026-07-03T12:30:00+08:00
category: 工作
tags: [flutter, sync]
---

# 会议纪要

正文……
```

- `id`：沿用现有 `generateId()`（UUID v4 去连字符取 16 位，`lib/utils/markdown_utils.dart:5`）。**创建即生成、永不改变、随文件走**
- `created/updated/category/tags`：元数据随文件同步，解决 P9。`updated` 仅供展示，**不参与同步判定**（见 §6）
- front-matter 在编辑器中对用户隐藏（加载时剥离、保存时回写），预览/正文均不显示

**txt 笔记**没有公认的元数据头惯例，为保持"打开即纯文本"，**降级为路径身份**：路径即 id，重命名等价于"删除旧 + 新建新"。此限制写入 `features.md` 并在 UI 上不提供 txt 改名后的连续历史。若用户需要完整能力，引导转为 Markdown 格式。

> txt 笔记不设独立标题字段：`Note.title` 始终由正文首行派生（首个非空行、截断 80 字符，`deriveTxtTitle`），仅用于文件名分配（§5.3）与列表展示，不写入文件内容。因此 txt 的"改标题"= 改正文首行 = 换文件名 = 换身份，与上面的路径身份语义一致。

### 5.2 为什么不是路径、不是内容 hash、不是中心清单

| 候选 | 否决理由 |
|------|----------|
| 文件路径 | 即现状 P1/P2：改名即换身份；标题非法字符；两端同名互踩 |
| 内容 hash | 内容一变身份就变，无法追踪编辑；空笔记/模板笔记 hash 相同 |
| 仓库级 `manifest.json` 清单（路径 ↔ id 映射集中存放） | 清单本身成为**冲突热点**——任意两端同时新建笔记都会并发改同一个文件，把逐笔记冲突升级为全局冲突；且清单与文件易失同步 |

front-matter 是 Obsidian/Jekyll/Hugo 等工具的通用惯例，随文件复制、移动、fork 都不丢，是分散式身份的最稳载体。

### 5.3 文件名与路径策略

文件名保持人类可读，但**只是展示层**：

- 生成规则：`{notesDir}/{sanitize(title)}.md`
  - `sanitize`：替换 Windows/Unix 非法字符 `\ / : * ? " < > |` 及首尾空格、点号为 `-`；空标题用 `untitled`；截断至 80 字符（规避 Windows 260 路径限制）
  - 路径已被**其他 id** 占用时追加短 id 后缀：`{title}-{id 前 8 位}.md`
- **改标题 = 同 id 重命名**：推送时在同一提交内"删旧路径 + 建新路径"（见 §8.4），远端历史连续
- 拉取端看到"旧路径消失 + 新路径出现且 front-matter id 相同" → 判定为重命名而非删除+新建（见 §6.3）

### 5.4 id 对账的边界情况

| 情况 | 判定 |
|------|------|
| 两端各自新建，id 不同但路径相同 | 不同笔记。后到者按 §5.3 加 id 后缀改名，两篇共存 |
| 远端出现两个文件 front-matter id 相同（用户手工复制文件） | 保路径与 base 一致者为正身；另一个视为新笔记并**就地改写新 id** 后推回 |
| 远端文件无 front-matter（用户用其他工具直接建的 md） | 视为新笔记：拉取时生成 id 注入 front-matter，下轮推送回写远端（“收编”） |
| front-matter 被用户手工删除 | 同上，按新笔记收编；旧 id 对应条目走删除判定。属可接受的用户自担行为 |

---

## 6. 同步判定：怎么确定拉取还是推送

### 6.1 变更检测：内容寻址，不用时钟

- **远程是否变了**：比较远端 blob sha 与 `base.blobSha`。关键优化——git blob sha 就是内容的确定性哈希（`sha1("blob {字节数}\0" + 内容)`），**本地可自行计算**。因此：
  - 一次 `GET /git/trees/{branch}?recursive=1` 拿到全仓库 `path → blobSha` 清单（1 个请求，解 P7）
  - sha 与 base 相同的文件**无需下载**
- **本地是否变了**：比较本地内容算出的 blob sha 与 `base.blobSha`（等价于现 `syncStatus == local` 标记，但以内容为准，不怕标记丢失）
- 设备时钟、`updatedAt` **一律不参与判定**（解 P4）。时间戳只用于 UI 展示——包括冲突弹窗里给用户看的「本地/远端最后更新时间」（§7）。注意：判定是否冲突只看内容 blob sha，与时间无关；时间仅在确认冲突后作为用户裁决的参考信息呈现

### 6.2 判定表（引擎核心）

对"本地笔记表 ∪ base 表 ∪ 远程清单"中出现过的每个 id（txt 为路径）执行：

| # | base | 本地相对 base | 远端相对 base | 判定 | 动作 |
|---|------|--------------|--------------|------|------|
| 1 | 有 | 未变 | 未变 | 已同步 | 无操作 |
| 2 | 有 | **已变** | 未变 | 本地领先 | **推送**；成功后 base ← 本地 |
| 3 | 有 | 未变 | **已变** | 远端领先 | **拉取**覆盖本地；base ← 远端 |
| 4 | 有 | **已变** | **已变** | 分叉冲突 | **冲突二选一**（§7）：弹窗展示双方最后更新时间，用户选保留本地（推送覆盖远端）或用远端覆盖本地；取消则跳过本篇 |
| 5 | 有 | **已删** | 未变 | 本地删除 | 推送删除到远端；清 base |
| 6 | 有 | 未变 | **已删** | 远端删除 | 删除本地；清 base（解 P6） |
| 7 | 有 | **已变** | **已删** | 删改冲突 | 保守处理：本地按"新笔记"重新推送（内容尚在，恢复文件），并提示用户 |
| 8 | 有 | **已删** | **已变** | 改删冲突 | 保守处理：远端新版拉回本地并标记提示，用户可再删（删除需重确认，不自动重删） |
| 9 | 无 | **新建** | 不存在 | 本地新增 | 推送；建 base |
| 10 | 无 | 不存在 | **新增** | 远端新增 | 拉取导入（先做 §6.3 重命名对账）；建 base |
| 11 | 无 | **新建** | **新增**（同 id） | 双端同源（如同一仓库先导入再各改） | 内容相同 → 直接建 base；不同 → 无 base 的冲突，走 §7 二选一（缺 base，弹窗仅展示两版时间供裁决） |

规则 7/8 遵循 git 对 modify/delete 冲突的保守立场：**删除让位于修改**——宁可让用户多删一次，不可替用户丢一篇。

### 6.3 重命名/移动的识别

远端清单对账时，"路径消失"不能立即判死为删除：

1. 收集"消失路径"集合 D 与"新增路径"集合 N
2. 下载 N 中文件，解析 front-matter id
3. 若某新增文件 id 与某消失路径的 base id 相同 → **重命名/移动**：本地仅更新 `filePath`，内容按规则 3/4 继续判定
4. D 中剩余者才进入规则 6/8 的删除判定

本地改标题同理：推送计划中生成"旧路径删除 + 新路径写入"成对操作，在一个提交内完成（§8.4）。

---

## 7. 冲突处理：时间对照 + 用户二选一

设计原则：**判定用内容，裁决交用户，绝不静默覆盖**。v2 首版不做自动合并、不留冲突副本——检测到双方都改过（规则 4，或规则 11 的内容不一致分支）时，弹窗把本地与远端的最后更新时间摆给用户，由用户在"保留本地"和"用远程覆盖"之间二选一。

> **设计取舍**：早期版本设计过三层递进策略（diff3 行级自动合并 → 冲突副本 → 三选一解决界面），因实现与心智成本偏高，在 M4 阶段简化为本方案。被移除方案的分析保留在 §13.5，未来若有需求可重新引入。

### 7.1 冲突判定与判定/展示的分离

**判定是否冲突，仍只看内容**（§6.1）：本地内容 blob sha ≠ base.blobSha 且远端 blob sha ≠ base.blobSha，即规则 4。这一步不涉及任何时间戳，与"判定确定性"目标（§3 目标 3）一致。

**只有确认冲突后**，才为这一篇额外取时间供弹窗展示：

- **本地最后更新时间**：`Note.updatedAt`（本地编辑时写入，展示用途，不参与判定）
- **远端最后更新时间**：该文件在远端最新一次 commit 的**服务端提交时间**（committer date），非任何设备的本地时钟——GitHub `GET /repos/{o}/{r}/commits?path={path}&per_page=1`，Gitee 同类端点。仅在确认冲突时才请求（冲突罕见，额外开销可忽略）

时间只是给用户的**参考信息**，不自动决定胜负——避免重蹈时间戳 LWW 的覆辙（§13.3）。

### 7.2 冲突弹窗：逐篇二选一

```
┌──────────────────────────────────────────────┐
│  同步冲突：《会议纪要》                          │
│                                                │
│  本地和远程都修改过这篇笔记，请选择保留哪一版：    │
│                                                │
│  · 本地版本    最后修改：2026-07-06 14:32        │
│  · 远程版本    最后修改：2026-07-06 15:10        │
│                                                │
│      [保留本地]   [用远程覆盖]   [取消]           │
└──────────────────────────────────────────────┘
```

三个动作：

- **保留本地**：本地内容不动，标记为待推送（`syncStatus = local`）；下一次同步会把本地版本推到远端，base ← 本地版本
- **用远程覆盖**：下载远端版本覆盖本地正文/标题/标签/分类，base ← 远端版本；本地原内容不另存（如需找回，可在远端 git 历史中查看，符合不变量 I3——被覆盖内容仍存于远端历史）
- **取消 / 关闭弹窗**：**保持本地不动，跳过该篇**，本轮不推不拉、不更新 base；下次同步仍会再次就这篇提示，直到用户作出选择

**多篇同时冲突**：逐篇弹窗，用户对每一篇单独决定；某篇取消只跳过该篇，不影响其余篇的同步与后续冲突篇的提示。

### 7.3 冲突不阻塞其余笔记

冲突处理发生在同步会话的**本地落盘阶段**（§8.1 步骤⑤）之后、以逐篇交互的形式进行；无冲突的笔记该推的推、该拉的拉，正常完成。冲突篇即使被用户取消，也只是维持现状等待下次，不会中断整个同步流水线（解 P5/P10）。

---

## 8. 同步会话：端到端流程

### 8.1 会话时序

```
acquire(syncMutex)                    ── 防重入；仅主窗口可发起（多窗口约束见 §11.3）
  ↓
① GET branch head → headSha           ── 乐观锁锚点（1 请求）
  ↓
② GET git/trees/{headSha}?recursive=1 ── 远程清单 [{path, blobSha}]，按 notesDir 前缀过滤（1 请求）
  ↓
③ 三方对账（§6.2 判定表，纯本地计算）
  → 计划 = {pulls, pushes, renames, deletes↑, deletes↓, conflicts}
  ↓
④ 下载需要内容的远端文件（pulls/新增/冲突项），解析 front-matter，
  完成重命名对账（§6.3），修订计划               ── 仅变更文件数个请求
  ↓
⑤ 执行本地落盘：导入/覆盖/删除；冲突项收集到冲突队列，暂不落盘（§7）
  ↓
⑥ 执行远端写入（§8.4）：
  GitHub → blobs + tree + commit(parent=headSha) + updateRef，单提交原子完成
  Gitee  → 逐文件 contents API（per-file sha 乐观锁），失败逐条记录不中断
  ↓
⑦ updateRef 被拒（远端在会话期间又前进了）→ 回到 ①，全程最多重试 3 次
  ↓
⑧ 成功项逐条更新 base；写同步日志（推 x 拉 y 删 z 冲 w）；更新 lastSyncTime
  ↓
⑨ 冲突队列非空 → 逐篇弹出二选一对话框（§7），用户裁决后落盘并按需推送
  ↓
release(syncMutex)
```

要点：

- **拉与推是同一会话的两个产物**，不再有独立的"先推后拉"两阶段（现 `fullSync` 的顺序耦合是 P10 的来源）。判定先行，读写分离
- 步骤⑥失败的个别文件只影响自身 base 不更新，下轮重判，**单点失败不中断全场**（解 P10）
- 会话期间用户仍可编辑：落盘前对每篇做二次校验，发现会话中又被用户改过的笔记跳过本轮（下轮自然按规则 2/4 处理）

### 8.2 请求数对比（解 P7/P8）

以 100 篇笔记、本次 3 改 1 删 2 新增为例：

| | 现行实现 | 本设计（GitHub） |
|---|---|---|
| 探测变更 | 1 + 目录数（列表）+ 100（逐文件下载） | 2（head + tree） |
| 下载 | 已含在上 | ≤ 5（仅变更文件） |
| 推送 | 6 次 contents API（6 个 commit） | 5（3 blob + tree + commit + ref ≈ 6 请求，**1 个 commit**） |
| 合计 | **100+ 请求** | **≈ 13 请求** |

### 8.3 提交信息规范

单提交聚合本轮全部变更，message 模板：

```
sync: 3 updated, 2 added, 1 deleted (from {设备名})

- update: 会议纪要.md
- add: 购物清单.md
…
```

设备名取值：Windows 用主机名，Android/iOS 用型号（`device_info_plus`），设置页可自定义。

### 8.4 远端写入的平台实现

- **GitHub**：Git Data API 组装单提交——`POST /git/blobs`（每个新内容）→ `POST /git/trees`（base_tree = headSha 的 tree，含删除项置 `sha: null`、重命名 = 旧路径 null + 新路径 blob）→ `POST /git/commits`（parent = headSha）→ `PATCH /git/refs/heads/{branch}`。updateRef 非 fast-forward 失败即步骤⑦重试，这是**仓库级乐观锁**，比 per-file sha 更强
- **Gitee**：v5 API 只有只读 git-data 端点，**无公开的 create-tree/create-commit/update-ref**（调研见 §10），维持逐文件 `contents` API + per-file sha 乐观锁；重命名退化为"先建新、后删旧"两次调用（顺序保证中断时不丢内容，最多残留一个旧文件，下轮按规则 6 清理）

---

## 9. 数据模型与存储变更

### 9.1 Note 模型（`lib/domain/models/note.dart`）

```dart
class Note {
  final String id;          // 不变；Markdown 笔记同时写入 front-matter
  String title;
  String content;           // 不含 front-matter 的正文
  // …existing fields…
  String? filePath;         // 仍保留：当前远端路径（展示层）
  String? sha;              // 语义变更 → 改名 remoteBlobSha：最近一次已知的远端 blob sha
}

/// 新增：base 快照，与 Note 分表存储
class NoteSyncBase {
  final String id;          // 关联 Note.id（txt 为路径）
  final String path;        // 上次共识时的远端路径（识别重命名用）
  final String blobSha;     // 上次共识版本的 git blob sha
  final String content;     // 上次共识版本全文（保留供未来能力扩展，二选一裁决本身不需要）
  final DateTime syncedAt;
}
```

- `SyncStatus` 枚举保留，但 `local` 由"内容 blob sha ≠ base.blobSha"推导，不再靠手工置位（标记只作 UI 缓存）
- `conflict` 判定不落地为持久状态：冲突在同步会话末尾（§8.1 步骤⑨）逐篇弹窗即时裁决，用户选定后笔记即回到 `synced`/`local`。`conflict` 枚举值保留仅供渲染兼容，正常流程不再长期驻留冲突态

### 9.2 存储

- base 表新增 shared_preferences key：`sync_base`（`List<NoteSyncBase>` JSON）
- 存储成本：base 保存全文使笔记存储约 ×2。纯文本量级可接受（1000 篇 × 平均 5KB ≈ 10MB）；后续若迁 SQLite（`drift`）可顺带压缩，列为独立技术债不阻塞本设计
- front-matter 解析/序列化：新增 `lib/utils/front_matter.dart`（无第三方依赖，手写 YAML 子集：仅 `key: scalar` 与 `key: [a, b]`，避免引入完整 YAML 库）

### 9.3 模块划分

```
lib/data/sync/
├── sync_engine.dart          # 会话编排（§8.1 状态机）+ 冲突队列回调
├── sync_engine_provider.dart # 引擎 provider + SyncNotesPort 适配 + 可注入 remote 工厂
├── sync_planner.dart         # 判定表 + 重命名对账（§6，纯函数，重点单测）
├── note_file_codec.dart      # Note ↔ 仓库文件编解码（front-matter 注入/剥离）
├── sync_base_store.dart      # base 快照表持久化
├── blob_sha.dart             # git blob sha 本地计算
└── remote/
    ├── remote_repo.dart      # 抽象：listTree/getBlob/commitChanges
    ├── github_remote.dart    # Git Data API 实现（原子提交）
    └── gitee_remote.dart     # contents API 降级实现
```

`remote_repo.dart` 抽象保证未来若引入真 git 引擎（§13.1）或新平台（GitLab/自建）时判定层零改动。

> M4 方向调整后不再需要 `diff3.dart`（三方合并）与 `conflict_service.dart`（冲突副本）。冲突改由引擎的冲突队列 + UI 层二选一对话框处理（§7）；`diff3.dart` 若已随 M1 落地，可作为未来「自动合并」能力的储备保留，但不接入主流程。

---

## 10. 平台能力矩阵与 API 效率

| 能力 | GitHub | Gitee | 引擎策略 |
|------|--------|-------|----------|
| 递归 tree 清单 | ✅ `GET /git/trees?recursive=1` | ✅ 同款只读端点 | 双平台走 tree 清单探测 |
| 读 blob | ✅ | ✅ | sha 变更才下载 |
| 原子多文件提交 | ✅ Git Data API 全套写端点 | ❌ 无公开写端点（[调研结论](https://gitee.com/api/v5/swagger)：v5 仅 contents 单文件写） | GitHub 单提交；Gitee 逐文件 + 会话级重试 |
| 单文件乐观锁 | ✅ contents PUT 带 sha | ✅ 同 | Gitee 路径的冲突防护 |
| 文件大小限制 | contents API 读 ≤1MB（超出走 blob API） | 类似 | 读一律走 blob API，不受限 |
| 限流 | 5000 次/时（授权） | 更严格（未公开细则） | 请求数正比变更量后，两端均富余 |

---

## 11. 触发时机与并发控制

### 11.1 触发点（均汇入同一 `SyncEngine.requestSync()` 入口）

| 触发 | 默认 | 说明 |
|------|------|------|
| 手动（现有按钮） | 保留 | 仓库页/列表页 |
| 应用启动后 | 延迟 5s | 避免抢首屏 |
| 编辑停顿 debounce | 30s，可配 | "尽快上传缩小冲突窗口"（Joplin 经验，§2.1） |
| 周期后台 | 10min，可配/可关 | 应用前台运行期间 |
| 网络恢复 | 开 | `connectivity_plus` 监听 |

移动端进入后台的持续同步（WorkManager/BGTask）**不在本期**：现阶段行为与提醒功能一致——仅应用运行期间工作，限制注明于 `features.md`。

### 11.2 并发控制

- 进程内互斥：`requestSync()` 在会话进行中被调用时置 `pendingFlag`，会话结束后立即补跑一轮（合并风暴）
- 同一仓库多设备并发推送：GitHub 由 updateRef 乐观锁串行化；Gitee 由 per-file sha 乐观锁保护，冲突方下轮重判

### 11.3 多窗口约束（Windows）

遵循既有多窗口架构（主窗口是唯一数据权威，见 `data-flow.md` 独立窗口章节）：**同步引擎只在主窗口运行**。子窗口编辑经 IPC 回流主窗口后自然纳入下轮判定；同步落盘引起的内容更新按现有 provider 镜像机制刷新子窗口只读视图。

---

## 12. 迁移方案

首次以 v2 引擎同步时执行一次性迁移会话：

1. 拉取远程清单与全部内容（等价现行为，最后一次全量）
2. 对每个远端文件：有 front-matter id → 直接对账；无 → 与本地笔记按 `filePath` 匹配（现行身份规则），匹配上沿用本地 id，匹配不上生成新 id
3. 为所有 Markdown 注入 front-matter，聚合成一个**升级提交**推送（GitHub 单提交 / Gitee 逐文件），message: `sync: migrate to gitnote sync v2 (inject note ids)`
4. 以推送后的内容与 blob sha 建立全量 base 表
5. 迁移完成前禁用增量判定；失败可整体重跑（幂等：已有 id 的文件跳过）

现存 `conflict` 状态笔记在迁移时按普通本地笔记对待：合成 base 后，若与远端内容不一致会在下次同步按规则 4 走二选一弹窗，由用户裁决，一次清账。旧字段 `sha` 数据自然废弃。

**回滚安全**：迁移只追加 front-matter 与本地 base 表，不改正文；旧版本 App 读到带 front-matter 的文件会把它当正文显示（可接受的降级），远端仓库始终可用 git 手段恢复任意历史。

---

## 13. 被否决的备选方案

### 13.1 内嵌真 Git（libgit2 / git2dart / dart_git）

- ✅ 语义最完备（本地历史、离线合并、任意远端协议）
- ❌ 移动端体积 +数 MB、内存峰值高（clone/packfile）、FFI 维护成本；GitJournal/obsidian-git 的移动端稳定性问题是前车之鉴（§2.3）
- **裁决**：否决为本期方案；`remote_repo.dart` 抽象已为桌面端未来挂真 git 引擎留口（Git Vault Sync 式双引擎），届时判定层/冲突层复用

### 13.2 CRDT（Yjs / Automerge 系）

- ✅ 理论上冲突免疫，适合实时协作
- ❌ 需要在仓库存二进制/操作日志状态文件，**破坏"远端是人类可读 Markdown 仓库"的核心卖点**；无实时协作需求；仍需处理"CRDT 状态文件 vs 用户直接改 md"的双源问题
- **裁决**：否决。单用户多设备 + 文件粒度，三方合并足够

### 13.3 时间戳 Last-Write-Wins

- ✅ 实现最简单
- ❌ 多端时钟不可信；Git API 拿不到可靠 mtime（P4 已经在现网证伪此路）；静默丢失慢设备上的修改，违反不变量 I3
- **裁决**：否决**自动** LWW。注意区别：本设计的冲突二选一（§7）也向用户展示时间，但时间只作**人工裁决的参考信息**，不参与"是否冲突"的判定（那一步仍纯靠内容 blob sha），也不由程序按时间自动选择——决策权始终在用户手上。这与"程序按时间戳自动覆盖"有本质不同

### 13.4 仓库级 manifest 清单文件

见 §5.2：集中清单是并发冲突热点，否决。

### 13.5 三层递进冲突策略（diff3 自动合并 → 冲突副本 → 三选一界面）

这是 v2 的**原设计**，在 M4 阶段被简化替换（见 §7），此处保留其分析供未来复评：

- **第一层 diff3 行级自动合并**：规则 4 触发时用 base/local/remote 做 git 同款三方行级合并，双方改动不重叠则干净合并、双写、用户无感；重叠才降级。可由 `autoMerge` 设置项关闭
- **第二层冲突副本**：合并失败时本地版另存为带 `conflict` 标签的新笔记（并参与同步，改进 Joplin 的"副本不同步"痛点），正身采纳远端，保证流水线永不阻塞
- **第三层解决界面**：并排对比 + 三选一（保留本地 / 保留远端 / 两篇都留）

- ✅ 能自动化的冲突大多无需打扰用户；任何一方内容都物理存在，无损保底
- ❌ 实现面广（diff3 移植 + 冲突副本生命周期 + 解决界面 + 差异高亮），心智负担重：用户要理解"冲突副本""正身""三选一"等概念；且 Joplin/Obsidian 的实践表明自动合并存在"悄悄合丢"的长尾风险（§2.2）
- **裁决**：M4 阶段否决为首版方案，简化为 §7 的二选一。判定层（§6，用 base 精确识别是否冲突）完全复用；若 `diff3.dart` 已随 M1 落地则作为储备保留，不接入主流程。未来如有强需求可在二选一对话框中增设"尝试自动合并"作为第三个选项，渐进引入

---

## 14. 分阶段实施计划

| 阶段 | 内容 | 交付判据 |
|------|------|----------|
| ✅ M1 基础设施 | `blob_sha` / `front_matter` / `diff3` / `sync_planner` 纯函数模块 + 单元测试（判定表 11 条规则逐条覆盖，diff3 期望值与 `git merge-file` 实测对齐，blob sha 期望值取自 `git hash-object` 实测） | `flutter test` 全绿（68 项新增用例）；不接 UI |
| ✅ M2 远端抽象 | `remote_repo` 接口 + GitHub Data API 实现 + Gitee contents 降级实现 | MockClient 单测覆盖请求序列/payload/错误映射（20 项）；`tool/remote_live_check.dart` 供真仓库联调（清单/读/原子提交/重命名/本地 sha 与服务端一致性），端点清单见 [api.md](./api.md) |
| ✅ M3 引擎接入 | `sync_engine` 会话状态机替换 `fullSync`；迁移吸收为会话内合成 base（§12）；base 表落地（`sync_base_store`）；`note_file_codec` 文件编解码；UI 三动作（拉/推/全量）收敛为单一「同步」，删除改为仅删本地由引擎传播 | `flutter test` 全绿（117 项，其中引擎端到端 14 项）；`flutter analyze` 零问题 |
| M4 冲突体验 | 冲突二选一对话框（§7.2，逐篇展示双方最后更新时间，保留本地/远端覆盖，取消跳过）；远端最后提交时间获取；同步日志明细 | 冲突场景端到端演示 |
| M5 触发与打磨 | debounce/周期/网络恢复触发；设置项（周期、设备名）；文档同步更新（features/data-flow/api/architecture） | 双平台（Windows + Android）验证 |

**M1 实施补充**（编码中确定的细化，均已落入代码与测试）：

- 判定器采用**两阶段调用协议**：首轮返回 `needsDownload`（含全部所需路径，一轮收齐），引擎下载后重新调用得到完整计划；`needsDownload` 非空时动作列表为空，禁止部分执行（`lib/data/sync/sync_planner.dart` 库注释）
- 路径占用判断**大小写不敏感**，避免产生仅大小写不同的路径导致仓库在 Windows 上 clone 时互踩；重命名时自身旧路径不算占用，因此允许纯大小写改名
- front-matter 解析**读宽容、写保守**：无法识别的行（外部工具如 Obsidian 写入的字段、注释、嵌套块）原样保留并按原顺序回写，只改动本应用管理的键，不丢外来数据（不变量 I3 的延伸）
- 存在未下载的未匹配远端文件时，base 路径消失的笔记**不判删除**（无法与重命名区分），推迟到下载完成后的下一轮判定
- 判定表新增两个隐含情形的显式动作：双端都删 → `ForgetBaseAction`（仅清 base）；双方改成相同内容（伪分叉）→ `AdoptBaseAction`（仅建 base，无网络 IO）

**M3 实施补充**（编码中确定的细化，均已落入代码与测试）：

- **删除语义改造**：v2 删除只删本地、保留 base 表作为墓碑，下次同步由引擎按规则 5/8 传播。旧的「删除时即时删远端」被移除——它会架空规则 8（本地删 + 远端改 → 保守恢复），可能静默丢掉另一端的修改。UI 层 `deleteNoteWithRemote`/`deleteNotesWithRemote` 及 `GitNotifier.deleteRemoteNote` 一并退役
- **单条推送退役**：v2 引擎是整仓库原子会话，无独立「推送单条」语义。编辑页「同步到远程」改为先保存再触发完整同步会话（`runSync`）
- **UI 动作收敛**：仓库页原「拉取 / 推送 / 全量」三个动作合并为单一「同步」，均调用 `GitNotifier.runSync()`
- **引擎不直写存储**：引擎经 `SyncNotesPort` 适配器（`sync_engine_provider.dart`）把所有变更流入 `NotesNotifier` 内存状态权威，再由其持久化，遵守多窗口不变量（见 data-flow.md 独立窗口章节）
- **远端可注入**：`remoteRepoFactoryProvider` 允许测试注入 fake remote，widget 测试无需真实网络即可覆盖同步入口
- **SnackBar 文案国际化**：同步完成提示用已国际化的 `syncSuccess`；`SyncReport.summary()` 的中文统计明细仅写入同步日志（诊断用途），不直接上 UI

**M3 验收场景清单**（双设备 A/B）：改标题跨端不重复（P1）✔；A 删 B 可见（P6）✔；A、B 改不同笔记互不干扰 ✔；A、B 改同一笔记不同段落自动合并双写 ✔；改同一段落生成冲突副本且两端可见 ✔；断网中途重试收敛 ✔；tags/分类跨端一致（P9）✔。

**M4 验收场景清单**（基于 M3，替换冲突处理为二选一）：双端改同一笔记 → UI 弹冲突对话框，展示双方最后更新时间；用户选「保留本地」→ 下次同步推送覆盖远端 ✔；用户选「用远程覆盖」→ 本地立即采纳远端内容 ✔；用户取消 → 冲突下次仍提示 ✔；冲突裁决后无冲突副本残留 ✔。

---

## 15. 参考资料

- [Joplin 同步规范](https://joplinapp.org/help/dev/spec/sync/) · [Joplin 冲突说明](https://joplinapp.org/help/apps/conflict/) · [Joplin 自动冲突解决（GSoC）](https://discourse.joplinapp.org/t/automatic-conflict-resolution/49050)
- [GitJournal](https://gitjournal.io/support/) · [GitJournal HN 讨论](https://news.ycombinator.com/item?id=31914003)
- [obsidian-git 多设备冲突处理议题](https://github.com/Vinzent03/obsidian-git/issues/803) · [Obsidian 冲突解决讨论](https://forum.obsidian.md/t/robust-sync-conflict-resolution/93544)
- [Git Vault Sync（双引擎设计）](https://community.obsidian.md/plugins/git-vault-sync)
- [GitHub Git Database API](https://docs.github.com/en/rest/git) · [Git Database API 入门](https://docs.github.com/en/rest/guides/getting-started-with-the-git-database-api)
- [Gitee OpenAPI v5](https://gitee.com/api/v5/swagger)
- [node-diff3（三方合并参考实现）](https://github.com/bhousel/node-diff3)

## 相关文档

- [数据流](./data-flow.md) - 现行同步实现的数据流（已随 M3 更新）
- [架构设计](./architecture.md) - 整体架构说明
- [API 文档](./api.md) - Git 平台 API 调用说明
