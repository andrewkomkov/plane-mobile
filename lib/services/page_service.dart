import 'package:dio/dio.dart';
import '../config/api_client.dart';
import '../config/secure_storage.dart';
import '../models/page.dart';

class PageService {
  static Future<Dio> _getProxyDio() async {
    final baseUrl = await SecureStorage.getBaseUrl() ?? '';
    final apiKey = await SecureStorage.getApiKey() ?? '';
    return Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {'X-Api-Key': apiKey, 'Content-Type': 'application/json'},
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
  }

  static Future<List<PlanePage>> getPages(
    String workspaceSlug,
    String projectId,
  ) async {
    // Try microservice first (survives Plane updates)
    try {
      final dio = await _getProxyDio();
      final response = await dio.get(
        '/auth/mobile/$workspaceSlug/projects/$projectId/pages/',
      );
      final data = response.data;
      if (data is Map && data.containsKey('results')) {
        return (data['results'] as List).map((e) => PlanePage.fromJson(e)).toList();
      }
      if (data is List) {
        return data.map((e) => PlanePage.fromJson(e)).toList();
      }
    } catch (_) {}

    // Fallback to Plane API v1 (works if our Django patch is present)
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get(
        '/workspaces/$workspaceSlug/projects/$projectId/pages/',
      );
      final data = response.data;
      if (data is Map && data.containsKey('results')) {
        return (data['results'] as List).map((e) => PlanePage.fromJson(e)).toList();
      }
      if (data is List) {
        return data.map((e) => PlanePage.fromJson(e)).toList();
      }
    } catch (_) {}

    return [];
  }

  static Future<PlanePage> getPage(
    String workspaceSlug,
    String projectId,
    String pageId,
  ) async {
    try {
      final dio = await _getProxyDio();
      final response = await dio.get(
        '/auth/mobile/$workspaceSlug/projects/$projectId/pages/$pageId',
      );
      return PlanePage.fromJson(response.data);
    } catch (_) {}

    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/pages/$pageId/',
    );
    return PlanePage.fromJson(response.data);
  }

  static Future<PlanePage> createPage(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    try {
      final dio = await _getProxyDio();
      final response = await dio.post(
        '/auth/mobile/$workspaceSlug/projects/$projectId/pages/',
        data: data,
      );
      return PlanePage.fromJson(response.data);
    } catch (_) {}

    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/pages/',
      data: data,
    );
    return PlanePage.fromJson(response.data);
  }

  static Future<PlanePage> updatePage(
    String workspaceSlug,
    String projectId,
    String pageId,
    Map<String, dynamic> data,
  ) async {
    try {
      final dio = await _getProxyDio();
      await dio.patch(
        '/auth/mobile/$workspaceSlug/projects/$projectId/pages/$pageId',
        data: data,
      );
    } catch (_) {
      final dio = await ApiClient.getInstance();
      await dio.patch(
        '/workspaces/$workspaceSlug/projects/$projectId/pages/$pageId/',
        data: data,
      );
    }
    return getPage(workspaceSlug, projectId, pageId);
  }
}
