import '../config/api_client.dart';
import '../models/label.dart';

class LabelService {
  static Future<List<Label>> getLabels(String workspaceSlug, String projectId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/workspaces/$workspaceSlug/projects/$projectId/issue-labels/');
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => Label.fromJson(e)).toList();
  }

  static Future<Label> createLabel(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/issue-labels/',
      data: data,
    );
    return Label.fromJson(response.data);
  }

  static Future<Label> updateLabel(
    String workspaceSlug,
    String projectId,
    String labelId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.patch(
      '/workspaces/$workspaceSlug/projects/$projectId/issue-labels/$labelId/',
      data: data,
    );
    return Label.fromJson(response.data);
  }

  static Future<void> deleteLabel(
    String workspaceSlug,
    String projectId,
    String labelId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/issue-labels/$labelId/',
    );
  }
}
