import 'package:flutter/material.dart';
import '../../models/member.dart';
import '../../models/member_permissions.dart';
import '../../services/workspace_service.dart';
import '../../utils/api_error.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/m3e/text_field.dart';
import '../../widgets/m3e/chip.dart';
import '../../widgets/member_row.dart';
import '../../widgets/plane_row.dart';
import '../../widgets/section_header.dart';

/// Everyone in the workspace, plus the invitations that have been sent and not
/// yet answered.
///
/// The workspace list is the wider of the two member screens: a project can
/// only draw on people who are already here, so this is where somebody new to
/// the organisation actually gets in. Which is also why the two "add" flows
/// differ — a project adds an existing workspace member, this one sends mail.
class WorkspaceMembersScreen extends StatefulWidget {
  final String workspaceSlug;

  const WorkspaceMembersScreen({super.key, required this.workspaceSlug});

  @override
  State<WorkspaceMembersScreen> createState() => _WorkspaceMembersScreenState();
}

class _WorkspaceMembersScreenState extends State<WorkspaceMembersScreen> {
  List<Membership> _members = [];
  List<WorkspaceInvitation> _invitations = [];
  bool _loading = true;
  String? _error;

  /// Denies everything until the role lookup lands.
  MemberPermissions _permissions = const MemberPermissions();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final membersRequest =
          WorkspaceService.getWorkspaceMemberships(widget.workspaceSlug);
      final meRequest = WorkspaceService.getMyMembership(widget.workspaceSlug);

      final members = await membersRequest;
      final me = await meRequest;

      final permissions = MemberPermissions(
        currentUserId: me?.member.id,
        workspaceRole: me?.role,
      );

      // Pending invitations are behind the same permission class as sending
      // one, so a guest asking for them gets a 403. Only fetch when the role
      // says the call will succeed, rather than swallowing an error that the
      // user cannot act on anyway.
      final invitations = permissions.canManageWorkspaceInvitations
          ? await WorkspaceService.getInvitations(widget.workspaceSlug)
              .catchError((_) => <WorkspaceInvitation>[])
          : <WorkspaceInvitation>[];

