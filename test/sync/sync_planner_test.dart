import 'package:casual/data/sync/blob_sha.dart';
import 'package:casual/data/sync/sync_planner.dart';
import 'package:flutter_test/flutter_test.dart';

// 测试脚手架：以内容自动算 sha，保持夹具与真实清单一致。
BaseEntry baseOf(String key, String path, String content) => BaseEntry(
      key: key,
      path: path,
      blobSha: computeBlobSha(content),
      content: content,
    );

RemoteFileState remoteOf(String path, String content) =>
    RemoteFileState(path: path, blobSha: computeBlobSha(content));

LocalFileState localOf(
  String key,
  String? path,
  String content, {
  String title = '笔记',
  String extension = 'md',
}) =>
    LocalFileState(
      key: key,
      path: path,
      title: title,
      extension: extension,
      content: content,
    );

DownloadedRemoteFile dlOf(String path, String content, {String? id}) =>
    DownloadedRemoteFile(path: path, content: content, frontMatterId: id);

void main() {
  const dir = 'notes';

  group('判定表（doc/sync-design.md §6.2）', () {
    test('规则 1：双方均未变 → 无动作', () {
      final plan = planSync(
        locals: [localOf('k1', 'notes/笔记.md', 'v1')],
        bases: [baseOf('k1', 'notes/笔记.md', 'v1')],
        remoteFiles: [remoteOf('notes/笔记.md', 'v1')],
        notesDir: dir,
      );
      expect(plan.needsDownload, isEmpty);
      expect(plan.actions, isEmpty);
    });

    test('规则 2：仅本地变 → 推送，带远端 sha 乐观锁', () {
      final plan = planSync(
        locals: [localOf('k1', 'notes/笔记.md', 'v2')],
        bases: [baseOf('k1', 'notes/笔记.md', 'v1')],
        remoteFiles: [remoteOf('notes/笔记.md', 'v1')],
        notesDir: dir,
      );
      final push = plan.actions.single as PushAction;
      expect(push.key, 'k1');
      expect(push.path, 'notes/笔记.md');
      expect(push.oldPath, isNull);
      expect(push.content, 'v2');
      expect(push.remoteBlobSha, computeBlobSha('v1'));
      expect(push.recreatesRemoteDeleted, isFalse);
    });

    test('规则 2 重命名变体：md 改标题 → 新旧路径成对推送', () {
      final plan = planSync(
        locals: [
          localOf('abcdefgh1234', 'notes/旧标题.md', 'v1', title: '新标题'),
        ],
        bases: [baseOf('abcdefgh1234', 'notes/旧标题.md', 'v1')],
        remoteFiles: [remoteOf('notes/旧标题.md', 'v1')],
        notesDir: dir,
      );
      final push = plan.actions.single as PushAction;
      expect(push.path, 'notes/新标题.md');
      expect(push.oldPath, 'notes/旧标题.md');
      expect(push.remoteBlobSha, computeBlobSha('v1'));
    });

    test('规则 2：txt 不因标题重命名（路径即身份）', () {
      final plan = planSync(
        locals: [
          localOf('notes/old.txt', 'notes/old.txt', 'v2',
              title: '完全不同的标题', extension: 'txt'),
        ],
        bases: [baseOf('notes/old.txt', 'notes/old.txt', 'v1')],
        remoteFiles: [remoteOf('notes/old.txt', 'v1')],
        notesDir: dir,
      );
      final push = plan.actions.single as PushAction;
      expect(push.path, 'notes/old.txt');
      expect(push.oldPath, isNull);
    });

    test('规则 3：仅远端变 → 先索要下载，再产出拉取', () {
      final locals = [localOf('k1', 'notes/笔记.md', 'v1')];
      final bases = [baseOf('k1', 'notes/笔记.md', 'v1')];
      final remotes = [remoteOf('notes/笔记.md', 'v2')];

      final draft = planSync(
        locals: locals,
        bases: bases,
        remoteFiles: remotes,
        notesDir: dir,
      );
      expect(draft.needsDownload, ['notes/笔记.md']);
      expect(draft.actions, isEmpty);

      final plan = planSync(
        locals: locals,
        bases: bases,
        remoteFiles: remotes,
        notesDir: dir,
        downloads: {'notes/笔记.md': dlOf('notes/笔记.md', 'v2', id: 'k1')},
      );
      final pull = plan.actions.single as PullAction;
      expect(pull.key, 'k1');
      expect(pull.content, 'v2');
      expect(pull.blobSha, computeBlobSha('v2'));
      expect(pull.isNew, isFalse);
      expect(pull.restoresLocalDeleted, isFalse);
    });

    test('规则 4：双方都变 → 产出三方合并动作', () {
      final plan = planSync(
        locals: [localOf('k1', 'notes/笔记.md', 'local 版')],
        bases: [baseOf('k1', 'notes/笔记.md', 'base 版')],
        remoteFiles: [remoteOf('notes/笔记.md', 'remote 版')],
        notesDir: dir,
        downloads: {'notes/笔记.md': dlOf('notes/笔记.md', 'remote 版', id: 'k1')},
      );
      final merge = plan.actions.single as MergeAction;
      expect(merge.baseContent, 'base 版');
      expect(merge.localContent, 'local 版');
      expect(merge.remoteContent, 'remote 版');
      expect(merge.remoteBlobSha, computeBlobSha('remote 版'));
      expect(merge.path, 'notes/笔记.md');
    });

    test('规则 4 伪分叉：双方改成相同内容 → 只建 base，无网络 IO', () {
      final plan = planSync(
        locals: [localOf('k1', 'notes/笔记.md', '同一份新内容')],
        bases: [baseOf('k1', 'notes/笔记.md', '旧内容')],
        remoteFiles: [remoteOf('notes/笔记.md', '同一份新内容')],
        notesDir: dir,
      );
      final adopt = plan.actions.single as AdoptBaseAction;
      expect(adopt.blobSha, computeBlobSha('同一份新内容'));
      expect(plan.needsDownload, isEmpty, reason: '内容已一致，无需下载');
    });

    test('规则 5：本地删、远端未变 → 删除远端', () {
      final plan = planSync(
        locals: [],
        bases: [baseOf('k1', 'notes/笔记.md', 'v1')],
        remoteFiles: [remoteOf('notes/笔记.md', 'v1')],
        notesDir: dir,
      );
      final del = plan.actions.single as DeleteRemoteAction;
      expect(del.path, 'notes/笔记.md');
      expect(del.remoteBlobSha, computeBlobSha('v1'));
    });

    test('规则 6：远端删、本地未变 → 删除本地', () {
      final plan = planSync(
        locals: [localOf('k1', 'notes/笔记.md', 'v1')],
        bases: [baseOf('k1', 'notes/笔记.md', 'v1')],
        remoteFiles: [],
        notesDir: dir,
      );
      expect(plan.actions.single, isA<DeleteLocalAction>());
    });

    test('规则 7：远端删、本地有改 → 重建远端并标记提示', () {
      final plan = planSync(
        locals: [localOf('k1', 'notes/笔记.md', 'v2', title: '笔记')],
        bases: [baseOf('k1', 'notes/笔记.md', 'v1')],
        remoteFiles: [],
        notesDir: dir,
      );
      final push = plan.actions.single as PushAction;
      expect(push.recreatesRemoteDeleted, isTrue);
      expect(push.path, 'notes/笔记.md', reason: '旧路径已空闲，优先复用');
      expect(push.remoteBlobSha, isNull, reason: '远端文件已不存在，创建无需乐观锁');
    });

    test('规则 8：本地删、远端有改 → 恢复到本地并标记提示', () {
      final bases = [baseOf('k1', 'notes/笔记.md', 'v1')];
      final remotes = [remoteOf('notes/笔记.md', 'v2')];

      final draft = planSync(
          locals: [], bases: bases, remoteFiles: remotes, notesDir: dir);
      expect(draft.needsDownload, ['notes/笔记.md']);

      final plan = planSync(
        locals: [],
        bases: bases,
        remoteFiles: remotes,
        notesDir: dir,
        downloads: {'notes/笔记.md': dlOf('notes/笔记.md', 'v2', id: 'k1')},
      );
      final pull = plan.actions.single as PullAction;
      expect(pull.restoresLocalDeleted, isTrue);
      expect(pull.content, 'v2');
    });

    test('规则 9：本地新建 → 推送到分配路径', () {
      final plan = planSync(
        locals: [localOf('k1', null, 'v1', title: '全新笔记')],
        bases: [],
        remoteFiles: [],
        notesDir: dir,
      );
      final push = plan.actions.single as PushAction;
      expect(push.path, 'notes/全新笔记.md');
      expect(push.remoteBlobSha, isNull);
    });

    test('规则 10：远端新增 → 下载后导入（md 带 id / md 无 id / txt）', () {
      final remotes = [
        remoteOf('notes/a.md', 'A'),
        remoteOf('notes/b.md', 'B'),
        remoteOf('notes/c.txt', 'C'),
      ];
      final draft = planSync(
          locals: [], bases: [], remoteFiles: remotes, notesDir: dir);
      expect(draft.needsDownload, ['notes/a.md', 'notes/b.md', 'notes/c.txt']);
      expect(draft.actions, isEmpty);

      final plan = planSync(
        locals: [],
        bases: [],
        remoteFiles: remotes,
        notesDir: dir,
        downloads: {
          'notes/a.md': dlOf('notes/a.md', 'A', id: 'ida'),
          'notes/b.md': dlOf('notes/b.md', 'B'),
          'notes/c.txt': dlOf('notes/c.txt', 'C'),
        },
      );
      final pulls = plan.actions.cast<PullAction>().toList();
      expect(pulls, hasLength(3));
      expect(pulls.every((a) => a.isNew), isTrue);

      final a = pulls.singleWhere((x) => x.path == 'notes/a.md');
      expect(a.key, 'ida');
      expect(a.needsIdInjection, isFalse);

      final b = pulls.singleWhere((x) => x.path == 'notes/b.md');
      expect(b.key, 'notes/b.md');
      expect(b.needsIdInjection, isTrue, reason: '外部创建的 md 收编时注入 id');

      final c = pulls.singleWhere((x) => x.path == 'notes/c.txt');
      expect(c.key, 'notes/c.txt');
      expect(c.needsIdInjection, isFalse, reason: 'txt 保持纯文本，不注入');
    });

    test('规则 11：双端同源新建同 id，内容相同 → 只建 base', () {
      final plan = planSync(
        locals: [localOf('same-id', null, '同内容')],
        bases: [],
        remoteFiles: [remoteOf('notes/x.md', '同内容')],
        notesDir: dir,
        downloads: {'notes/x.md': dlOf('notes/x.md', '同内容', id: 'same-id')},
      );
      final adopt = plan.actions.single as AdoptBaseAction;
      expect(adopt.key, 'same-id');
      expect(adopt.path, 'notes/x.md');
    });

    test('规则 11：双端同源新建同 id，内容不同 → 空 base 合并', () {
      final plan = planSync(
        locals: [localOf('same-id', null, '本地内容')],
        bases: [],
        remoteFiles: [remoteOf('notes/x.md', '远端内容')],
        notesDir: dir,
        downloads: {'notes/x.md': dlOf('notes/x.md', '远端内容', id: 'same-id')},
      );
      final merge = plan.actions.single as MergeAction;
      expect(merge.baseContent, '');
      expect(merge.localContent, '本地内容');
      expect(merge.remoteContent, '远端内容');
    });

    test('双端都删 → 仅清 base', () {
      final plan = planSync(
        locals: [],
        bases: [baseOf('k1', 'notes/笔记.md', 'v1')],
        remoteFiles: [],
        notesDir: dir,
      );
      expect(plan.actions.single, isA<ForgetBaseAction>());
    });
  });

  group('重命名对账（§6.3）', () {
    final base = baseOf('k1', 'notes/旧名.md', 'v1');

    test('远端仅重命名 → 本地记录迁移，不误判删除', () {
      final plan = planSync(
        locals: [localOf('k1', 'notes/旧名.md', 'v1', title: '旧名')],
        bases: [base],
        remoteFiles: [remoteOf('notes/新名.md', 'v1')],
        notesDir: dir,
        downloads: {'notes/新名.md': dlOf('notes/新名.md', 'v1', id: 'k1')},
      );
      final pull = plan.actions.single as PullAction;
      expect(pull.oldPath, 'notes/旧名.md');
      expect(pull.path, 'notes/新名.md');
      expect(pull.isNew, isFalse);
    });

    test('远端重命名 + 内容修改 → 拉取到新路径', () {
      final plan = planSync(
        locals: [localOf('k1', 'notes/旧名.md', 'v1', title: '旧名')],
        bases: [base],
        remoteFiles: [remoteOf('notes/新名.md', 'v2')],
        notesDir: dir,
        downloads: {'notes/新名.md': dlOf('notes/新名.md', 'v2', id: 'k1')},
      );
      final pull = plan.actions.single as PullAction;
      expect(pull.path, 'notes/新名.md');
      expect(pull.content, 'v2');
    });

    test('远端重命名 + 本地内容修改 → 合并，落点取远端新路径', () {
      final plan = planSync(
        locals: [localOf('k1', 'notes/旧名.md', 'v-local', title: '旧名')],
        bases: [base],
        remoteFiles: [remoteOf('notes/新名.md', 'v-remote')],
        notesDir: dir,
        downloads: {'notes/新名.md': dlOf('notes/新名.md', 'v-remote', id: 'k1')},
      );
      final merge = plan.actions.single as MergeAction;
      expect(merge.path, 'notes/新名.md');
      expect(merge.oldPath, 'notes/旧名.md');
      expect(merge.baseContent, 'v1');
    });

    test('远端重命名 + 本地仅内容变 → 推送到远端新路径', () {
      final plan = planSync(
        locals: [localOf('k1', 'notes/旧名.md', 'v2', title: '旧名')],
        bases: [base],
        remoteFiles: [remoteOf('notes/新名.md', 'v1')],
        notesDir: dir,
        downloads: {'notes/新名.md': dlOf('notes/新名.md', 'v1', id: 'k1')},
      );
      final push = plan.actions.single as PushAction;
      expect(push.path, 'notes/新名.md');
      expect(push.content, 'v2');
      expect(push.remoteBlobSha, computeBlobSha('v1'));
    });

    test('本地删 + 远端仅重命名 → 删除传播到新路径', () {
      final plan = planSync(
        locals: [],
        bases: [base],
        remoteFiles: [remoteOf('notes/新名.md', 'v1')],
        notesDir: dir,
        downloads: {'notes/新名.md': dlOf('notes/新名.md', 'v1', id: 'k1')},
      );
      final del = plan.actions.single as DeleteRemoteAction;
      expect(del.path, 'notes/新名.md');
    });

    test('有未下载的未匹配文件时，不把消失的 base 路径误判为删除', () {
      final plan = planSync(
        locals: [localOf('k1', 'notes/旧名.md', 'v1', title: '旧名')],
        bases: [base],
        remoteFiles: [remoteOf('notes/新名.md', 'v1')],
        notesDir: dir,
        // 未提供 downloads → 无法知道新名.md 的 id
      );
      expect(plan.needsDownload, ['notes/新名.md']);
      expect(plan.actions, isEmpty);
    });
  });

  group('重复 id（§5.4）', () {
    test('远端出现同 id 第二个文件 → 按新笔记导入并要求改写 id', () {
      final plan = planSync(
        locals: [localOf('k1', 'notes/正身.md', 'v1', title: '正身')],
        bases: [baseOf('k1', 'notes/正身.md', 'v1')],
        remoteFiles: [
          remoteOf('notes/正身.md', 'v1'),
          remoteOf('notes/手工副本.md', 'v1-copy'),
        ],
        notesDir: dir,
        downloads: {
          'notes/手工副本.md': dlOf('notes/手工副本.md', 'v1-copy', id: 'k1'),
        },
      );
      final pull = plan.actions.single as PullAction;
      expect(pull.duplicateOfKey, 'k1');
      expect(pull.isNew, isTrue);
      expect(pull.path, 'notes/手工副本.md');
    });
  });

  group('路径分配与清洗（§5.3）', () {
    test('sanitizeFileTitle：非法字符、首尾点空格、控制字符', () {
      expect(sanitizeFileTitle(r'a/b\c:d*e?f"g<h>i|j'), 'a-b-c-d-e-f-g-h-i-j');
      expect(sanitizeFileTitle('  .标题. '), '标题');
      expect(sanitizeFileTitle('a\x01b'), 'ab');
      expect(sanitizeFileTitle(''), 'untitled');
      expect(sanitizeFileTitle(' . '), 'untitled');
    });

    test('sanitizeFileTitle：Windows 保留名与长度截断', () {
      expect(sanitizeFileTitle('CON'), 'CON-note');
      expect(sanitizeFileTitle('com1'), 'com1-note');
      final long = sanitizeFileTitle('长' * 100);
      expect(long.length, 80);
    });

    test('路径碰撞：其他笔记占用 → 追加短 id 后缀', () {
      final plan = planSync(
        locals: [localOf('abcdefgh1234', null, 'v1', title: '会议')],
        bases: [],
        remoteFiles: [remoteOf('notes/会议.md', '别人的')],
        notesDir: dir,
        downloads: {'notes/会议.md': dlOf('notes/会议.md', '别人的', id: 'other')},
      );
      final push = plan.actions.whereType<PushAction>().single;
      expect(push.path, 'notes/会议-abcdefgh.md');
    });

    test('路径碰撞大小写不敏感（防 Windows 克隆互踩）', () {
      final occupied = <String>{'notes/note.md'};
      final path = allocatePath(
        dir: 'notes',
        title: 'Note',
        key: 'abcdefgh1234',
        extension: 'md',
        occupiedLower: occupied,
      );
      expect(path, 'notes/Note-abcdefgh.md');
    });

    test('同一轮规划内不重复分配同一路径', () {
      final plan = planSync(
        locals: [
          localOf('key-aaaaaaaa', null, 'v1', title: '同名'),
          localOf('key-bbbbbbbb', null, 'v2', title: '同名'),
        ],
        bases: [],
        remoteFiles: [],
        notesDir: dir,
      );
      final paths =
          plan.actions.whereType<PushAction>().map((a) => a.path).toSet();
      expect(paths, hasLength(2));
      expect(paths, contains('notes/同名.md'));
    });

    test('重命名时自身旧路径不算占用（仅大小写变化也允许）', () {
      final plan = planSync(
        locals: [
          localOf('abcdefgh1234', 'notes/note.md', 'v1', title: 'Note'),
        ],
        bases: [baseOf('abcdefgh1234', 'notes/note.md', 'v1')],
        remoteFiles: [remoteOf('notes/note.md', 'v1')],
        notesDir: dir,
      );
      final push = plan.actions.single as PushAction;
      expect(push.path, 'notes/Note.md');
      expect(push.oldPath, 'notes/note.md');
    });

    test('已带短 id 后缀的文件名不触发再次重命名', () {
      final plan = planSync(
        locals: [
          localOf('abcdefgh1234', 'notes/会议-abcdefgh.md', 'v1', title: '会议'),
        ],
        bases: [baseOf('abcdefgh1234', 'notes/会议-abcdefgh.md', 'v1')],
        remoteFiles: [remoteOf('notes/会议-abcdefgh.md', 'v1')],
        notesDir: dir,
      );
      expect(plan.actions, isEmpty);
    });
  });

  group('输入校验与确定性', () {
    test('重复身份键直接抛错', () {
      expect(
        () => planSync(
          locals: [localOf('k1', null, 'a'), localOf('k1', null, 'b')],
          bases: [],
          remoteFiles: [],
          notesDir: dir,
        ),
        throwsArgumentError,
      );
    });

    test('动作按身份键排序输出，多次运行一致', () {
      List<String> run() {
        final plan = planSync(
          locals: [
            localOf('kb', 'notes/b.md', 'b2'),
            localOf('ka', 'notes/a.md', 'a2'),
          ],
          bases: [
            baseOf('ka', 'notes/a.md', 'a1'),
            baseOf('kb', 'notes/b.md', 'b1'),
          ],
          remoteFiles: [
            remoteOf('notes/a.md', 'a1'),
            remoteOf('notes/b.md', 'b1'),
          ],
          notesDir: dir,
        );
        return plan.actions.map((a) => a.key).toList();
      }

      expect(run(), ['ka', 'kb']);
      expect(run(), run());
    });
  });
}
