import '../config/api_client.dart';
import '../models/cycle.dart';
import '../models/issue.dart';

class CycleService {
  static Future<List<Cycle>> getCycles(String workspaceSlug, String projectId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/workspaces/$workspaceSlug/projects/$projectId/cycles/');
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => Cycle.fromJson(e)).toList();
  }

  static Future<List<Issue>> getCycleIssues(
      String workspaceSlug, String projectId, String cycleId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
        '/workspaces/$workspaceSlug/projects/$projectId/cycles/$cycleId/cycle-issues/');
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => Issue.fromJson(e)).toList();
  }
}
