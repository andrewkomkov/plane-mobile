import '../config/api_client.dart';
import '../models/project.dart';

class ProjectService {
  static Future<List<Project>> getProjects(String workspaceSlug) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/workspaces/$workspaceSlug/projects/');
    final data = response.data;

    if (data is Map && data.containsKey('results')) {
      return (data['results'] as List)
          .map((e) => Project.fromJson(e))
          .toList();
    }
    if (data is List) {
      return data.map((e) => Project.fromJson(e)).toList();
    }
    return [];
  }
}
