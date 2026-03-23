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

  static Future<List<Issue>> getModuleIssues(
      String workspaceSlug, String projectId, String moduleId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
        '/workspaces/$workspaceSlug/projects/$projectId/modules/$moduleId/module-issues/');
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => Issue.fromJson(e)).toList();
  }
}
