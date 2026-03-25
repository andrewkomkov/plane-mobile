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

  static Future<Project> getProject(String workspaceSlug, String projectId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/workspaces/$workspaceSlug/projects/$projectId/');
    return Project.fromJson(response.data);
  }

  static Future<Project> updateProject(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.patch(
      '/workspaces/$workspaceSlug/projects/$projectId/',
      data: data,
    );
    return Project.fromJson(response.data);
  }

  static Future<List<Map<String, dynamic>>> getProjectMembers(
    String workspaceSlug,
    String projectId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/members/',
    );
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => e as Map<String, dynamic>).toList();
  }
}
