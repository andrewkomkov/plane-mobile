import '../config/api_client.dart';
import '../models/issue.dart';

class SearchService {
  static Future<List<Issue>> searchIssues(
      String workspaceSlug, String query) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/work-items/search/',
      queryParameters: {'search': query},
    );
    final data = response.data;
    // Search returns {"issues": [...]} with minimal fields
    final list = data is Map ? (data['issues'] ?? data['results'] ?? []) : data;
    return (list as List).map((e) => Issue.fromJson(e)).toList();
  }
}
