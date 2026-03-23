import '../config/api_client.dart';
import '../models/member.dart';

class MemberService {
  static Future<List<Member>> getMembers(String workspaceSlug, String projectId) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/workspaces/$workspaceSlug/projects/$projectId/members/');
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => Member.fromJson(e)).toList();
  }
}
