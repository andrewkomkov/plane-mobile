import 'member.dart';

/// What the signed-in user may do to a project's or a workspace's members.
///
/// Everything here is a mirror of a rule that already exists on the server, and
/// every method names where it was read from. Two sources matter, and they do
/// not say the same thing:
///
/// * **The endpoints** — `plane/app/views/project/member.py`,
///   `plane/app/views/workspace/member.py`, `.../workspace/invite.py`, and the
///   permission classes in `plane/app/permissions/`. These decide what will
///   actually be accepted. Offering anything they reject puts a 403 or a 400 in
///   front of the user, which is the thing this file exists to prevent.
/// * **Plane's own web client** — `apps/web/core/components/project/settings/
///   member-columns.tsx` and `apps/web/core/components/workspace/settings/
///   member-columns.tsx`. Where the endpoint is laxer than the web UI, this
///   follows the web UI.
///
/// That second point is deliberate and worth stating plainly, because it is the
/// one place this file is not a faithful mirror. `ProjectMemberViewSet.
/// partial_update` is decorated `@allow_permission([ADMIN, MEMBER, GUEST])` and
/// then only checks that the requested role is not *above* the caller's own —
/// so the endpoint will let a project guest demote a project admin to guest.
/// Plane's web client does not offer that, and neither does this. Being
/// stricter than the server costs a control that would have worked; being laxer
/// would put a privilege hole on the phone.
///
/// A null role means "not a member of that thing", not "role unknown yet" —
/// callers must not construct this until both lookups have landed, because
/// every rule here fails closed.
class MemberPermissions {
  /// The signed-in user's id. Null until the identity call returns, which
  /// disables every rule that has to tell self from other.
  final String? currentUserId;

  /// The caller's role in the project under inspection, or null if they are
  /// not an active member of it.
  final int? projectRole;

  /// The caller's role in the enclosing workspace, or null if they are not an
  /// active member of it.
  final int? workspaceRole;

  const MemberPermissions({
    this.currentUserId,
    this.projectRole,
    this.workspaceRole,
  });

  bool get isWorkspaceAdmin => workspaceRole == MemberRole.admin;
  bool get isWorkspaceMemberOrAbove =>
      workspaceRole == MemberRole.admin || workspaceRole == MemberRole.member;
  bool get isProjectAdmin => projectRole == MemberRole.admin;

  bool isSelf(Membership target) =>
      currentUserId != null && currentUserId == target.member.id;

  /// The `@allow_permission(level="PROJECT")` decorator, as a predicate.
  ///
  /// From `plane/app/permissions/base.py`: the caller passes if their project
  /// role is in [allowed], **or** if they are an active member of the project
  /// at any role while also being a workspace admin. That second arm is easy
  /// to miss and it is why a workspace admin can administer a project they
  /// joined as a guest.
  bool _projectGate(Set<int> allowed) {
    final role = projectRole;
    if (role == null) return false;
    return allowed.contains(role) || isWorkspaceAdmin;
  }

  // ---------------------------------------------------------------------------
  //  Project
  // ---------------------------------------------------------------------------

  /// Whether to offer "add member" at all.
  ///
  /// `ProjectMemberViewSet.create` is `@allow_permission([ROLE.ADMIN])`.
  bool get canAddProjectMembers => _projectGate({MemberRole.admin});

  /// Roles that may be given to [workspaceRole] when adding them to a project.
  ///
  /// `create` refuses outright if a workspace admin is added at any role below
  /// admin, or a workspace guest at any role above guest — those two are
  /// pinned to their workspace role and the third is free. Plane's web client
  /// filters the same way in `send-project-invitation-modal.tsx`.
  static List<int> addableProjectRoles(int? workspaceRole) {
    switch (workspaceRole) {
      case MemberRole.admin:
        return const [MemberRole.admin];
      case MemberRole.guest:
        return const [MemberRole.guest];
      case MemberRole.member:
        return MemberRole.all;
      default:
        // Not a workspace member, so they cannot be a project member either.
        return const [];
    }
  }

  /// Whether to offer a role picker on [target]'s row.
  ///
  /// Mirrors `member-columns.tsx`:
  ///
  ///   * a workspace admin may change their own project role — and only the
  ///     server's `is_workspace_admin` escape hatch in `partial_update` makes
  ///     that legal, since the plain rule is "you cannot update your own role";
  ///   * a project admin may change anyone else's, except a workspace admin's.
  ///
  /// Nobody else gets the control, even though the endpoint would let them.
  bool canChangeProjectRole(Membership target) {
    if (currentUserId == null) return false;
    final targetIsWorkspaceAdmin = target.workspaceRole == MemberRole.admin;
    if (isSelf(target)) return isWorkspaceAdmin;
    return isProjectAdmin && !targetIsWorkspaceAdmin;
  }

