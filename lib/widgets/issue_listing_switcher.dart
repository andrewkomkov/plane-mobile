import 'package:flutter/material.dart';
import 'm3e/button_group.dart';

/// Which of a project's three work-item listings is on screen.
///
/// They are separate endpoints and separate querysets server-side — `issues/`
/// excludes archived rows, `archived-issues/` returns only archived ones, and
/// `draft-issues/` is a different table entirely — so exactly one of them can
/// be showing at a time.
enum IssueListing {
  live('Work items', 'work items'),
  drafts('Drafts', 'drafts'),
  archived('Archive', 'archived work items');

  const IssueListing(this.label, this.plural);

  /// The segment's visible text.
  final String label;

  /// How the listing names its contents, for empty states and counts.
  final String plural;
}

/// The one control that chooses between a project's three work-item listings.
///
/// [ArchiveToggle] is a binary switch and still the right control on the three
/// lists that have exactly two states — cycles, modules and pages each have
/// live and archived and nothing else. Work items now have a third, and a
/// second chip beside the first would be two independent-looking switches
/// standing for one mutually exclusive choice: nothing about their shape says
/// that turning Drafts on turns Archive off, and both being off would be a
/// fourth state that does not exist.
///
/// A connected button group says it in its geometry — one selection, three
/// positions, no illegal combination expressible. It also costs the header no
/// more room than the chip plus its neighbour did.
class IssueListingSwitcher extends StatelessWidget {
  final IssueListing value;
  final ValueChanged<IssueListing> onChanged;

  const IssueListingSwitcher({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// The accessibility floor, not a design choice.
  ///
  /// This was 38 so the header would read as a list header rather than a
  /// toolbar — a real density argument, and the kind normally worth deferring
  /// to. But it put three segment targets 10dp under the minimum, while the
  /// identical control one screen over sat at 48. Density is a legitimate axis
  /// to trade on; the touch-target floor is not one of them. The density comes
  /// back out of horizontal padding instead, which costs nothing a finger
  /// cares about.
  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    return M3EButtonGroup(
      height: height,
      items: [
        for (final listing in IssueListing.values)
          M3EButtonGroupItem(label: listing.label),
      ],
      selectedIndex: IssueListing.values.indexOf(value),
      onSelected: (index) => onChanged(IssueListing.values[index]),
    );
  }
}

/// How a draft's last-saved time reads in a row's subtitle.
///
/// Absolute, for the same reason `archivedOnLabel` is: a draft is a thing you
/// come back to, and "12d ago" stops being a date the moment it matters.
String draftSavedLabel(DateTime? savedAt) {
  if (savedAt == null) return 'Draft';
  final local = savedAt.toLocal();
  final d = local.day.toString().padLeft(2, '0');
  final m = local.month.toString().padLeft(2, '0');
  return 'Draft, saved $d.$m.${local.year}';
}
