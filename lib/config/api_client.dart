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

    _dio = Dio(BaseOptions(
      baseUrl: '$baseUrl/api/v1',
      headers: {
        'X-Api-Key': apiKey,
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio!.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (o) => print('[API] $o'),
    ));

    return _dio!;
  }

  static void reset() {
    _dio?.close();
    _dio = null;
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
}
