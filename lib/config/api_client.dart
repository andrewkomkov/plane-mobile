import 'package:dio/dio.dart';
import 'secure_storage.dart';

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

    // Prefer API key if available, fall back to session cookie
    if (apiKey.isNotEmpty) {
      headers['X-Api-Key'] = apiKey;
    } else if (sessionId.isNotEmpty) {
      headers['Cookie'] = 'sessionid=$sessionId';
    }

    _dio = Dio(BaseOptions(
      baseUrl: apiKey.isNotEmpty ? '$baseUrl/api/v1' : '$baseUrl/api',
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

  /// Internal API instance (/api/ instead of /api/v1/) — for notifications, views, etc.
  static Dio? _dioInternal;

  static Future<Dio> getInternalInstance() async {
    if (_dioInternal != null) return _dioInternal!;
    final baseUrl = await SecureStorage.getBaseUrl() ?? '';
    final apiKey = await SecureStorage.getApiKey() ?? '';
    _dioInternal = Dio(BaseOptions(
      baseUrl: '$baseUrl/api',
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
