import 'package:dio/dio.dart';
import 'secure_storage.dart';

/// Where the app's API token can actually reach Plane's full API.
///
/// Plane has two APIs. The internal one (`/api/...`) carries the whole feature
/// set — saved views, reactions, subscribers, relations, analytics, and
/// assignees and labels on a work item — but authenticates by session cookie
/// only and 401s an API token. The external one (`/api/v1/...`) accepts the
/// token but is a much smaller surface: it has no views, no reactions, no
/// relations and no analytics, and marks assignees and labels write-only so
/// they never come back at all.
///
/// The app holds a token, so it was pinned to the smaller API while calling
/// the larger one's route names. Opening a work item and the Views screen both
/// failed on a real device for that reason.
///
/// plane-mobile-api now exchanges the token for a real Plane session and
/// proxies through to the internal API, so Plane's own permission classes run
/// on every request. Route names in the services are the internal ones, which
/// is what they were written against in the first place.
const String kPlaneProxyBase = '/auth/mobile/_plane/api';

class ApiClient {
  static Dio? _dio;

  static Future<Dio> getInstance() async {
    if (_dio != null) return _dio!;
    return await _create();
  }

  static Future<Dio> _create() async {
    final baseUrl = await SecureStorage.getBaseUrl() ?? '';
    final apiKey = await SecureStorage.getApiKey() ?? '';
    final sessionId = await SecureStorage.getSessionId() ?? '';

    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
    };

    // Prefer API key if available, fall back to session cookie.
    //
    // The cookie branch is kept for a caller that supplies its own session,
    // but nothing produces one: both sign-in paths end in
    // setup_screen._handleAuthSuccess, which stores an api_token. Note the
    // name below is wrong for this server anyway — Plane sets
    // SESSION_COOKIE_NAME to "session-id", not Django's default.
    if (apiKey.isNotEmpty) {
      headers['X-Api-Key'] = apiKey;
    } else if (sessionId.isNotEmpty) {
      headers['Cookie'] = 'sessionid=$sessionId';
    }

    _dio = Dio(BaseOptions(
      baseUrl: apiKey.isNotEmpty ? '$baseUrl$kPlaneProxyBase' : '$baseUrl/api',
      headers: headers,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio!.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode == 429) {
          final retryAfter = int.tryParse(
                  error.response?.headers.value('retry-after') ?? '') ??
              2;
          await Future.delayed(Duration(seconds: retryAfter));
          try {
            final response = await _dio!.fetch(error.requestOptions);
            return handler.resolve(response);
          } catch (_) {}
        }
        return handler.next(error);
      },
    ));

    return _dio!;
  }

  /// Internal API instance.
  ///
  /// This used to send `X-Api-Key` straight at `/api`, which Plane rejects —
  /// those views authenticate with BaseSessionAuthentication and never read
  /// that header, so every call through here was a 401. It now goes through
  /// the same proxy as [getInstance], which is what makes the header work.
  static Dio? _dioInternal;

  static Future<Dio> getInternalInstance() async {
    if (_dioInternal != null) return _dioInternal!;
    final baseUrl = await SecureStorage.getBaseUrl() ?? '';
    final apiKey = await SecureStorage.getApiKey() ?? '';
    _dioInternal = Dio(BaseOptions(
      baseUrl: '$baseUrl$kPlaneProxyBase',
      headers: {
        'X-Api-Key': apiKey,
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    return _dioInternal!;
  }

  static void reset() {
    _dio?.close();
    _dio = null;
    _dioInternal?.close();
    _dioInternal = null;
  }

  static Future<Dio> createTemporary(String baseUrl, String apiKey) async {
    return Dio(BaseOptions(
      baseUrl: '$baseUrl/api/v1',
      headers: {
        'X-Api-Key': apiKey,
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  /// Create a Dio instance using a session cookie for internal API calls.
  static Dio createWithSession(String baseUrl, String sessionId) {
    return Dio(BaseOptions(
      baseUrl: '$baseUrl/api',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': 'sessionid=$sessionId',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }
}
