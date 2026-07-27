import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/services/update_service.dart';

class _FakeAdapter implements HttpClientAdapter {
  final Object? body;
  final int status;
  final List<RequestOptions> calls = [];

  _FakeAdapter(this.body, {this.status = 200});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    if (status != 200) {
      return ResponseBody.fromString('{}', status, headers: _headers);
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: _headers);
  }

  static const _headers = {
    Headers.contentTypeHeader: ['application/json'],
  };

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> release({
  String tag = 'v1.2.0',
  List<Map<String, String>> assets = const [],
  String body = 'Notes',
}) =>
    {
      'tag_name': tag,
      'html_url': 'https://github.com/andrewkomkov/plane-mobile/releases/v1',
      'body': body,
      'assets': assets,
    };

Map<String, String> asset(String name) => {
      'name': name,
      'browser_download_url': 'https://example.invalid/$name',
    };

void main() {
  setUp(() {
    // The check is Android-only; the tests run on the host, so pretend.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    UpdateService.debugCurrentVersion = '1.0.0';
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    UpdateService.debugClient = null;
    UpdateService.debugCurrentVersion = null;
  });

  void wire(Object? body, {int status = 200}) {
    UpdateService.debugClient = Dio()
      ..httpClientAdapter = _FakeAdapter(body, status: status);
  }

  group('compareVersions', () {
    test('compares by number, not by string', () {
      // The whole reason this exists: "1.10.0" sorts before "1.9.3" as text.
      expect(UpdateService.compareVersions('1.10.0', '1.9.3'), greaterThan(0));
      expect(UpdateService.compareVersions('1.9.3', '1.10.0'), lessThan(0));
    });

    test('equal versions compare equal', () {
      expect(UpdateService.compareVersions('2.0.1', '2.0.1'), 0);
    });

    test('a missing segment counts as zero', () {
      expect(UpdateService.compareVersions('1.2', '1.2.0'), 0);
      expect(UpdateService.compareVersions('1.2.1', '1.2'), greaterThan(0));
    });

    test('the build suffix does not decide it', () {
      expect(UpdateService.compareVersions('1.2.0+42', '1.2.0+7'), 0);
    });

    test('a non-numeric suffix on a segment is ignored', () {
      expect(
          UpdateService.compareVersions('1.3.0-rc.1', '1.2.0'), greaterThan(0));
    });
  });

  group('assetUrls', () {
    test('tells the checksum apart from the package', () {
      // `.apk.sha256` also ends in a suffix a careless check would take for
      // the APK; here the checksum is listed first on purpose.
      final urls = UpdateService.assetUrls([
        asset('plane-mobile-1.2.0.apk.sha256'),
        asset('plane-mobile-1.2.0.apk'),
      ]);

      expect(urls.apk, endsWith('plane-mobile-1.2.0.apk'));
      expect(urls.sha256, endsWith('.apk.sha256'));
    });

    test('a release with no build has no apk url', () {
      final urls = UpdateService.assetUrls([asset('sources.zip')]);
      expect(urls.apk, isNull);
    });

    test('missing or malformed assets do not throw', () {
      expect(UpdateService.assetUrls(null).apk, isNull);
      expect(UpdateService.assetUrls('nonsense').apk, isNull);
      expect(UpdateService.assetUrls([1, 'two']).apk, isNull);
    });
  });

  group('check', () {
    test('offers a newer release', () async {
      wire(release(tag: 'v1.2.0', assets: [asset('app.apk')]));

      final update = await UpdateService.check();

      expect(update, isNotNull);
      expect(update!.version, '1.2.0');
      expect(update.installable, isTrue);
    });

    test('says nothing when the release matches what is installed', () async {
      wire(release(tag: 'v1.0.0'));
      expect(await UpdateService.check(), isNull);
    });

    test('says nothing when the release is older', () async {
      wire(release(tag: 'v0.9.0'));
      expect(await UpdateService.check(), isNull);
    });

    test('a tag without the v prefix still compares', () async {
      wire(release(tag: '1.1.0'));
      expect((await UpdateService.check())?.version, '1.1.0');
    });

    test('a release with no build is still offered, but not installable',
        () async {
      wire(release(tag: 'v1.2.0', assets: const []));

      final update = await UpdateService.check();

      expect(update, isNotNull);
      expect(update!.installable, isFalse);
    });

    test('an unreachable GitHub is not an error the user sees', () async {
      wire(null, status: 503);
      expect(await UpdateService.check(), isNull);
    });

    test('blank release notes become null rather than an empty dialog',
        () async {
      wire(release(tag: 'v1.2.0', body: '   '));
      expect((await UpdateService.check())?.notes, isNull);
    });

    test('reads the repository this app is published from', () async {
      final adapter = _FakeAdapter(release(tag: 'v1.0.0'));
      UpdateService.debugClient = Dio()..httpClientAdapter = adapter;

      await UpdateService.check();

      expect(adapter.calls.single.uri.toString(),
          'https://api.github.com/repos/andrewkomkov/plane-mobile/releases/latest');
    });
  });

  group('platform', () {
    test('no update is offered off Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      wire(release(tag: 'v9.9.9', assets: [asset('app.apk')]));

      // There is no sideload path on iOS, so offering one would be a dead end.
      expect(await UpdateService.check(), isNull);
    });
  });

  group('install', () {
    test('a release with no build cannot be installed', () async {
      const update =
          AppUpdate(version: '1.2.0', pageUrl: 'https://example.org');
      expect(await UpdateService.install(update), isNotNull);
    });
  });
}
