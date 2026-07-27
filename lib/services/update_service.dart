import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// A release on GitHub that is newer than what is installed.
@immutable
class AppUpdate {
  /// The tag with any leading `v` removed, so it compares against the version
  /// in the manifest.
  final String version;

  /// The `.apk` asset, or null for a release that published no build. Nothing
  /// can be installed from one of those; the release page is all there is.
  final String? apkUrl;

  /// The `.apk.sha256` published next to it, when there is one.
  final String? sha256Url;

  final String pageUrl;
  final String? notes;

  const AppUpdate({
    required this.version,
    required this.pageUrl,
    this.apkUrl,
    this.sha256Url,
    this.notes,
  });

  bool get installable => apkUrl != null;
}

/// What the updater is doing, for the progress bar.
enum UpdateStage { download, verify, install }

@immutable
class UpdateProgress {
  final UpdateStage stage;
  final int bytes;
  final int total;

  const UpdateProgress(this.stage, {this.bytes = 0, this.total = 0});

  /// Fraction downloaded, or null while the length is unknown — GitHub's asset
  /// redirect does not always carry one.
  double? get fraction => total > 0 ? (bytes / total).clamp(0.0, 1.0) : null;
}

/// Self-update from GitHub releases.
///
/// There is no store in this picture: the app is installed from an APK, so
/// there is nothing to publish an update through. The releases the CI builds
/// are the only channel, and this reads them.
///
/// The trust chain is worth stating, because "download an APK and run it" is
/// otherwise a bad idea:
///
/// 1. The release is built by GitHub Actions from a tag, not uploaded by hand.
/// 2. The download is checked against the `.sha256` published beside it, which
///    catches a truncated download and a swap in transit.
/// 3. Android refuses to install a package signed with a different key over
///    the installed one. That check is the system's, not ours, and it is the
///    one that actually matters.
///
/// Android only. Every other platform reports no update: iOS has no sideload
/// path, and the desktop targets are unmodified scaffolding.
class UpdateService {
  static const String repository = 'andrewkomkov/plane-mobile';

  static const String _api =
      'https://api.github.com/repos/$repository/releases/latest';
  static const String releasesUrl =
      'https://github.com/$repository/releases/latest';

  /// The channel [installApk] speaks. Implemented in `UpdateInstaller.kt`.
  static const MethodChannel _channel = MethodChannel('plane_mobile/updater');

  /// An APK larger than this is not one of ours.
  static const int _maxApkBytes = 300 * 1024 * 1024;

  /// Injected by tests in place of a real HTTP client.
  @visibleForTesting
  static Dio? debugClient;

  /// Overrides the installed version in tests.
  @visibleForTesting
  static String? debugCurrentVersion;

