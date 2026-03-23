import '../config/api_client.dart';
import '../models/label.dart';

class LabelService {
  static Future<List<Label>> getLabels(String workspaceSlug, String projectId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/workspaces/$workspaceSlug/projects/$projectId/labels/');
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => Label.fromJson(e)).toList();
  }
}
