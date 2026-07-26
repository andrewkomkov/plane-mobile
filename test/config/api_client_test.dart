import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/config/api_client.dart';
import 'package:plane_mobile/config/secure_storage.dart';

/// These pin the one thing the app is allowed to send.
///
/// The client used to have a second, session-cookie transport: when no token
/// was stored it aimed at `{base}/api` with a `Cookie: sessionid=...` header.
/// It could not work — Plane's SESSION_COOKIE_NAME is "session-id", so the
/// server never read the header — and nothing ever wrote a session id anyway,
/// so the branch was permanently unreachable. Both are gone. A regression that
/// reintroduces either one is worth catching here rather than as a wall of
/// 401s on a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ApiClient.reset();
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(ApiClient.reset);

  group('ApiClient.getInstance', () {
    test('always goes through the proxy and authenticates with the token',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        'plane_base_url': 'https://plane.example.com',
        'plane_api_key': 'plane_api_abc123',
      });

      final dio = await ApiClient.getInstance();

      expect(dio.options.baseUrl, 'https://plane.example.com$kPlaneProxyBase');
      expect(dio.options.headers['X-Api-Key'], 'plane_api_abc123');
      // The proxy holds the Plane session; the app must never send one.
      expect(dio.options.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('cookie')));
    });

    test('does not fall back to a bare /api base when no token is stored',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        'plane_base_url': 'https://plane.example.com',
      });

      final dio = await ApiClient.getInstance();

      // The old code sent this at `{base}/api`, which only session cookies can
      // authenticate. Better to keep aiming at the proxy and fail as an
      // ordinary 401 than to look like a working second transport.
      expect(dio.options.baseUrl, 'https://plane.example.com$kPlaneProxyBase');
      expect(dio.options.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('cookie')));
    });
  });

  group('ApiClient.createTemporary', () {
    test('targets the external v1 API, the only surface a bare token can use',
        () async {
      final dio = await ApiClient.createTemporary(
          'https://plane.example.com', 'plane_api_abc123');

      // Deliberate: setup validates a token before anything is stored, so the
      // proxy has nothing to exchange for a session yet.
      expect(dio.options.baseUrl, 'https://plane.example.com/api/v1');
      expect(dio.options.headers['X-Api-Key'], 'plane_api_abc123');
    });
  });

  group('SecureStorage.isConfigured', () {
    test('needs a base URL and a token', () async {
      FlutterSecureStorage.setMockInitialValues({
        'plane_base_url': 'https://plane.example.com',
        'plane_api_key': 'plane_api_abc123',
      });

      expect(await SecureStorage.isConfigured(), isTrue);
    });

    test('a base URL on its own is not enough', () async {
      FlutterSecureStorage.setMockInitialValues({
        'plane_base_url': 'https://plane.example.com',
      });

      expect(await SecureStorage.isConfigured(), isFalse);
    });

    test('a leftover session id does not count as configured', () async {
      // Old installs may still carry `plane_session_id`. It used to satisfy
      // this check and let the app past the setup screen holding a credential
      // no request could ever use.
      FlutterSecureStorage.setMockInitialValues({
        'plane_base_url': 'https://plane.example.com',
        'plane_session_id': 'deadbeef',
      });

      expect(await SecureStorage.isConfigured(), isFalse);
    });
  });
}
