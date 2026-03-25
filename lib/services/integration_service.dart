import '../config/api_client.dart';

class IntegrationService {
  static Future<List<Map<String, dynamic>>> getGitHubRepositories(
    String workspaceSlug,
    String projectId,
  ) async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.get(
        '/workspaces/$workspaceSlug/projects/$projectId/github-repositories/',
      );
      final data = response.data;
      final list = data is Map ? (data['results'] ?? data) : data;
      if (list is List) {
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {
      // Integration endpoint may not exist on all instances
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getGitHubIssueLinks(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    try {
      final response = await dio.get(
        '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/issue-links/',
      );
      final data = response.data;
      final list = data is Map ? (data['results'] ?? data) : data;
      if (list is List) {
        return list
            .where((e) {
              final url = (e['url'] ?? '').toString().toLowerCase();
              return url.contains('github.com');
            })
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
