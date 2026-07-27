import 'package:flutter/material.dart';

/// "12 cycles", with whatever the list keeps beside it.
///
/// The cycle, module and page lists each carried their own copy of this — the
/// same eighteen lines three times, differing only in the noun — and the views
/// list, which is a fourth list of the same kind on the same screen, carried
/// none at all, so it alone showed no count and had nowhere to put an archive
/// toggle. The five workspace screens then put the identical string in
/// `M3EAppBar.subtitle` instead, which is why [label] is exposed separately:
/// the two renderings should at least be the same sentence.
class ListCountHeader extends StatelessWidget {
  final int count;

  /// The noun in the singular — "cycle", "page". [plural] covers the nouns
  /// that do not simply take an "s".
  final String singular;
  final String? plural;

  /// Usually an `ArchiveToggle`.
  final Widget? trailing;

  const ListCountHeader({
    super.key,
    required this.count,
    required this.singular,
    this.plural,
    this.trailing,
  });

  /// The count as a sentence, for a header or an app-bar subtitle.
  static String label(int count, String singular, {String? plural}) =>
      '$count ${count == 1 ? singular : (plural ?? '${singular}s')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // A trailing control brings its own 48dp target and sets the height on
      // its own; without one the strip should stay as tight as the text.
      padding: EdgeInsets.fromLTRB(
          20, trailing == null ? 8 : 0, 12, trailing == null ? 4 : 0),
      child: Row(
        children: [
          Text(
            label(count, singular, plural: plural),
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
