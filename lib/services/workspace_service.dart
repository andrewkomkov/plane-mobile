import 'package:dio/dio.dart';
import '../config/api_client.dart';
import '../config/secure_storage.dart';
import '../models/workspace.dart';
import '../models/member.dart';

class WorkspaceService {
  static Future<List<Workspace>> getWorkspaces() async {
    // Use proxy endpoint
    try {
      final baseUrl = await SecureStorage.getBaseUrl() ?? '';
      final apiKey = await SecureStorage.getApiKey() ?? '';
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {'X-Api-Key': apiKey},
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final response = await dio.get('/auth/mobile/workspaces/');
      if (response.data is List) {
        return (response.data as List).map((e) => Workspace.fromJson(e)).toList();
      }
    } catch (_) {}

    // Fallback: return current workspace
    final slug = await SecureStorage.getWorkspaceSlug() ?? '';
    if (slug.isNotEmpty) {
      return [Workspace(id: '', name: slug, slug: slug, totalMembers: 0, totalProjects: 0, createdAt: DateTime.now())];
    }
    return [];
  }

  static Future<List<Member>> getWorkspaceMembers(String slug) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/workspaces/$slug/members/');
    final data = response.data;
    final list = data is Map ? (data['results'] ?? data) : data;
    if (list is List) {
      return list.map((e) {
        // Workspace members may have member details nested
        final memberData = e is Map && e.containsKey('member')
            ? e['member'] as Map<String, dynamic>
            : e as Map<String, dynamic>;
        return Member.fromJson(memberData);
      }).toList();
    }
    return [];
  }

  static Future<Workspace> updateWorkspace(
    String slug,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.patch(
      '/workspaces/$slug/',
      data: data,
    );
    return Workspace.fromJson(response.data);
  }
}