  static Dio _client() =>
      debugClient ??
      Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ));

  static Future<String> currentVersion() async {
    final injected = debugCurrentVersion;
    if (injected != null) return injected;
    return (await PackageInfo.fromPlatform()).version;
  }

  /// The latest release, or null when it is not newer than what is installed.
  static Future<AppUpdate?> check() async {
    if (!_supported) return null;
    try {
      final response = await _client().get<Map<String, dynamic>>(
        _api,
        options: Options(headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'plane-mobile',
        }),
      );
      final json = response.data;
      if (json == null) return null;

      final tag = (json['tag_name'] as String? ?? '').replaceFirst('v', '');
      if (tag.isEmpty) return null;
      if (compareVersions(tag, await currentVersion()) <= 0) return null;

      final assets = assetUrls(json['assets']);
      final notes = (json['body'] as String?)?.trim();
      return AppUpdate(
        version: tag,
        apkUrl: assets.apk,
        sha256Url: assets.sha256,
        pageUrl: (json['html_url'] as String?) ?? releasesUrl,
        notes: (notes == null || notes.isEmpty) ? null : notes,
      );
    } catch (_) {
      // A check that cannot reach GitHub is not an error worth a dialog — the
      // app works fine without one.
      return null;
    }
  }

  /// Download, verify and hand [update] to the system installer.
  ///
  /// [onProgress] is called as it goes. Returns null on success, or a message
  /// explaining what stopped it.
  static Future<String?> install(
    AppUpdate update, {
    void Function(UpdateProgress)? onProgress,
  }) async {
    final apkUrl = update.apkUrl;
    if (apkUrl == null) return 'That release has no build attached';
    if (!_supported) return 'Updating in place is Android-only';

    File? apk;
    try {
      onProgress?.call(const UpdateProgress(UpdateStage.download));
      apk = await _download(apkUrl, update.version, onProgress);

      onProgress?.call(const UpdateProgress(UpdateStage.verify));
      if (!await _verify(apk, update.sha256Url)) {
        await apk.delete();
        return 'The download did not match its published checksum';
      }

      onProgress?.call(const UpdateProgress(UpdateStage.install));
      await installApk(apk.path);
      return null;
    } on PlatformException catch (e) {
      return e.message ?? 'The installer refused the package';
    } catch (e) {
      await apk?.delete().catchError((_) => apk!);
      return 'Could not download the update';
    }
  }

  /// Hand a downloaded APK to Android's PackageInstaller.
  ///
  /// The system shows its own "update this app?" dialog and does the install;
  /// nothing here installs anything.
  static Future<void> installApk(String path) =>
      _channel.invokeMethod<void>('install', {'path': path});

  /// Whether the user has granted "install unknown apps", which Android only
  /// takes from its own settings screen.
  static Future<bool> canInstall() async {
    if (!_supported) return false;
    return await _channel.invokeMethod<bool>('canInstall') ?? false;
  }

  /// Open the settings screen where that permission is granted.
  static Future<void> requestInstallPermission() =>
      _channel.invokeMethod<void>('requestInstallPermission');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<File> _download(
    String url,
    String version,
    void Function(UpdateProgress)? onProgress,
  ) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/update');
    // Previous attempts are not worth keeping: an APK is large and exactly one
    // is ever wanted.
    if (dir.existsSync()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final target = File('${dir.path}/plane-mobile-$version.apk');

    await _client().download(
      url,
      target.path,
      options: Options(headers: {'User-Agent': 'plane-mobile'}),
      onReceiveProgress: (received, total) {
        if (received > _maxApkBytes) {
          throw Exception('apk is suspiciously large');
        }
        onProgress?.call(UpdateProgress(
          UpdateStage.download,
          bytes: received,
          total: total < 0 ? 0 : total,
        ));
      },
    );
    return target;
  }

  /// Compare against the checksum published beside the release.
  ///
  /// A release without one is not a reason to refuse: Android still checks the
  /// signature, which is the check that stops a hostile package. This one
  /// catches a truncated download and a swap before it.
  static Future<bool> _verify(File apk, String? sha256Url) async {
    if (sha256Url == null) return true;
    String published;
    try {
      final response = await _client().get<String>(
        sha256Url,
        options: Options(
          headers: {'User-Agent': 'plane-mobile'},
          responseType: ResponseType.plain,
        ),
      );
      published = response.data ?? '';
    } catch (_) {
      return true;
    }

    // `sha256sum` writes "<hash>  <filename>"; take the hash.
    final expected = published.trim().split(RegExp(r'\s+')).first.toLowerCase();
    if (expected.length != 64) return true;

    final digest = await _sha256(apk);
    return digest == expected;
  }

  static Future<String> _sha256(File file) async {
    final output = AccumulatorSink<Digest>();
    final input = sha256.startChunkedConversion(output);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    return output.events.single.toString();
  }

  /// The `.apk` and `.apk.sha256` asset URLs from a release payload.
  ///
  /// The order assets come back in is not guaranteed, so the whole list is
  /// walked — and `.apk.sha256` must not be mistaken for the APK, which is
  /// exactly what a naive `endsWith('.apk')` on a sorted list would do.
  @visibleForTesting
  static ({String? apk, String? sha256}) assetUrls(Object? assets) {
    String? apk;
    String? sha;
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map) continue;
        final name = asset['name']?.toString() ?? '';
        final url = asset['browser_download_url']?.toString() ?? '';
        if (url.isEmpty) continue;
        if (name.endsWith('.apk.sha256')) {
          sha ??= url;
        } else if (name.endsWith('.apk')) {
          apk ??= url;
        }
      }
    }
    return (apk: apk, sha256: sha);
  }

  /// Compare `1.10.0` against `1.9.3` by number rather than by string.
  ///
  /// Returns >0 when [a] is newer. A `-rc.1` style suffix on a segment is
  /// ignored rather than parsed: it only ever appears on a build nobody is
  /// meant to be offered.
  @visibleForTesting
  static int compareVersions(String a, String b) {
    List<int> parse(String v) => v
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(RegExp(r'^\d+').stringMatch(p) ?? '') ?? 0)
        .toList();

    final left = parse(a);
    final right = parse(b);
    for (var i = 0;
        i < (left.length > right.length ? left : right).length;
        i++) {
      final diff =
          (i < left.length ? left[i] : 0) - (i < right.length ? right[i] : 0);
      if (diff != 0) return diff;
    }
    return 0;
  }
}
