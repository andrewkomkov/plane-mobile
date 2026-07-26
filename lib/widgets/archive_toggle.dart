import 'package:flutter/material.dart';
import 'm3e/chip.dart';

/// The control that swaps a list between its live and its archived contents.
///
/// Archived work items, cycles and modules each live behind their own endpoint,
/// which invites four screens with four different affordances. This is the one
/// affordance: the same chip, in the same place, saying the same word, on every
/// list that has an archive. A user who finds it once has found all of them.
///
/// A chip rather than a new screen or a nav destination, because archived
/// content is a *view of the same list*, not a different place — the rows are
/// the same rows, and the navigation the app already has does not grow.
class ArchiveToggle extends StatelessWidget {
  final bool showArchived;
  final ValueChanged<bool> onChanged;

  /// What the list holds, for the accessibility label — "cycles", "pages".
  /// The visible text stays "Archived" so the control reads the same
  /// everywhere; only the announced label names the list it belongs to.
  final String entityPlural;

  const ArchiveToggle({
    super.key,
    required this.showArchived,
    required this.onChanged,
    required this.entityPlural,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // M3EChip leaves its own visible text as the accessible name, which is
      // the bare word "Archived" — ambiguous when four screens each have one,
      // and it never says what tapping does. This node names both.
      label: showArchived
          ? 'Showing archived $entityPlural, tap to show live $entityPlural'
          : 'Show archived $entityPlural',
      button: true,
      selected: showArchived,
      // Its own node, replacing the chip's, exactly as M3EPressable does when
      // it is given a label — otherwise both names reach the tree.
      container: true,
      excludeSemantics: true,
      onTap: () => onChanged(!showArchived),
      child: M3EChip(
        label: 'Archived',
        icon: Icons.inventory_2_outlined,
        selected: showArchived,
        dense: true,
        onTap: () => onChanged(!showArchived),
      ),
    );
  }
}

/// How an archive timestamp reads in a row's subtitle.
///
/// Deliberately absolute rather than "3d ago": the useful question about
/// archived content is when it was put away, and a relative age stops being
/// legible past a couple of weeks — which is where most archived rows are.
String archivedOnLabel(DateTime? archivedAt) {
  if (archivedAt == null) return 'Archived';
  final local = archivedAt.toLocal();
  final d = local.day.toString().padLeft(2, '0');
  final m = local.month.toString().padLeft(2, '0');
  return 'Archived $d.$m.${local.year}';
}
