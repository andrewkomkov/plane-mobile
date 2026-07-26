import 'package:flutter/material.dart';

import '../config/m3e/shapes.dart';
import '../models/reaction.dart';

/// Readable names for the emoji Plane offers.
///
/// An emoji is not a label. `tool/adb_drive.py` walks the accessibility tree
/// and a control announcing itself as "👍" is one it cannot reliably address,
/// so every chip and every picker entry is named in words. Keyed by Plane's
/// decimal code point strings — see [kReactionEmojiCodes].
const Map<String, String> kReactionNames = {
  '128077': 'thumbs up',
  '128078': 'thumbs down',
  '128516': 'grinning face',
  '128165': 'collision',
  '128533': 'confused face',
  '129505': 'brain',
  '9992': 'airplane',
  '128064': 'eyes',
};

/// The name to speak for a reaction code, falling back to the code itself for
/// an emoji some other client invented.
String reactionName(String code) => kReactionNames[code] ?? 'reaction $code';

/// A row of reaction chips with an add button.
///
/// Used both on the work item and on every comment, which is why it takes
/// callbacks rather than talking to a service itself — the two live at
/// different routes.
class ReactionBar extends StatelessWidget {
  final List<ReactionGroup> groups;

  /// Toggles [code]: adds the current user's reaction, or removes it if
  /// [ReactionGroup.reactedByMe] is already set.
  final void Function(String code) onToggle;

  /// Names what this bar reacts to, for the add button's label. Several bars
  /// sit on one screen — one per comment plus the work item's own — so "Add
  /// reaction" alone would be ambiguous to anything driving by label.
  final String targetDescription;

  /// Smaller chips for the comment cards, which are denser than the header.
  final bool compact;

  const ReactionBar({
    super.key,
    required this.groups,
    required this.onToggle,
    required this.targetDescription,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...groups.map((g) => _ReactionChip(
              group: g,
              compact: compact,
              onTap: () => onToggle(g.reaction),
            )),
        _AddReactionButton(
          compact: compact,
          targetDescription: targetDescription,
          // The picker reports the chosen code straight into the same toggle:
          // choosing one already reacted with is a removal, which is what the
          // web client does too.
          onPicked: onToggle,
        ),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final ReactionGroup group;
  final VoidCallback onTap;
  final bool compact;

  const _ReactionChip({
    required this.group,
    required this.onTap,
    required this.compact,
  });

  /// What a screen reader, or the repo's own driver, hears.
  String get _semanticLabel {
    final name = reactionName(group.reaction);
    final who = group.reactedByMe
        ? 'you and ${group.count - 1} others'
        : '${group.count}';
    final action = group.reactedByMe ? 'remove your reaction' : 'react';
    if (group.count == 1) {
      return group.reactedByMe
          ? '$name, reacted by you. Tap to $action'
          : '$name, 1 reaction. Tap to $action';
    }
    return '$name, ${group.reactedByMe ? who : '$who reactions'}. '
        'Tap to $action';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = group.reactedByMe;

    return Semantics(
      label: _semanticLabel,
      button: true,
      selected: mine,
      container: true,
      // The visual content is an emoji and a bare number, neither of which
      // means anything read aloud, so the composed label above replaces the
      // subtree rather than sitting alongside it.
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(M3EShape.full),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 9,
            vertical: compact ? 3 : 5,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(M3EShape.full),
            // Your own reaction is filled, everyone else's is outlined. That
            // is the only thing distinguishing the two states, so it uses the
            // container role rather than an opacity tint that would wash out
            // against the light surface ramp.
            color: mine ? scheme.secondaryContainer : Colors.transparent,
            border: Border.all(
              color: mine ? scheme.secondary : scheme.outlineVariant,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                group.emoji,
                style: compact
                    ? theme.textTheme.labelMedium
                    : theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 4),
              Text(
                '${group.count}',
                style: (compact
                        ? theme.textTheme.labelSmall
                        : theme.textTheme.labelMedium)
                    ?.copyWith(
                  color: mine
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddReactionButton extends StatelessWidget {
  final void Function(String code) onPicked;
  final String targetDescription;
  final bool compact;

  const _AddReactionButton({
    required this.onPicked,
    required this.targetDescription,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final size = compact ? 24.0 : 28.0;

    return Semantics(
      label: 'Add reaction to $targetDescription',
      button: true,
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: () async {
          final code = await showReactionPicker(context, targetDescription);
          if (code != null) onPicked(code);
        },
        borderRadius: BorderRadius.circular(M3EShape.full),
        // The chip itself is small, but the tap target is not allowed to be.
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outlineVariant, width: 0.8),
              ),
              child: Icon(
                Icons.add_reaction_outlined,
                size: compact ? 13 : 15,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Offers the eight emoji Plane's own client offers, and returns the chosen
/// code, or null if dismissed.
Future<String?> showReactionPicker(
  BuildContext context,
  String targetDescription,
) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'React to $targetDescription',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              children: kReactionEmojiCodes.map((code) {
                return Semantics(
                  label: 'React with ${reactionName(code)}',
                  button: true,
                  container: true,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => Navigator.pop(ctx, code),
                    borderRadius: BorderRadius.circular(M3EShape.full),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Center(
                        child: Text(
                          Reaction.codeToEmoji(code),
                          style: Theme.of(ctx).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ),
  );
}
