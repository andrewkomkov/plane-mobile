import 'package:flutter/material.dart';
import '../models/member.dart';
import 'bottom_sheet_picker.dart';
import 'confirm_dialog.dart';
import 'm3e/icon_button.dart';
import 'plane_row.dart';

/// One thing offered on a member's overflow menu.
class MemberAction {
  final String label;
  final IconData icon;

  /// Renders in the error colour. Purely presentational — the confirmation is
  /// the caller's job, because only it knows what the action costs.
  final bool destructive;

  final VoidCallback onSelected;

  const MemberAction({
    required this.label,
    required this.icon,
    this.destructive = false,
    required this.onSelected,
  });
}

/// A person in a member list, built from [PlaneRow] like every other list.
///
/// Both member screens use this so that a project member and a workspace
/// member are the same row with the same slots — the only difference between
/// them is which actions the caller is allowed to be offered, and that is
/// decided before it gets here.
class MemberRow extends StatelessWidget {
  final Member member;

  /// The role to display. Null renders nothing rather than guessing, since a
  /// wrong role here is worse than a missing one.
  final int? role;

  /// Marks the caller's own row, which changes the label and the copy on the
  /// actions ("Leave" rather than "Remove").
  final bool isSelf;

  final List<MemberAction> actions;

  const MemberRow({
    super.key,
    required this.member,
    this.role,
    this.isSelf = false,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = member.label;
    final roleLabel = role == null ? null : MemberRole.label(role);

    // The row's own semantics node replaces everything drawn inside it, so the
    // role and the "you" marker have to be spelled out here or they are
    // invisible to a screen reader and to `tool/adb_drive.py`.
    final semantics = [
      name,
      if (isSelf) 'you',
      if (roleLabel != null) roleLabel,
      if (member.email.isNotEmpty) member.email,
    ].join(', ');

    return PlaneRow(
      leading: _Avatar(member: member),
      title: isSelf ? '$name (you)' : name,
      subtitle: member.email.isEmpty ? null : member.email,
      semanticLabel: semantics,
      metadata: [
        if (roleLabel != null)
          Text(
            roleLabel,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
      trailing: actions.isEmpty
          ? null
          : M3EIconButton(
              icon: Icons.more_vert,
              tooltip: 'Manage $name',
              size: M3EIconButtonSize.small,
              onPressed: () => showMemberActions(context, name, actions),
            ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Member member;
  const _Avatar({required this.member});

  static const double _size = 36;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = member.avatar;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: _size / 2,
        backgroundImage: NetworkImage(url),
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
      );
    }
    return CircleAvatar(
      radius: _size / 2,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      child: Text(
        member.label[0].toUpperCase(),
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

/// The overflow menu for a member row.
///
/// Built from [BottomSheetPicker] rather than hand-rolled, which is also what
/// proves the component: an action sheet is a picker with nothing selected.
Future<void> showMemberActions(
  BuildContext context,
  String name,
  List<MemberAction> actions,
) async {
  final selected = await BottomSheetPicker.show<MemberAction>(
    context: context,
    title: name,
    items: [
      for (final action in actions)
        BottomSheetPickerItem<MemberAction>(
          value: action,
          label: action.label,
          icon: action.icon,
          destructive: action.destructive,
        ),
    ],
  );
  selected?.onSelected();
}

/// Pick one of [allowed].
///
/// [allowed] is the caller's permitted set, already narrowed by
/// `MemberPermissions` — a role that would be refused by the server never
/// reaches this list, so there is nothing here to disable or explain away.
Future<int?> showRolePicker(
  BuildContext context, {
  required String title,
  required List<int> allowed,
  int? current,
}) {
  return BottomSheetPicker.show<int>(
    context: context,
    title: title,
    selectedValue: current,
    items: [
      for (final role in allowed)
        BottomSheetPickerItem<int>(
          value: role,
          label: MemberRole.label(role),
          subtitle: MemberRole.description(role),
        ),
    ],
  );
}

/// Confirm something that cannot be undone from here.
///
/// Superseded by `confirmDestructive`, which is the same dialog without the
/// word "member" in its name and is what the other fifteen sites that need one
/// should call. Kept as a forwarder so the six existing call sites do not have
/// to move in the same change that generalised it.
Future<bool> confirmMemberAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) =>
    confirmDestructive(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    );
