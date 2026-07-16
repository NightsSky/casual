import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/app_release.dart';

/// 应用内更新服务：查询 GitHub Release、比较版本、下载安装包并触发安装。
///
/// 跨平台策略（遵循项目规则 3）：
/// - Android：下载 `.apk` 到应用外部/临时目录，通过系统安装器打开安装（需
///   `REQUEST_INSTALL_PACKAGES` 权限）。
/// - Windows：下载 `.exe` 安装包或 `.zip` 压缩包到临时目录，用系统默认程序打开
///   （exe 直接运行安装器，zip 在资源管理器中打开供用户解压覆盖）。
/// - 其他平台：不支持自动下载，UI 应降级为打开 Release 页面。
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// 发布仓库（与 git remote 保持一致：https://github.com/NightsSky/casual）。
  static const String repoOwner = 'NightsSky';
  static const String repoName = 'casual';

  static String get _latestReleaseUrl =>
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  /// 当前平台是否支持应用内自动下载安装。
  static bool get supportsInAppDownload =>
      !kIsWeb && (Platform.isAndroid || Platform.isWindows);

  /// 读取当前应用版本号（来自 pubspec / 原生构建配置）。
  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// 查询最新 Release。网络失败或无 Release 时抛出异常，由调用方处理。
  Future<AppRelease> fetchLatestRelease() async {
    final response = await _client.get(
      Uri.parse(_latestReleaseUrl),
      headers: const {
        'Accept': 'application/vnd.github.v3+json',
      },
    );

    if (response.statusCode == 404) {
      throw const UpdateException('尚未发布任何版本');
    }
    if (response.statusCode != 200) {
      throw UpdateException('检查更新失败: HTTP ${response.statusCode}');
    }

    final data = _decodeJson(response.bodyBytes);
    return AppRelease.fromJson(data);
  }

  /// 检查是否有可用更新。
  ///
  /// 返回 [UpdateCheckResult]，包含最新 Release、当前版本以及是否需要升级。
  Future<UpdateCheckResult> checkForUpdate() async {
    final current = await currentVersion();
    final release = await fetchLatestRelease();
    final hasUpdate = AppRelease.isNewerVersion(release.tagName, current);
    return UpdateCheckResult(
      currentVersion: current,
      release: release,
      hasUpdate: hasUpdate,
    );
  }

  /// 下载指定资产到本地临时/下载目录，返回落地文件路径。
  ///
  /// [onProgress] 回传 0~1 的进度；总长度未知时回传 -1（不确定进度）。
  Future<String> downloadAsset(
    ReleaseAsset asset, {
    void Function(double progress, int received, int total)? onProgress,
  }) async {
    if (asset.downloadUrl.isEmpty) {
      throw const UpdateException('下载地址无效');
    }

    final dir = await _downloadDirectory();
    final filePath = p.join(dir.path, asset.name);
    final file = File(filePath);

    // 若已存在同名且完整的文件，直接复用，避免重复下载。
    if (await file.exists() && asset.size > 0) {
      final existingLength = await file.length();
      if (existingLength == asset.size) {
        onProgress?.call(1, existingLength, asset.size);
        return filePath;
      }
    }

    final request = http.Request('GET', Uri.parse(asset.downloadUrl));
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UpdateException('下载失败: HTTP ${response.statusCode}');
    }

    final total = response.contentLength ?? (asset.size > 0 ? asset.size : -1);
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call(received / total, received, total);
        } else {
          onProgress?.call(-1, received, -1);
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    return filePath;
  }

  /// 触发安装/打开已下载的文件。
  ///
  /// - Android：打开 apk，弹出系统安装界面。
  /// - Windows：打开 exe（运行安装器）或 zip（资源管理器中打开）。
  ///
  /// 返回 true 表示已成功交给系统处理。
  Future<bool> installDownloadedFile(String filePath) async {
    if (!File(filePath).existsSync()) {
      throw const UpdateException('安装文件不存在');
    }
    final result = await OpenFilex.open(filePath);
    return result.type == ResultType.done;
  }

  /// 下载目录：Android 用外部存储（安装器可访问），其余平台用临时目录。
  Future<Directory> _downloadDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        final dir = Directory(p.join(external.path, 'updates'));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    }
    final temp = await getTemporaryDirectory();
    final dir = Directory(p.join(temp.path, 'casual_updates'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Map<String, dynamic> _decodeJson(List<int> bytes) {
    final decoded = utf8.decode(bytes);
    final json = jsonDecode(decoded);
    return Map<String, dynamic>.from(json as Map);
  }

  void dispose() {
    _client.close();
  }
}

/// 检查更新的结果。
@immutable
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.release,
    required this.hasUpdate,
  });

  final String currentVersion;
  final AppRelease release;
  final bool hasUpdate;
}

/// 更新流程中的可读异常。
class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;

  @override
  String toString() => message;
}