  /// Roles that may be assigned to [target], given the caller may act at all.
  ///
  /// A workspace guest is pinned to project guest — `partial_update` rejects
  /// promoting one, and `member-columns.tsx` filters the dropdown the same
  /// way. Everything else is capped at the caller's own project role, which is
  /// what `"role" > requested_project_member.role` enforces; for a project
  /// admin that cap is the whole list.
  List<int> assignableProjectRoles(Membership target) {
    if (!canChangeProjectRole(target)) return const [];
    if (target.workspaceRole == MemberRole.guest) {
      return const [MemberRole.guest];
    }
    // Self-edit only reaches here for a workspace admin, whom `partial_update`
    // exempts from the cap entirely.
    if (isSelf(target)) return MemberRole.all;
    final cap = projectRole ?? 0;
    return MemberRole.all.where((r) => r <= cap).toList();
  }

  /// Whether to offer "remove from project" on [target]'s row.
  ///
  /// `destroy` is `@allow_permission([ROLE.ADMIN])` and then refuses two more
  /// things: removing yourself (there is a separate leave route for that), and
  /// removing anyone whose project role is above your own. The second only
  /// bites on the workspace-admin arm of the gate, where the caller's project
  /// role can be below the target's.
  bool canRemoveProjectMember(Membership target) {
    if (currentUserId == null) return false;
    if (isSelf(target)) return false;
    if (!_projectGate({MemberRole.admin})) return false;
    return (projectRole ?? 0) >= target.role;
  }

  /// Whether "leave project" should be offered, given the full member list.
  ///
  /// `leave` admits any active project member, then refuses if the caller is
  /// the project's only admin. That count is knowable from the list already on
  /// screen, so the refusal can be a disabled control with a reason rather than
  /// a 400 after the fact.
  bool canLeaveProject(List<Membership> members) {
    if (projectRole == null) return false;
    if (projectRole != MemberRole.admin) return true;
    return members.where((m) => m.role == MemberRole.admin).length > 1;
  }

  // ---------------------------------------------------------------------------
  //  Workspace
  // ---------------------------------------------------------------------------

  /// Whether to offer a role picker on a workspace member's row.
  ///
  /// `WorkSpaceMemberViewSet.partial_update` is
  /// `@allow_permission([ADMIN], level="WORKSPACE")` and then refuses to let
  /// the caller edit their own role — with no workspace-admin escape this
  /// time, unlike the project endpoint. `member-columns.tsx` agrees:
  /// `isRoleNonEditable = isCurrentUser || !isAdminRole`.
  bool canChangeWorkspaceRole(Membership target) {
    if (currentUserId == null) return false;
    return isWorkspaceAdmin && !isSelf(target);
  }

  /// Every role, once the caller is allowed to act.
  ///
  /// Only a workspace admin gets here and the endpoint applies no further
  /// ceiling, so there is nothing left to filter. Demoting someone to guest
  /// also drops them to guest in every project — the server does that in the
  /// same handler, and the confirmation copy says so.
  List<int> assignableWorkspaceRoles(Membership target) =>
      canChangeWorkspaceRole(target) ? MemberRole.all : const [];

  /// Whether to offer "remove from workspace" on [target]'s row.
  ///
  /// `destroy` is admin-only and refuses self-removal. Its other two refusals
  /// — target senior to caller, and target being the sole admin of some
  /// project — cannot bite or cannot be known here: the caller is an admin so
  /// nobody outranks them, and project admin counts are not on this screen.
  /// The second surfaces as a server error message.
  bool canRemoveWorkspaceMember(Membership target) {
    if (currentUserId == null) return false;
    return isWorkspaceAdmin && !isSelf(target);
  }

  /// Whether "leave workspace" should be offered.
  ///
  /// `leave` refuses the workspace's only admin. It also refuses anyone who is
  /// the only admin of some project, which this cannot see; that one comes back
  /// as a server error.
  bool canLeaveWorkspace(List<Membership> members) {
    if (workspaceRole == null) return false;
    if (workspaceRole != MemberRole.admin) return true;
    return members.where((m) => m.role == MemberRole.admin).length > 1;
  }

  /// Whether to offer "invite by email".
  ///
  /// `WorkspaceInvitationsViewset` carries `WorkSpaceAdminPermission`, which
  /// despite the name admits Admin *and* Member — see
  /// `plane/app/permissions/workspace.py`. The class guards every action on the
  /// viewset, listing included, so a guest cannot even see pending invitations.
  bool get canInviteToWorkspace => isWorkspaceMemberOrAbove;

  /// Whether pending invitations can be listed and revoked.
  bool get canManageWorkspaceInvitations => isWorkspaceMemberOrAbove;

  /// Roles the caller may invite at.
  ///
  /// `create` refuses any invite whose role is above the caller's own, so a
  /// workspace member may invite members and guests but not admins.
  List<int> invitableWorkspaceRoles() {
    final cap = workspaceRole;
    if (cap == null || !canInviteToWorkspace) return const [];
    return MemberRole.all.where((r) => r <= cap).toList();
  }
}
