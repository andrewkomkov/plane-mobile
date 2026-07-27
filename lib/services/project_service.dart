import '../config/api_client.dart';
import '../models/project.dart';

class ProjectService {
  static Future<List<Project>> getProjects(String workspaceSlug) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/workspaces/$workspaceSlug/projects/');
    final data = response.data;

    if (data is Map && data.containsKey('results')) {
      return (data['results'] as List).map((e) => Project.fromJson(e)).toList();
    }
    if (data is List) {
      return data.map((e) => Project.fromJson(e)).toList();
    }
    return [];
  }

  static Future<Project> getProject(
      String workspaceSlug, String projectId) async {
    final dio = await ApiClient.getInstance();
    final response =
        await dio.get('/workspaces/$workspaceSlug/projects/$projectId/');
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

  /// Put a project away.
  ///
  /// Admin or member. Archiving also deletes every favourite pointing at it —
  /// `ProjectArchiveUnarchiveEndpoint` clears `UserFavorite` for the project —
  /// so unarchiving does not bring the stars back, for anyone.
  static Future<void> archiveProject(
      String workspaceSlug, String projectId) async {
    final dio = await ApiClient.getInstance();
    await dio.post('/workspaces/$workspaceSlug/projects/$projectId/archive/');
  }

  /// Bring it back. Same path, different method.
  static Future<void> unarchiveProject(
      String workspaceSlug, String projectId) async {
    final dio = await ApiClient.getInstance();
    await dio.delete('/workspaces/$workspaceSlug/projects/$projectId/archive/');
  }

  /// Leave a project.
  ///
  /// Plane refuses when the caller is the project's only admin, with a message
  /// saying to appoint another or delete the project. That refusal is a 400
  /// with an `error` string, which is worth surfacing verbatim: it is the one
  /// case where the reason is not guessable from the screen.
  static Future<void> leaveProject(
      String workspaceSlug, String projectId) async {
    final dio = await ApiClient.getInstance();
    await dio
        .post('/workspaces/$workspaceSlug/projects/$projectId/members/leave/');
  }

  /// Join a public project in the workspace.
  ///
  /// Only reaches projects whose `network` is 2 — Plane's own listing hides
  /// the rest from a non-member, so a project this can join is one the caller
  /// can already see.
  static Future<void> joinProject(
    String workspaceSlug,
    String projectId,
    String memberId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio
        .post('/workspaces/$workspaceSlug/projects/$projectId/join/$memberId/');
  }
}
// Project members are not read here. They arrive from the same endpoint as
// bare ids and roles, and only become useful once joined against the workspace
// member list for names — see MemberService.getProjectMemberships, which owns
// that join and the write side that goes with it.
