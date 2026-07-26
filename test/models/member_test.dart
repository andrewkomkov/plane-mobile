import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/member.dart';

void main() {
  group('Member.fromJson', () {
    test('reads a plain user object', () {
      final m = Member.fromJson({
        'id': 'user-1',
        'display_name': 'jane',
        'email': 'jane@example.com',
        'first_name': 'Jane',
        'last_name': 'Doe',
      });
      expect(m.id, 'user-1');
      expect(m.displayName, 'jane');
      expect(m.email, 'jane@example.com');
    });

    test('unwraps a workspace membership, which nests the whole user', () {
      // workspaces/{slug}/members/ — WorkSpaceMemberSerializer declares
      // `member = UserLiteSerializer()`, so the person arrives expanded.
      final m = Member.fromJson({
        'id': 'workspace-membership-1',
        'role': 20,
        'member': {
          'id': 'user-1',
          'display_name': 'jane',
          'email': 'jane@example.com',
          'first_name': 'Jane',
          'last_name': 'Doe',
        },
      });
      // The user id, not the membership row id. Getting this wrong is what
      // made assignee lookups by user id silently match nothing.
      expect(m.id, 'user-1');
      expect(m.displayName, 'jane');
    });

    test('takes the user id when a membership leaves member as a bare id', () {
      // projects/{id}/members/ — ProjectMemberRoleSerializer declares no
      // nested serializer for `member`, so it renders as the foreign key.
      final m = Member.fromJson({
        'id': 'project-membership-1',
        'role': 15,
        'member': 'user-1',
        'project': 'project-1',
      });
      expect(m.id, 'user-1');
      expect(m.displayName, isEmpty);
    });

    test('falls back to the row id when there is no member field at all', () {
      expect(Member.fromJson({'id': 'user-1'}).id, 'user-1');
    });

    test('never returns a null id', () {
      expect(Member.fromJson(const {}).id, '');
    });
  });

  group('Member.label', () {
    Member named({
      String display = '',
      String first = '',
      String last = '',
      String email = '',
    }) =>
        Member(
          id: 'u',
          displayName: display,
          email: email,
          firstName: first,
          lastName: last,
        );

    test('prefers the display name', () {
      expect(named(display: 'jane', first: 'Jane').label, 'jane');
    });

    test('falls back to the full name', () {
      expect(named(first: 'Jane', last: 'Doe').label, 'Jane Doe');
    });

    test('falls back to the email', () {
      // A workspace guest reads the member list through UserLiteSerializer,
      // which omits the email — but a project membership joined against a
      // stale workspace list can be the other way round.
      expect(named(email: 'jane@example.com').label, 'jane@example.com');
    });

    test('never returns an empty string, because rows index into it', () {
      expect(named().label, isNotEmpty);
    });
  });

  group('Membership', () {
    test('keeps the membership row id separate from the user id', () {
      final m = Membership.fromJson({
        'id': 'membership-1',
        'role': 20,
        'member': 'user-1',
      });
      // PATCH and DELETE address the membership; everything else the user.
      expect(m.id, 'membership-1');
      expect(m.member.id, 'user-1');
      expect(m.role, 20);
    });

    test('defaults an unreadable role to guest rather than admin', () {
      expect(Membership.fromJson({'id': 'm'}).role, MemberRole.guest);
    });

    test('resolved() fills in names and the workspace role', () {
      final bare = Membership.fromJson({
        'id': 'membership-1',
        'role': 15,
        'member': 'user-1',
      });
      final resolved = bare.resolved(
        details: Member(
          id: 'user-1',
          displayName: 'jane',
          email: 'jane@example.com',
          firstName: 'Jane',
          lastName: 'Doe',
        ),
        workspaceRole: MemberRole.admin,
      );
      expect(resolved.id, 'membership-1');
      expect(resolved.role, 15);
      expect(resolved.member.displayName, 'jane');
      expect(resolved.workspaceRole, MemberRole.admin);
    });

    test('resolved() with nothing to add leaves the membership alone', () {
      final bare = Membership.fromJson({
        'id': 'membership-1',
        'role': 15,
        'member': 'user-1',
      });
      final resolved = bare.resolved();
      expect(resolved.member.id, 'user-1');
      expect(resolved.workspaceRole, isNull);
    });
  });

  group('MemberRole', () {
    test('labels the three roles the API can return', () {
      expect(MemberRole.label(MemberRole.admin), 'Admin');
      expect(MemberRole.label(MemberRole.member), 'Member');
      expect(MemberRole.label(MemberRole.guest), 'Guest');
    });

    test('does not invent a label for a value Plane cannot send', () {
      // 10 was "Viewer" in an older Plane and the app still carried a label
      // for it; the current ROLE_CHOICES has no such value.
      expect(MemberRole.label(10), 'Unknown');
      expect(MemberRole.label(null), 'Unknown');
    });

    test('lists roles from most to least privileged', () {
      expect(MemberRole.all, [20, 15, 5]);
    });
  });

  group('WorkspaceInvitation.fromJson', () {
    test('reads a pending invitation', () {
      final i = WorkspaceInvitation.fromJson({
        'id': 'invite-1',
        'email': 'new@example.com',
        'role': 15,
        'accepted': false,
      });
      expect(i.id, 'invite-1');
      expect(i.email, 'new@example.com');
      expect(i.role, MemberRole.member);
      expect(i.accepted, isFalse);
    });

    test('defaults an unreadable role to guest', () {
      expect(WorkspaceInvitation.fromJson(const {}).role, MemberRole.guest);
    });
  });
}
