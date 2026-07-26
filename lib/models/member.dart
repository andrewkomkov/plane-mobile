/// Plane's membership roles, and the integers its API speaks.
///
/// Both `plane/db/models/project.py` and `plane/db/models/workspace.py` define
/// the same `ROLE_CHOICES = ((20, "Admin"), (15, "Member"), (5, "Guest"))`, and
/// the ordering is load-bearing: every permission rule on the server is written
/// as an integer comparison against another role, so "senior to" is literally
/// "greater than". There is no 10 — an older Plane had a Viewer there and this
/// app still carried a label for it, but nothing can return that value now.
class MemberRole {
  const MemberRole._();

  static const int admin = 20;
  static const int member = 15;
  static const int guest = 5;

  /// Highest first, which is the order every picker offers them in.
  static const List<int> all = [admin, member, guest];

  static String label(int? role) {
    switch (role) {
      case admin:
        return 'Admin';
      case member:
        return 'Member';
      case guest:
        return 'Guest';
      default:
        return 'Unknown';
    }
  }

  /// What the role lets someone do, for the line under a role in a picker.
  static String description(int role) {
    switch (role) {
      case admin:
        return 'Full control, including members and settings';
      case member:
        return 'Can create and edit work items';
      default:
        return 'Read-only, plus work items they are assigned';
    }
  }
}

/// A person.
///
/// Deliberately just the person: their role is a property of a [Membership],
/// not of them, because the same user holds one role in the workspace and
/// possibly a different one in each project.
class Member {
  final String id;
  final String displayName;
  final String email;
  final String firstName;
  final String lastName;
  final String? avatar;

  Member({
    required this.id,
    required this.displayName,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.avatar,
  });

  /// Best available name, for a row that has to say *something*.
  ///
  /// A workspace guest reading the member list gets `UserLiteSerializer`,
  /// which omits `email`, so falling through to the address is not always
  /// possible either.
  String get label {
    if (displayName.isNotEmpty) return displayName;
    final full = '$firstName $lastName'.trim();
    if (full.isNotEmpty) return full;
    if (email.isNotEmpty) return email;
    return 'Unknown';
  }

  /// Accepts either a bare user object or a membership envelope around one.
  ///
  /// The two member collections do not agree on shape. `workspaces/{slug}/
  /// members/` nests the whole user under `member`, because
  /// `WorkSpaceMemberSerializer` declares `member = UserLiteSerializer()`.
  /// `projects/{id}/members/` leaves `member` as a bare user id, because
  /// `ProjectMemberRoleSerializer` declares no nested serializer for it — and
  /// the `fields=(...)` argument the view passes cannot change that, since
  /// `DynamicBaseSerializer.__init__` overwrites `fields` with `expand` before
  /// using it, so the argument is a no-op. A project membership therefore
  /// arrives with an id and nothing else; [MemberService] fills in the rest
  /// from the workspace list, which is what Plane's own web client does.
  factory Member.fromJson(Map<String, dynamic> json) {
    final nested = json['member'];
    if (nested is Map) {
      return Member.fromJson(Map<String, dynamic>.from(nested));
    }
    // A membership whose `member` is a plain id names the *user* by that id.
    // Falling back to `json['id']` would take the membership row's id instead,
    // which is a different uuid and matches no assignee anywhere.
    final id = nested is String && nested.isNotEmpty ? nested : json['id'];
    return Member(
      id: id ?? '',
      displayName: json['display_name'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      avatar: json['avatar'],
    );
  }
}

/// One person's membership of a project or of a workspace.
class Membership {
  /// The membership row's own id.
  ///
  /// This is what the PATCH and DELETE routes address —
  /// `members/{this}/`, not `members/{user id}/`. They are different uuids and
  /// sending the wrong one 404s.
  final String id;

  final Member member;
  final int role;

  /// The same person's role in the enclosing workspace, when it is known.
  ///
  /// Carried on project memberships because Plane's project rules are written
  /// in terms of both roles at once: a workspace guest may only ever be a
  /// project guest, and a workspace admin is exempt from several of the checks
  /// that apply to everyone else. Null on workspace memberships, where [role]
  /// already is the workspace role.
  final int? workspaceRole;

  const Membership({
    required this.id,
    required this.member,
    required this.role,
    this.workspaceRole,
  });

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
        id: json['id']?.toString() ?? '',
        member: Member.fromJson(json),
        role: json['role'] is int
            ? json['role'] as int
            : int.tryParse('${json['role']}') ?? MemberRole.guest,
      );

  /// Fills in what a project membership arrives without: the person's name,
  /// and their workspace role. [details] must be the same user — it is looked
  /// up by [Member.id], which both halves agree on.
  Membership resolved({Member? details, int? workspaceRole}) => Membership(
        id: id,
        member: details ?? member,
        role: role,
        workspaceRole: workspaceRole ?? this.workspaceRole,
      );
}

/// A workspace invitation that has been sent but not yet answered.
class WorkspaceInvitation {
  final String id;
  final String email;
  final int role;
  final bool accepted;

  const WorkspaceInvitation({
    required this.id,
    required this.email,
    required this.role,
    required this.accepted,
  });

  factory WorkspaceInvitation.fromJson(Map<String, dynamic> json) =>
      WorkspaceInvitation(
        id: json['id']?.toString() ?? '',
        email: json['email'] ?? '',
        role: json['role'] is int
            ? json['role'] as int
            : int.tryParse('${json['role']}') ?? MemberRole.guest,
        accepted: json['accepted'] == true,
      );
}
