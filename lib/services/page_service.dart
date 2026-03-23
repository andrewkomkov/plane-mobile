import '../config/api_client.dart';
import '../models/page.dart';

class PageService {
  static Future<List<PlanePage>> getPages(
    String workspaceSlug,
    String projectId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/pages/',
    );
    final data = response.data;

    if (data is Map && data.containsKey('results')) {
      return (data['results'] as List)
          .map((e) => PlanePage.fromJson(e))
          .toList();
    }
    if (data is List) {
      return data.map((e) => PlanePage.fromJson(e)).toList();
    }
    return [];
  }

  static Future<PlanePage> getPage(
    String workspaceSlug,
    String projectId,
    String pageId,
  ) async {
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
    final dio = await ApiClient.getInstance();
    final response = await dio.patch(
      '/workspaces/$workspaceSlug/projects/$projectId/pages/$pageId/',
      data: data,
    );
    return PlanePage.fromJson(response.data);
  }
}
