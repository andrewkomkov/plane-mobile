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

  static Future<Cycle> createCycle(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/cycles/',
      data: data,
    );
    return Cycle.fromJson(response.data);
  }

  static Future<Cycle> updateCycle(
    String workspaceSlug,
    String projectId,
    String cycleId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.patch(
      '/workspaces/$workspaceSlug/projects/$projectId/cycles/$cycleId/',
      data: data,
    );
    return Cycle.fromJson(response.data);
  }

  static Future<void> deleteCycle(
    String workspaceSlug,
    String projectId,
    String cycleId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/cycles/$cycleId/',
    );
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

  static Future<void> addIssuesToCycle(
    String workspaceSlug,
    String projectId,
    String cycleId,
    List<String> issueIds,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/cycles/$cycleId/cycle-issues/',
      data: {'issues': issueIds},
    );
  }

  static Future<void> removeIssueFromCycle(
    String workspaceSlug,
    String projectId,
    String cycleId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/cycles/$cycleId/cycle-issues/$issueId/',
    );
  }
}
