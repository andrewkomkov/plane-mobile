import '../config/api_client.dart';
import '../models/member.dart';
import 'workspace_service.dart';

/// Project membership: who is in a project, at what role, and changing that.
///
/// Every route here is the internal API's, reached through the proxy in
/// [ApiClient] — see `lib/config/api_client.dart`. They are the ones Plane's
/// own web client uses, and they are declared in
/// `plane/app/urls/project.py`.
class MemberService {
  static String _base(String workspaceSlug, String projectId) =>
      '/workspaces/$workspaceSlug/projects/$projectId/members/';

  /// Everyone in the project, named, with their project and workspace roles.
  ///
  /// This is two calls because no single endpoint has both halves.
  /// `projects/{id}/members/` returns memberships whose `member` is a bare
  /// user id and nothing else — `ProjectMemberRoleSerializer` declares no
  /// nested serializer for it, and the `fields=(...)` the view passes is
  /// silently discarded by `DynamicBaseSerializer.__init__`. The names come
  /// from `workspaces/{slug}/members/`, which does expand the user. Plane's
  /// web client performs exactly this join — see `getProjectMemberDetails` in
  /// `apps/web/core/store/member/project/base-project-member.store.ts`.
  ///
  /// The workspace half also supplies each person's workspace role, which the
  /// project permission rules need and which is not on the project payload.
  static Future<List<Membership>> getProjectMemberships(
    String workspaceSlug,
    String projectId,
  ) async {
    final dio = await ApiClient.getInstance();
    // Both in flight at once — the second is only needed to decorate the
    // first, and waiting for it in series would double the screen's latency.
    final membershipsRequest = dio.get(_base(workspaceSlug, projectId));
    // A failure on the workspace half costs names, not the list, so it must
    // not take the whole call down with it. Any active workspace member may
    // read that route, so in practice it only fails when the network does.
    final workspaceRequest = WorkspaceService.getWorkspaceMemberships(
      workspaceSlug,
    ).catchError((_) => <Membership>[]);

    final data = (await membershipsRequest).data;
    final workspace = {
      for (final m in await workspaceRequest) m.member.id: m,
    };

    final list = data is Map ? (data['results'] ?? const []) : data;
    if (list is! List) return [];

    return list
        .whereType<Map>()
        .map((e) => Membership.fromJson(Map<String, dynamic>.from(e)))
        .map((m) {
      final ws = workspace[m.member.id];
      return m.resolved(details: ws?.member, workspaceRole: ws?.role);
    }).toList();
  }

  /// The project's members as plain people, for assignee pickers and avatars.
  ///
  /// Kept because most callers only want somebody to put a name and a face to
  /// an id. It used to build these straight from the project payload, which
  /// gave every [Member] the *membership* row's id and an empty name — so an
  /// assignee lookup by user id never matched. Going through
  /// [getProjectMemberships] is what fixes that.
  static Future<List<Member>> getMembers(
    String workspaceSlug,
    String projectId,
  ) async =>
      (await getProjectMemberships(workspaceSlug, projectId))
          .map((m) => m.member)
          .toList();

  /// The caller's own membership, which is where their project role comes from.
  ///
  /// Returns null when they are not an active member. `ProjectMemberUserEndpoint`
  /// fetches with an unguarded `.get()`, so a non-member gets a server error
  /// rather than a 404; either way there is no role to report.
  static Future<Membership?> getMyMembership(
    String workspaceSlug,
    String projectId,
  ) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get(
        '/workspaces/$workspaceSlug/projects/$projectId/project-members/me/',
      );
      final data = response.data;
      if (data is! Map) return null;
      return Membership.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  /// Add workspace members to the project.
  ///
  /// This is the project's real "invite" path. The `invitations/` route exists
  /// but cannot be called: `ProjectInvitationsViewset.create` reads `.role` off
  /// a queryset instead of an object, so it raises before it does anything.
  /// Plane's web client does not use it either — its "add members" modal picks
  /// from the workspace and POSTs here.
  ///
  /// [members] maps a user id to the project role they should get. The server
  /// rejects the whole batch if any role disagrees with that person's
  /// workspace role; [MemberPermissions.addableProjectRoles] is the client-side
  /// copy of that rule.
  static Future<void> addMembers(
    String workspaceSlug,
    String projectId,
    Map<String, int> members,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.post(_base(workspaceSlug, projectId), data: {
      'members': [
        for (final entry in members.entries)
          {'member_id': entry.key, 'role': entry.value},
      ],
    });
  }

  /// Change a member's project role. [membershipId] is [Membership.id], not
  /// the user id.
  static Future<void> updateRole(
    String workspaceSlug,
    String projectId,
    String membershipId,
    int role,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.patch(
      '${_base(workspaceSlug, projectId)}$membershipId/',
      data: {'role': role},
    );
  }

  /// Remove somebody from the project. Deactivates the membership rather than
  /// deleting it, so re-adding them later restores their history.
  static Future<void> removeMember(
    String workspaceSlug,
    String projectId,
    String membershipId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete('${_base(workspaceSlug, projectId)}$membershipId/');
  }

  /// Leave the project. Refused by the server if the caller is its only admin.
  static Future<void> leave(String workspaceSlug, String projectId) async {
    final dio = await ApiClient.getInstance();
    await dio.post('${_base(workspaceSlug, projectId)}leave/');
  }
}
