import 'package:dio/dio.dart';
import '../config/api_client.dart';
import '../config/secure_storage.dart';

class SearchService {
  static Future<Map<String, List<Map<String, dynamic>>>> searchAll(
      String workspaceSlug, String query) async {
    // Try proxy search first (fast, single SQL)
    try {
      final baseUrl = await SecureStorage.getBaseUrl() ?? '';
      final apiKey = await SecureStorage.getApiKey() ?? '';
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {'X-Api-Key': apiKey},
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final response = await dio.get(
        '/auth/mobile/$workspaceSlug/search/',
        queryParameters: {'q': query},
      );
      final data = response.data;
      if (data is Map) {
        final results = <String, List<Map<String, dynamic>>>{};
        for (final key in ['issues', 'projects', 'pages']) {
          final list = data[key];
          if (list is List && list.isNotEmpty) {
            results[key] = list.map((e) => e as Map<String, dynamic>).toList();
          }
        }
        if (results.isNotEmpty) return results;
      }
    } catch (_) {}

    // Fallback: Plane's built-in search API
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get(
        '/workspaces/$workspaceSlug/search/',
        queryParameters: {
          'search': query,
          'type': 'issue,project,page,cycle,module',
        },
      );
      final data = response.data;
      final results = <String, List<Map<String, dynamic>>>{};
      if (data is Map) {
        for (final key in ['issues', 'projects', 'pages', 'cycles', 'modules']) {
          final list = data[key];
          if (list is List && list.isNotEmpty) {
            results[key] = list.map((e) => e as Map<String, dynamic>).toList();
          }
        }
      }
      return results;
    } catch (_) {}

    return {};
  }
}