      if (!mounted) return;
      setState(() {
        _members = members;
        _invitations = invitations;
        _permissions = permissions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = describeApiError(e, fallback: 'Could not load members');
        _loading = false;
      });
    }
  }

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  //  Actions. Each one is only reachable when [_permissions] says the server
  //  would accept it; see lib/models/member_permissions.dart for the rules.
  // ---------------------------------------------------------------------------

  Future<void> _invite() async {
    final allowed = _permissions.invitableWorkspaceRoles();
    if (allowed.isEmpty) return;

    final controller = TextEditingController();
    // Guest is the server's own default for an invitation, and the least
    // surprising thing to pre-select.
    int role = allowed.last;

    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Invite to workspace'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              M3ETextField(
                label: 'Email address',
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              // Chips rather than a dropdown, so every role is a named,
              // tappable node for the accessibility tree.
              //
              // `M3EChip`, not `ChoiceChip`: `chipTheme` pins a `StadiumBorder`
              // for both states, so a stock chip expresses selection as a fill
              // tint and nothing else, while every other chip in the app also
              // pulls its corner in. And a `Wrap`, not a `Row`: three roles at
              // a large text scale overflowed a row inside a dialog.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in allowed)
                    M3EChip(
                      label: MemberRole.label(r),
                      selected: role == r,
                      onTap: () => setDialogState(() => role = r),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send invite'),
            ),
          ],
        ),
      ),
    );

    final email = controller.text.trim();
    controller.dispose();
    if (send != true || email.isEmpty) return;

    try {
      await WorkspaceService.invite(widget.workspaceSlug, {email: role});
      _report('Invited $email as ${MemberRole.label(role)}');
      await _load();
    } catch (e) {
      // The server refuses the whole batch for an address that is already a
      // member or is malformed, and says which — worth passing through.
      _report(describeApiError(e, fallback: 'Could not send the invite'));
    }
  }

  Future<void> _changeRole(Membership target) async {
    final allowed = _permissions.assignableWorkspaceRoles(target);
    if (allowed.isEmpty) return;
    final picked = await showRolePicker(
      context,
      title: 'Role for ${target.member.label}',
      allowed: allowed,
      current: target.role,
    );
    if (picked == null || picked == target.role || !mounted) return;

    // Demotion to guest is not only a workspace change: the same handler drops
    // the person to guest in every project in the workspace, which is not
    // obvious from a role picker.
    if (picked == MemberRole.guest) {
      final ok = await confirmMemberAction(
        context,
        title: 'Make ${target.member.label} a guest?',
        message: 'They also become a guest in every project in this workspace. '
            'Restoring their old project roles is a manual job.',
        confirmLabel: 'Make guest',
      );
      if (!ok) return;
    }

    try {
      await WorkspaceService.updateMemberRole(
          widget.workspaceSlug, target.id, picked);
      _report('${target.member.label} is now ${MemberRole.label(picked)}');
      await _load();
    } catch (e) {
      _report(describeApiError(e, fallback: 'Could not change role'));
    }
  }

  Future<void> _remove(Membership target) async {
    final ok = await confirmMemberAction(
      context,
      title: 'Remove ${target.member.label}?',
      message: 'They lose access to this workspace and to every project in it.',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    try {
      await WorkspaceService.removeMember(widget.workspaceSlug, target.id);
      _report('${target.member.label} removed from the workspace');
      await _load();
    } catch (e) {
      // One refusal here cannot be predicted from this screen: the server
      // blocks removing anyone who is the sole admin of some project.
      _report(describeApiError(e, fallback: 'Could not remove member'));
    }
  }

  Future<void> _leave() async {
    final ok = await confirmMemberAction(
      context,
      title: 'Leave this workspace?',
      message: 'You lose access to every project in it. '
          'An admin has to invite you back.',
      confirmLabel: 'Leave',
    );
    if (!ok) return;
    try {
      await WorkspaceService.leave(widget.workspaceSlug);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _report(describeApiError(e, fallback: 'Could not leave the workspace'));
    }
  }

  Future<void> _revoke(WorkspaceInvitation invitation) async {
    final ok = await confirmMemberAction(
      context,
      title: 'Withdraw the invite to ${invitation.email}?',
      message: 'The link in their email stops working.',
      confirmLabel: 'Withdraw',
    );
    if (!ok) return;
    try {
      await WorkspaceService.revokeInvitation(
          widget.workspaceSlug, invitation.id);
      await _load();
    } catch (e) {
      _report(describeApiError(e, fallback: 'Could not withdraw the invite'));
    }
  }

  Future<void> _changeInvitationRole(WorkspaceInvitation invitation) async {
    final allowed = _permissions.invitableWorkspaceRoles();
    if (allowed.isEmpty) return;
    final picked = await showRolePicker(
      context,
      title: 'Role for ${invitation.email}',
      allowed: allowed,
      current: invitation.role,
    );
    if (picked == null || picked == invitation.role) return;
    try {
      await WorkspaceService.updateInvitationRole(
          widget.workspaceSlug, invitation.id, picked);
      await _load();
    } catch (e) {
      _report(describeApiError(e, fallback: 'Could not change the role'));
    }
  }

  List<MemberAction> _memberActions(Membership m) {
    final isSelf = _permissions.isSelf(m);
    return [
      if (_permissions.canChangeWorkspaceRole(m))
        MemberAction(
          label: 'Change role',
          icon: Icons.badge_outlined,
          onSelected: () => _changeRole(m),
        ),
      if (_permissions.canRemoveWorkspaceMember(m))
        MemberAction(
          label: 'Remove from workspace',
          icon: Icons.person_remove_outlined,
          destructive: true,
          onSelected: () => _remove(m),
        ),
      // The server refuses to let the last admin leave, and that is knowable
      // from the list already on screen, so it is not offered at all.
      if (isSelf && _permissions.canLeaveWorkspace(_members))
        MemberAction(
          label: 'Leave workspace',
          icon: Icons.logout,
          destructive: true,
          onSelected: _leave,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: M3EAppBar(
        title: 'Workspace members',
        subtitle: _loading ? null : '${_members.length} people',
        actions: [
          if (_permissions.canInviteToWorkspace)
            M3EAppBarAction(
              icon: Icons.person_add_alt,
              tooltip: 'Invite by email',
              emphasized: true,
              onPressed: _invite,
            ),
        ],
      ),
      body: _loading
          ? const LoadingStateWidget()
          : _error != null
              ? ErrorStateWidget(message: _error, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    // A short list still has to be draggable, or pull to
                    // refresh does nothing on a two-person workspace.
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      ..._members.map((m) => MemberRow(
                            member: m.member,
                            role: m.role,
                            isSelf: _permissions.isSelf(m),
                            actions: _memberActions(m),
                          )),
                      if (_invitations.isNotEmpty) ...[
                        // The shared header, with the count in its pill rather
                        // than folded into the string. This screen was one of
                        // eight that invented its own section heading.
                        SectionHeader(
                          label: 'Pending invitations',
                          count: _invitations.length,
                        ),
                        ..._invitations.map(_invitationRow),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _invitationRow(WorkspaceInvitation invitation) {
    final theme = Theme.of(context);
    return PlaneRow(
      icon: Icons.mail_outline,
      title: invitation.email,
      subtitle: 'Invited as ${MemberRole.label(invitation.role)}',
      semanticLabel:
          'Invitation to ${invitation.email}, ${MemberRole.label(invitation.role)}, pending',
      metadata: [
        Text(
          'Pending',
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
      trailing: !_permissions.canManageWorkspaceInvitations
          ? null
          : M3EIconButton(
              icon: Icons.more_vert,
              tooltip: 'Manage invitation to ${invitation.email}',
              size: M3EIconButtonSize.small,
              onPressed: () => showMemberActions(
                context,
                invitation.email,
                [
                  MemberAction(
                    label: 'Change role',
                    icon: Icons.badge_outlined,
                    onSelected: () => _changeInvitationRole(invitation),
                  ),
                  MemberAction(
                    label: 'Withdraw invite',
                    icon: Icons.cancel_outlined,
                    destructive: true,
                    onSelected: () => _revoke(invitation),
                  ),
                ],
              ),
            ),
    );
  }
}
