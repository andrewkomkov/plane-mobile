import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
///
/// That session lives entirely on the proxy. The app never sees it, never
/// stores it and never sends a session cookie of its own — a token in
/// `X-Api-Key` is the whole client-side credential.
const String kPlaneProxyBase = '/auth/mobile/_plane/api';

class ApiClient {
  /// Answers every request the app makes, in place of a network.
  ///
  /// The one seam that lets a test drive the real widget tree end to end.
  /// Individual services expose their own `debugClient`, which is enough to
  /// test a service — but a test that boots the app and taps through it goes
  /// past a dozen services, and injecting each of them separately would test
  /// the injection rather than the app. Set once, honoured by every client
  /// this class hands out.
  ///
  /// Null in production, and nothing in `lib/` sets it.
  @visibleForTesting
  static HttpClientAdapter? debugAdapter;

  static Dio? _dio;

  static Future<Dio> getInstance() async {
    if (_dio != null) return _dio!;
    return await _create();
  }

  static Future<Dio> _create() async {
    final baseUrl = await SecureStorage.getBaseUrl() ?? '';
    final apiKey = await SecureStorage.getApiKey() ?? '';

    // The token is the only credential the app has. There used to be a second
    // branch here that sent a `Cookie: sessionid=...` when no token was
    // stored; it was removed because it could never have worked. Plane sets
    // SESSION_COOKIE_NAME to "session-id", so the server never read the
    // cookie, and nothing in the app ever wrote a session id in the first
    // place — both sign-in paths end in setup_screen._handleAuthSuccess,
    // which stores an api_token.
    _dio = Dio(BaseOptions(
      baseUrl: '$baseUrl$kPlaneProxyBase',
      headers: {
        'X-Api-Key': apiKey,
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    final adapter = debugAdapter;
    if (adapter != null) _dio!.httpClientAdapter = adapter;

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
    final adapter = debugAdapter;
    if (adapter != null) _dioInternal!.httpClientAdapter = adapter;
    return _dioInternal!;
  }

  static void reset() {
    _dio?.close();
    _dio = null;
    _dioInternal?.close();
    _dioInternal = null;
  }

  /// A throwaway client for validating a token the user has just typed in.
  ///
  /// This is the one place `/api/v1` is still the right target, and it is
  /// deliberate. The proxy the rest of the app talks to only answers once the
  /// app is configured — it needs a stored base URL and token to exchange for
  /// a session. At setup there is nothing stored yet and nothing to exchange,
  /// so the check has to go somewhere that authenticates a bare token on its
  /// own. That is the external API. `/users/me/` exists on both surfaces and
  /// is enough to tell a good token from a bad one.
  ///
  /// Nothing else should use this: v1 omits most of what the app reads.
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
}
