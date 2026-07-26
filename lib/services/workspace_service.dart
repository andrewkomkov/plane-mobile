import 'package:dio/dio.dart';
import '../config/api_client.dart';
import '../config/secure_storage.dart';
import '../models/workspace.dart';
import '../models/member.dart';

/// Workspace membership: who is in the workspace, at what role, who has been
/// invited, and changing all of that.
///
/// Routes are the internal API's, declared in `plane/app/urls/workspace.py`
/// and reached through the proxy in [ApiClient].
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
        return (response.data as List)
            .map((e) => Workspace.fromJson(e))
            .toList();
      }
    } catch (_) {}

    // Fallback: return current workspace
    final slug = await SecureStorage.getWorkspaceSlug() ?? '';
    if (slug.isNotEmpty) {
      return [
        Workspace(
            id: '',
            name: slug,
            slug: slug,
            totalMembers: 0,
            totalProjects: 0,
            createdAt: DateTime.now())
      ];
    }
    return [];
  }

  static String _membersBase(String slug) => '/workspaces/$slug/members/';
  static String _invitationsBase(String slug) =>
      '/workspaces/$slug/invitations/';

  /// Everyone in the workspace, with their role.
  ///
  /// Unlike the project list, this one expands the user: both
  /// `WorkSpaceMemberSerializer` and `WorkspaceMemberAdminSerializer` declare a
  /// nested `member`. Which of the two is used depends on the *caller* — a
  /// guest gets `UserLiteSerializer`, which has no `email`, so a guest reading
  /// this list sees names but no addresses. That is the server's choice and
  /// the UI just renders whatever arrived.
  static Future<List<Membership>> getWorkspaceMemberships(String slug) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(_membersBase(slug));
    final data = response.data;
    final list = data is Map ? (data['results'] ?? data) : data;
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Membership.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// The workspace's members as plain people.
  static Future<List<Member>> getWorkspaceMembers(String slug) async =>
      (await getWorkspaceMemberships(slug)).map((m) => m.member).toList();

  /// The caller's own workspace membership, which is where their workspace
  /// role — and their user id — come from.
  ///
  /// `WorkspaceMemberUserEndpoint` serializes with `fields = "__all__"` and no
  /// nested member, so `member` arrives as a bare user id; [Member.fromJson]
  /// reads it as the id and leaves the name blank, which is all this is for.
  static Future<Membership?> getMyMembership(String slug) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get('/workspaces/$slug/workspace-members/me/');
      final data = response.data;
      if (data is! Map) return null;
      return Membership.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  /// Change a member's workspace role. [membershipId] is [Membership.id].
  ///
  /// Demoting somebody to guest also demotes them to guest in every project in
  /// the workspace — the server does that in the same handler.
  static Future<void> updateMemberRole(
    String slug,
    String membershipId,
    int role,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio
        .patch('${_membersBase(slug)}$membershipId/', data: {'role': role});
  }

  /// Remove somebody from the workspace, and from every project in it.
  static Future<void> removeMember(String slug, String membershipId) async {
    final dio = await ApiClient.getInstance();
    await dio.delete('${_membersBase(slug)}$membershipId/');
  }

  /// Leave the workspace. Refused if the caller is its only admin, or the only
  /// admin of any project in it.
  static Future<void> leave(String slug) async {
    final dio = await ApiClient.getInstance();
    await dio.post('${_membersBase(slug)}leave/');
  }

  /// Invitations sent but not yet answered.
  ///
  /// The whole viewset is behind `WorkSpaceAdminPermission`, which admits
  /// admins and members but not guests — listing included, so a guest calling
  /// this gets a 403 rather than an empty list.
  static Future<List<WorkspaceInvitation>> getInvitations(String slug) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(_invitationsBase(slug));
    final data = response.data;
    final list = data is Map ? (data['results'] ?? data) : data;
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => WorkspaceInvitation.fromJson(Map<String, dynamic>.from(e)))
        .where((i) => !i.accepted)
        .toList();
  }

  /// Invite people to the workspace by email.
  ///
  /// The server takes a batch and fails it whole: one address already in the
  /// workspace, one malformed address, or one role above the caller's own and
  /// nothing is sent.
  static Future<void> invite(String slug, Map<String, int> emailRoles) async {
    final dio = await ApiClient.getInstance();
    await dio.post(_invitationsBase(slug), data: {
      'emails': [
        for (final entry in emailRoles.entries)
          {'email': entry.key, 'role': entry.value},
      ],
    });
  }

  /// Change the role a pending invitation will grant.
  static Future<void> updateInvitationRole(
    String slug,
    String invitationId,
    int role,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio
        .patch('${_invitationsBase(slug)}$invitationId/', data: {'role': role});
  }

  /// Withdraw a pending invitation.
  static Future<void> revokeInvitation(String slug, String invitationId) async {
    final dio = await ApiClient.getInstance();
    await dio.delete('${_invitationsBase(slug)}$invitationId/');
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
