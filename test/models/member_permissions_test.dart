import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/member.dart';
import 'package:plane_mobile/models/member_permissions.dart';

/// These are the tests that matter most in this feature.
///
/// A wrong answer here is not a cosmetic bug: too permissive and the app puts a
/// control in front of somebody the server will refuse, too restrictive and an
/// admin cannot do their job. Each group names the server rule it is pinning,
/// so that a future change to `MemberPermissions` has to argue with the rule
/// rather than with the assertion.
void main() {
  Membership person(
    String userId, {
    required int role,
    int? workspaceRole,
    String? membershipId,
  }) =>
      Membership(
        id: membershipId ?? '$userId-membership',
        member: Member(
          id: userId,
          displayName: userId,
          email: '$userId@example.com',
          firstName: userId,
          lastName: '',
        ),
        role: role,
        workspaceRole: workspaceRole,
      );

  MemberPermissions caller({
    String? id = 'me',
    int? project,
    int? workspace,
  }) =>
      MemberPermissions(
        currentUserId: id,
        projectRole: project,
        workspaceRole: workspace,
      );

  // ---------------------------------------------------------------------------
  //  Project — adding
  // ---------------------------------------------------------------------------

  group('canAddProjectMembers', () {
    test('a project admin may', () {
      expect(
        caller(project: MemberRole.admin, workspace: MemberRole.member)
            .canAddProjectMembers,
        isTrue,
      );
    });

    test('a project member may not', () {
      expect(
        caller(project: MemberRole.member, workspace: MemberRole.member)
            .canAddProjectMembers,
        isFalse,
      );
    });

    test('a project guest may not', () {
      expect(
        caller(project: MemberRole.guest, workspace: MemberRole.member)
            .canAddProjectMembers,
        isFalse,
      );
    });

    test('a workspace admin inside the project may, at any project role', () {
      // allow_permission's second arm in plane/app/permissions/base.py: an
      // active project member who is also a workspace admin passes regardless
      // of their project role.
      expect(
        caller(project: MemberRole.guest, workspace: MemberRole.admin)
            .canAddProjectMembers,
        isTrue,
      );
    });

    test('a workspace admin outside the project may not', () {
      // The same arm requires an active ProjectMember row. A workspace admin
      // who never joined has none.
      expect(
        caller(project: null, workspace: MemberRole.admin).canAddProjectMembers,
        isFalse,
      );
    });

    test('nothing is offered before the roles are known', () {
      expect(const MemberPermissions().canAddProjectMembers, isFalse);
    });
  });

  group('addableProjectRoles', () {
    // ProjectMemberViewSet.create refuses a workspace admin added below admin
    // and a workspace guest added above guest.
    test('a workspace admin can only be a project admin', () {
      expect(MemberPermissions.addableProjectRoles(MemberRole.admin),
          [MemberRole.admin]);
    });

    test('a workspace guest can only be a project guest', () {
      expect(MemberPermissions.addableProjectRoles(MemberRole.guest),
          [MemberRole.guest]);
    });

    test('a workspace member can be added at any project role', () {
      expect(MemberPermissions.addableProjectRoles(MemberRole.member),
          MemberRole.all);
    });

    test('a non-member of the workspace cannot be added at all', () {
      expect(MemberPermissions.addableProjectRoles(null), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  //  Project — changing a role
  // ---------------------------------------------------------------------------

  group('canChangeProjectRole', () {
    final ordinary = person('them',
        role: MemberRole.member, workspaceRole: MemberRole.member);

    test('a project admin may change somebody else', () {
      expect(
        caller(project: MemberRole.admin, workspace: MemberRole.member)
            .canChangeProjectRole(ordinary),
        isTrue,
      );
    });

    test('a project admin may not change a workspace admin', () {
      // Mirrors member-columns.tsx: `!isRowDataWorkspaceAdmin`.
      final wsAdmin = person('them',
          role: MemberRole.admin, workspaceRole: MemberRole.admin);
      expect(
        caller(project: MemberRole.admin, workspace: MemberRole.member)
            .canChangeProjectRole(wsAdmin),
        isFalse,
      );
    });

    test('a project admin may not change their own role', () {
      // partial_update: "You cannot update your own role", with an exemption
      // only for a workspace admin.
      final self = person('me',
          role: MemberRole.admin, workspaceRole: MemberRole.member);
      expect(
        caller(project: MemberRole.admin, workspace: MemberRole.member)
            .canChangeProjectRole(self),
        isFalse,
      );
    });

    test('a workspace admin may change their own project role', () {
      final self =
          person('me', role: MemberRole.guest, workspaceRole: MemberRole.admin);
      expect(
        caller(project: MemberRole.guest, workspace: MemberRole.admin)
            .canChangeProjectRole(self),
        isTrue,
      );
    });

    test('a project member may not, though the endpoint would let them', () {
      // The deliberate divergence. partial_update is decorated
      // @allow_permission([ADMIN, MEMBER, GUEST]) and only caps the *new* role
      // at the caller's own, so the endpoint really would accept a member
      // demoting an admin to member. Plane's web client does not offer it and
      // neither does this.
      final admin = person('them',
          role: MemberRole.admin, workspaceRole: MemberRole.member);
      expect(
        caller(project: MemberRole.member, workspace: MemberRole.member)
            .canChangeProjectRole(admin),
        isFalse,
      );
    });

    test('a project guest may not demote an admin', () {
      final admin = person('them',
          role: MemberRole.admin, workspaceRole: MemberRole.member);
      expect(
        caller(project: MemberRole.guest, workspace: MemberRole.guest)
            .canChangeProjectRole(admin),
        isFalse,
      );
    });

    test('nothing is offered before the caller is identified', () {
      // Without an id, self cannot be told from other, so every rule that
      // turns on that distinction has to fail closed.
      expect(
        caller(id: null, project: MemberRole.admin, workspace: MemberRole.admin)
            .canChangeProjectRole(ordinary),
        isFalse,
      );
    });
  });

  group('assignableProjectRoles', () {
    test('a project admin may assign any role to an ordinary member', () {
      final target = person('them',
          role: MemberRole.member, workspaceRole: MemberRole.member);
      expect(
        caller(project: MemberRole.admin, workspace: MemberRole.member)
            .assignableProjectRoles(target),
        MemberRole.all,
      );
    });

    test('a workspace guest may only ever be a project guest', () {
      // partial_update: "You cannot add a user with role higher than the
      // workspace role" — and the same filter in member-columns.tsx.
      final target = person('them',
          role: MemberRole.guest, workspaceRole: MemberRole.guest);
      expect(
        caller(project: MemberRole.admin, workspace: MemberRole.admin)
            .assignableProjectRoles(target),
        [MemberRole.guest],
      );
    });

    test('a workspace admin editing themselves is not capped', () {
      // partial_update skips the "not above your own role" check entirely when
      // the target is a workspace admin, which for a self-edit is the caller.
      final self =
          person('me', role: MemberRole.guest, workspaceRole: MemberRole.admin);
      expect(
        caller(project: MemberRole.guest, workspace: MemberRole.admin)
            .assignableProjectRoles(self),
        MemberRole.all,
      );
    });

    test('offers nothing when the role is not editable at all', () {
      final target = person('them',
          role: MemberRole.member, workspaceRole: MemberRole.member);
      expect(
        caller(project: MemberRole.member, workspace: MemberRole.member)
            .assignableProjectRoles(target),
        isEmpty,
      );
    });
  });

  // ---------------------------------------------------------------------------
  //  Project — removing and leaving
  // ---------------------------------------------------------------------------

  group('canRemoveProjectMember', () {
    test('a project admin may remove somebody else', () {
      final target = person('them',
          role: MemberRole.member, workspaceRole: MemberRole.member);
      expect(
        caller(project: MemberRole.admin, workspace: MemberRole.member)
            .canRemoveProjectMember(target),
        isTrue,
      );
    });

    test('a project admin may remove another project admin', () {
      // destroy only refuses a target whose role is *above* the caller's, and
      // admin is the ceiling.
      final target = person('them',
          role: MemberRole.admin, workspaceRole: MemberRole.member);
      expect(
        caller(project: MemberRole.admin, workspace: MemberRole.member)
            .canRemoveProjectMember(target),
        isTrue,
      );
    });

    test('nobody may remove themselves — leaving is a separate route', () {
      final self = person('me',
          role: MemberRole.member, workspaceRole: MemberRole.member);
      expect(
        caller(project: MemberRole.admin, workspace: MemberRole.admin)
            .canRemoveProjectMember(self),
        isFalse,
      );
    });

    test('a project member may not remove anyone', () {
      final target = person('them',
          role: MemberRole.guest, workspaceRole: MemberRole.member);
      expect(
        caller(project: MemberRole.member, workspace: MemberRole.member)
            .canRemoveProjectMember(target),
        isFalse,
      );
    });

    test('a workspace admin joined as a guest may remove a fellow guest', () {
      // Passes the decorator through the workspace-admin arm, and 5 >= 5
      // satisfies destroy's seniority check.
      final target = person('them',
          role: MemberRole.guest, workspaceRole: MemberRole.member);
      expect(
        caller(project: MemberRole.guest, workspace: MemberRole.admin)
            .canRemoveProjectMember(target),
        isTrue,
      );
    });

    test('a workspace admin joined as a guest may not remove a project admin',
        () {
      // destroy: "You cannot remove a user having role higher than you". The
      // decorator lets them in and then this rejects them, so the control must
      // not be offered.
      final target = person('them',
          role: MemberRole.admin, workspaceRole: MemberRole.member);
      expect(
        caller(project: MemberRole.guest, workspace: MemberRole.admin)
            .canRemoveProjectMember(target),
        isFalse,
      );
    });

    test('a workspace admin outside the project may not remove anyone', () {
      final target = person('them',
          role: MemberRole.guest, workspaceRole: MemberRole.member);
      expect(
        caller(project: null, workspace: MemberRole.admin)
            .canRemoveProjectMember(target),
        isFalse,
      );
    });
  });

  group('canLeaveProject', () {
    test('an ordinary member may leave', () {
      final members = [
        person('me', role: MemberRole.member),
        person('them', role: MemberRole.admin),
      ];
      expect(
        caller(project: MemberRole.member, workspace: MemberRole.member)
            .canLeaveProject(members),
        isTrue,
      );
    });

    test('the only admin may not leave', () {
      // leave() refuses with a 400 rather than orphaning the project, and the
      // count is on screen already, so the control is withheld instead.
      final members = [
        person('me', role: MemberRole.admin),
        person('them', role: MemberRole.member),
      ];
      expect(
        caller(project: MemberRole.admin, workspace: MemberRole.admin)
            .canLeaveProject(members),
        isFalse,
      );
    });

    test('an admin with a second admin may leave', () {
      final members = [
        person('me', role: MemberRole.admin),
        person('them', role: MemberRole.admin),
      ];
      expect(
        caller(project: MemberRole.admin, workspace: MemberRole.admin)
            .canLeaveProject(members),
        isTrue,
      );
    });

    test('somebody who is not in the project cannot leave it', () {
      expect(
        caller(project: null, workspace: MemberRole.admin)
            .canLeaveProject(const []),
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------------------
  //  Workspace
  // ---------------------------------------------------------------------------

  group('canChangeWorkspaceRole', () {
    final other = person('them', role: MemberRole.member);

    test('a workspace admin may change somebody else', () {
      expect(
        caller(workspace: MemberRole.admin).canChangeWorkspaceRole(other),
        isTrue,
      );
    });

    test('a workspace admin may not change their own role', () {
      // WorkSpaceMemberViewSet.partial_update has no self-exemption, unlike
      // the project one.
      final self = person('me', role: MemberRole.admin);
      expect(
        caller(workspace: MemberRole.admin).canChangeWorkspaceRole(self),
        isFalse,
      );
    });

    test('a workspace member may not change anyone', () {
      expect(
        caller(workspace: MemberRole.member).canChangeWorkspaceRole(other),
        isFalse,
      );
    });

    test('a workspace guest may not change anyone', () {
      expect(
        caller(workspace: MemberRole.guest).canChangeWorkspaceRole(other),
        isFalse,
      );
    });
  });

  group('assignableWorkspaceRoles', () {
    test('an admin may assign any role', () {
      expect(
        caller(workspace: MemberRole.admin)
            .assignableWorkspaceRoles(person('them', role: MemberRole.guest)),
        MemberRole.all,
      );
    });

    test('offers nothing to somebody who may not act', () {
      expect(
        caller(workspace: MemberRole.member)
            .assignableWorkspaceRoles(person('them', role: MemberRole.guest)),
        isEmpty,
      );
    });
  });

  group('canRemoveWorkspaceMember', () {
    test('a workspace admin may remove somebody else', () {
      expect(
        caller(workspace: MemberRole.admin)
            .canRemoveWorkspaceMember(person('them', role: MemberRole.admin)),
        isTrue,
      );
    });

    test('nobody may remove themselves', () {
      expect(
        caller(workspace: MemberRole.admin)
            .canRemoveWorkspaceMember(person('me', role: MemberRole.admin)),
        isFalse,
      );
    });

    test('a workspace member may not remove anyone', () {
      expect(
        caller(workspace: MemberRole.member)
            .canRemoveWorkspaceMember(person('them', role: MemberRole.guest)),
        isFalse,
      );
    });
  });

  group('canLeaveWorkspace', () {
    test('the only admin may not leave', () {
      final members = [
        person('me', role: MemberRole.admin),
        person('them', role: MemberRole.member),
      ];
      expect(
        caller(workspace: MemberRole.admin).canLeaveWorkspace(members),
        isFalse,
      );
    });

    test('an admin with a second admin may leave', () {
      final members = [
        person('me', role: MemberRole.admin),
        person('them', role: MemberRole.admin),
      ];
      expect(
        caller(workspace: MemberRole.admin).canLeaveWorkspace(members),
        isTrue,
      );
    });

    test('an ordinary member may leave', () {
      expect(
        caller(workspace: MemberRole.member)
            .canLeaveWorkspace([person('me', role: MemberRole.member)]),
        isTrue,
      );
    });

    test('a non-member has nothing to leave', () {
      expect(
        caller(workspace: null).canLeaveWorkspace(const []),
        isFalse,
      );
    });
  });

  group('workspace invitations', () {
    test('an admin may invite', () {
      expect(caller(workspace: MemberRole.admin).canInviteToWorkspace, isTrue);
    });

    test('a member may invite too', () {
      // WorkSpaceAdminPermission is misnamed: it admits Admin and Member.
      expect(caller(workspace: MemberRole.member).canInviteToWorkspace, isTrue);
    });

    test('a guest may not, and may not even list pending invitations', () {
      final guest = caller(workspace: MemberRole.guest);
      expect(guest.canInviteToWorkspace, isFalse);
      // The permission class guards every action on the viewset, listing
      // included, so asking would be a 403 rather than an empty list.
      expect(guest.canManageWorkspaceInvitations, isFalse);
    });

    test('an admin may invite at any role', () {
      expect(
        caller(workspace: MemberRole.admin).invitableWorkspaceRoles(),
        MemberRole.all,
      );
    });

    test('a member may not invite an admin', () {
      // create(): "You cannot invite a user with higher role".
      expect(
        caller(workspace: MemberRole.member).invitableWorkspaceRoles(),
        [MemberRole.member, MemberRole.guest],
      );
    });

    test('a guest is offered no roles at all', () {
      expect(caller(workspace: MemberRole.guest).invitableWorkspaceRoles(),
          isEmpty);
    });

    test('nothing before the role is known', () {
      expect(const MemberPermissions().canInviteToWorkspace, isFalse);
      expect(const MemberPermissions().invitableWorkspaceRoles(), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  //  Project — creating
  // ---------------------------------------------------------------------------
  //
  //  These gate the four create flows that, until they were wired up, had no
  //  call site at all. Getting one wrong is not cosmetic: too permissive puts a
  //  form in front of a guest and answers it with a 403 once they have filled
  //  it in.

  group('creating in a project', () {
    test('admin and member may create everything', () {
      for (final role in [MemberRole.admin, MemberRole.member]) {
        final me = caller(project: role, workspace: MemberRole.member);
        expect(me.canCreateIssue, isTrue, reason: 'issue @ $role');
        expect(me.canCreateCycle, isTrue, reason: 'cycle @ $role');
        expect(me.canCreateModule, isTrue, reason: 'module @ $role');
        expect(me.canCreatePage, isTrue, reason: 'page @ $role');
        expect(me.canCreateView, isTrue, reason: 'view @ $role');
      }
    });

    test('a guest gets only a view', () {
      // The four decorated endpoints are [ADMIN, MEMBER]. IssueViewViewSet
      // overrides neither create nor permission_classes, so nothing above
      // IsAuthenticated runs on it — and Plane's own views list offers the
      // empty-state action to a guest.
      final me = caller(project: MemberRole.guest, workspace: MemberRole.guest);
      expect(me.canCreateIssue, isFalse);
      expect(me.canCreateCycle, isFalse);
      expect(me.canCreateModule, isFalse);
      expect(me.canCreatePage, isFalse);
      expect(me.canCreateView, isTrue);
    });

    test('a workspace admin who joined as a guest still creates cycles', () {
      // allow_permission's second arm: an active project member who is also a
      // workspace admin passes regardless of their project role.
      final me = caller(project: MemberRole.guest, workspace: MemberRole.admin);
      expect(me.canCreateCycle, isTrue);
      expect(me.canCreateModule, isTrue);
      expect(me.canCreateIssue, isTrue);
    });

    test('but not pages, because that gate is not the decorator', () {
      // ProjectPagePermission reads the project role and nothing else, so the
      // workspace-admin escape does not exist for pages. Mirroring that is the
      // difference between a hidden button and a 403.
      final me = caller(project: MemberRole.guest, workspace: MemberRole.admin);
      expect(me.canCreatePage, isFalse);
    });

    test('a non-member of the project may create nothing, view included', () {
      final me = caller(project: null, workspace: MemberRole.admin);
      expect(me.canCreateIssue, isFalse);
      expect(me.canCreateCycle, isFalse);
      expect(me.canCreateModule, isFalse);
      expect(me.canCreatePage, isFalse);
      expect(me.canCreateView, isFalse);
    });

    test('nothing before the role is known', () {
      // Every screen builds this empty and only fills it in once the server has
      // answered, so "unknown" must read as "no".
      const unknown = MemberPermissions();
      expect(unknown.canCreateIssue, isFalse);
      expect(unknown.canCreateCycle, isFalse);
      expect(unknown.canCreateModule, isFalse);
      expect(unknown.canCreatePage, isFalse);
      expect(unknown.canCreateView, isFalse);
    });
  });
}
