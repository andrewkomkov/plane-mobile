import '../config/api_client.dart';
import '../models/view.dart';

class ViewService {
  static Future<List<PlaneView>> getViews(
    String workspaceSlug,
    String projectId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/views/',
    );
    final data = response.data;
    if (data is Map && data.containsKey('results')) {
      return (data['results'] as List)
          .map((e) => PlaneView.fromJson(e))
          .toList();
    }
    if (data is List) {
      return data.map((e) => PlaneView.fromJson(e)).toList();
    }
    return [];
  }

  static Future<PlaneView> createView(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/views/',
      data: data,
    );
    return PlaneView.fromJson(response.data);
  }

  static Future<PlaneView> updateView(
    String workspaceSlug,
    String projectId,
    String viewId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.patch(
      '/workspaces/$workspaceSlug/projects/$projectId/views/$viewId/',
      data: data,
    );
    return PlaneView.fromJson(response.data);
  }

  static Future<void> deleteView(
    String workspaceSlug,
    String projectId,
    String viewId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/views/$viewId/',
    );
  }
}
