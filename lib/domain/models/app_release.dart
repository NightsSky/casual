import 'package:flutter/foundation.dart';

/// GitHub Release 中的一个可下载资产（附件）。
@immutable
class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  /// 资产文件名，例如 `casual-0.2.0.apk`、`casual-windows-0.2.0.zip`。
  final String name;

  /// 浏览器可直接下载的地址（GitHub 的 browser_download_url）。
  final String downloadUrl;

  /// 文件字节数，用于展示下载进度总量；缺失时为 0。
  final int size;

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name'] as String? ?? '',
      downloadUrl: json['browser_download_url'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isApk => name.toLowerCase().endsWith('.apk');
  bool get isWindowsExe => name.toLowerCase().endsWith('.exe');
  bool get isWindowsZip => name.toLowerCase().endsWith('.zip');
}

/// 一个应用发行版本，对应 GitHub 的一条 Release 记录。
@immutable
class AppRelease {
  const AppRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.assets,
    this.prerelease = false,
  });

  /// 版本标签，例如 `v0.2.0`。
  final String tagName;

  /// Release 标题。
  final String name;

  /// Release 说明（Markdown 文本）。
  final String body;

  /// Release 页面地址，作为无法自动下载时的降级入口。
  final String htmlUrl;

  /// 该 Release 的全部资产。
  final List<ReleaseAsset> assets;

  /// 是否为预发布版本。
  final bool prerelease;

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final rawAssets = json['assets'];
    final assets = <ReleaseAsset>[];
    if (rawAssets is List) {
      for (final item in rawAssets) {
        if (item is Map) {
          assets.add(ReleaseAsset.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return AppRelease(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? (json['tag_name'] as String? ?? ''),
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      assets: assets,
      prerelease: json['prerelease'] as bool? ?? false,
    );
  }

  /// 去除标签前缀 `v` 后的纯版本号，例如 `0.2.0`。
  String get versionNumber => normalizeVersion(tagName);

  /// 选取当前平台适用的下载资产。
  ///
  /// - Android：优先 `.apk`。
  /// - Windows：优先安装包 `.exe`，否则退回 `.zip` 压缩包。
  ///
  /// 找不到匹配资产时返回 null，UI 应降级为打开 [htmlUrl]。
  ReleaseAsset? assetForPlatform({required bool isAndroid, required bool isWindows}) {
    if (isAndroid) {
      for (final asset in assets) {
        if (asset.isApk) return asset;
      }
      return null;
    }
    if (isWindows) {
      for (final asset in assets) {
        if (asset.isWindowsExe) return asset;
      }
      for (final asset in assets) {
        if (asset.isWindowsZip) return asset;
      }
      return null;
    }
    return null;
  }

  /// 去掉版本字符串里的 `v`/`V` 前缀以及构建号（`+` 之后的部分）。
  static String normalizeVersion(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return value;
    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }
    final plusIndex = value.indexOf('+');
    if (plusIndex != -1) {
      value = value.substring(0, plusIndex);
    }
    return value.trim();
  }

  /// 语义化版本比较：[remote] 是否比 [current] 更新。
  ///
  /// 逐段比较数字（`1.2.0` → [1,2,0]），缺失段补 0；非数字段忽略。
  /// 无法解析时保守返回 false，避免误报升级。
  static bool isNewerVersion(String remote, String current) {
    final remoteParts = _versionSegments(normalizeVersion(remote));
    final currentParts = _versionSegments(normalizeVersion(current));
    if (remoteParts.isEmpty || currentParts.isEmpty) return false;

    final length =
        remoteParts.length > currentParts.length ? remoteParts.length : currentParts.length;
    for (var i = 0; i < length; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  static List<int> _versionSegments(String version) {
    if (version.isEmpty) return const [];
    // 仅取主版本部分（忽略 `-beta` 等预发布后缀）后按 `.` 拆分。
    final core = version.split('-').first;
    final segments = <int>[];
    for (final part in core.split('.')) {
      final parsed = int.tryParse(part.trim());
      if (parsed == null) break;
      segments.add(parsed);
    }
    return segments;
  }
}
