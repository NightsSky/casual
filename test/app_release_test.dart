import 'package:casual/domain/models/app_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRelease.isNewerVersion', () {
    test('远端更高时返回 true', () {
      expect(AppRelease.isNewerVersion('v0.2.0', '0.1.0'), isTrue);
      expect(AppRelease.isNewerVersion('1.0.0', '0.9.9'), isTrue);
      expect(AppRelease.isNewerVersion('0.1.10', '0.1.9'), isTrue);
    });

    test('相同或更低时返回 false', () {
      expect(AppRelease.isNewerVersion('v0.1.0', '0.1.0'), isFalse);
      expect(AppRelease.isNewerVersion('0.1.0', '0.2.0'), isFalse);
    });

    test('段数不同按补零比较', () {
      expect(AppRelease.isNewerVersion('0.2', '0.1.9'), isTrue);
      expect(AppRelease.isNewerVersion('0.1', '0.1.0'), isFalse);
    });

    test('忽略 v 前缀与构建号', () {
      expect(AppRelease.normalizeVersion('v1.2.3+45'), '1.2.3');
      expect(AppRelease.isNewerVersion('v0.2.0', '0.1.0+7'), isTrue);
    });

    test('无法解析时保守返回 false', () {
      expect(AppRelease.isNewerVersion('abc', '0.1.0'), isFalse);
      expect(AppRelease.isNewerVersion('', '0.1.0'), isFalse);
    });
  });

  group('AppRelease.assetForPlatform', () {
    const apk = ReleaseAsset(
        name: 'casual-0.2.0.apk', downloadUrl: 'https://x/apk', size: 1);
    const exe = ReleaseAsset(
        name: 'casual-setup-0.2.0.exe', downloadUrl: 'https://x/exe', size: 2);
    const zip = ReleaseAsset(
        name: 'casual-windows-0.2.0.zip', downloadUrl: 'https://x/zip', size: 3);

    AppRelease releaseWith(List<ReleaseAsset> assets) => AppRelease(
          tagName: 'v0.2.0',
          name: 'v0.2.0',
          body: '',
          htmlUrl: 'https://github.com/NightsSky/casual/releases/tag/v0.2.0',
          assets: assets,
        );

    test('Android 选 apk', () {
      final asset = releaseWith(const [zip, apk, exe])
          .assetForPlatform(isAndroid: true, isWindows: false);
      expect(asset?.name, apk.name);
    });

    test('Windows 优先 exe，无 exe 退回 zip', () {
      expect(
        releaseWith(const [zip, apk, exe])
            .assetForPlatform(isAndroid: false, isWindows: true)
            ?.name,
        exe.name,
      );
      expect(
        releaseWith(const [zip, apk])
            .assetForPlatform(isAndroid: false, isWindows: true)
            ?.name,
        zip.name,
      );
    });

    test('无匹配资产返回 null', () {
      expect(
        releaseWith(const [])
            .assetForPlatform(isAndroid: true, isWindows: false),
        isNull,
      );
    });
  });

  test('AppRelease.fromJson 解析 GitHub Release 字段', () {
    final release = AppRelease.fromJson(const {
      'tag_name': 'v0.2.0',
      'name': 'casual 0.2.0',
      'body': '- 新增应用内更新',
      'html_url': 'https://github.com/NightsSky/casual/releases/tag/v0.2.0',
      'prerelease': false,
      'assets': [
        {
          'name': 'casual-0.2.0.apk',
          'browser_download_url': 'https://x/apk',
          'size': 1024,
        },
      ],
    });
    expect(release.tagName, 'v0.2.0');
    expect(release.versionNumber, '0.2.0');
    expect(release.assets, hasLength(1));
    expect(release.assets.single.isApk, isTrue);
  });
}
