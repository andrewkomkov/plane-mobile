import '../config/api_client.dart';
import '../models/module.dart';
import '../models/issue.dart';

class ModuleService {
  static Future<List<Module>> getModules(String workspaceSlug, String projectId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/workspaces/$workspaceSlug/projects/$projectId/modules/');
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => Module.fromJson(e)).toList();
  }

  static Future<Module> createModule(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/modules/',
      data: data,
    );
    return Module.fromJson(response.data);
  }

  static Future<Module> updateModule(
    String workspaceSlug,
    String projectId,
    String moduleId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.patch(
      '/workspaces/$workspaceSlug/projects/$projectId/modules/$moduleId/',
      data: data,
    );
    return Module.fromJson(response.data);
  }

  static Future<void> deleteModule(
    String workspaceSlug,
    String projectId,
    String moduleId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/modules/$moduleId/',
    );
  }

  static Future<List<Issue>> getModuleIssues(
      String workspaceSlug, String projectId, String moduleId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
        '/workspaces/$workspaceSlug/projects/$projectId/modules/$moduleId/issues/');
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => Issue.fromJson(e)).toList();
  }

  static Future<void> addIssuesToModule(
    String workspaceSlug,
    String projectId,
    String moduleId,
    List<String> issueIds,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/modules/$moduleId/issues/',
      data: {'issues': issueIds},
    );
  }

  static Future<void> removeIssueFromModule(
    String workspaceSlug,
    String projectId,
    String moduleId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/modules/$moduleId/issues/$issueId/',
    );
  }
}
