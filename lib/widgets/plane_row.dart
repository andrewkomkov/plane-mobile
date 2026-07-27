import 'package:flutter/material.dart';
import '../config/m3e/motion.dart';
import '../config/m3e/shapes.dart';
import '../config/m3e/typography.dart';
import '../config/theme.dart';

/// How much room a row is allowed to take, and what shape it takes.
///
/// A density is not a fork: every variant fills the same slots from the same
/// tokens and differs only in the surface it sits on and the padding around it.
enum PlaneRowDensity {
  /// Tonal card with the expressive corner. What every full-width list uses.
  standard,

  /// Same content and the same text position, no fill, tighter vertically.
  /// For a list that shares the screen with something else — the calendar's
  /// day pane, where a third of the height is already spent on the month grid.
  compact,

  /// Vertical card. The kanban column is 280dp wide, which is not enough for
  /// a leading icon, a title and a trailing cluster side by side, so the same
  /// slots stack instead.
  card,
}

/// One person shown in a row's avatar stack.
///
/// Deliberately not the `Member` model: rows are also built from notification
/// payloads and search hits, which never produce one.
@immutable
class PlaneAvatar {
  final String name;
  final String? imageUrl;

  const PlaneAvatar({required this.name, this.imageUrl});
}

/// The one row every list in this app is built from.
///
/// Before this existed, "a thing in a list" was drawn by three unrelated
/// widgets plus half a dozen inline `Row`s, so the same issue looked one way in
/// the project list, another in the inbox and a third in a saved view — same
/// content, three paddings, two icon sizes, two treatments of the identifier.
/// Everything goes through here now, and a screen that shows more or less fills
/// a different slot rather than growing its own widget.
///
/// Slots, top to bottom: an identifier line carrying [identifier] and [badges],
/// the [title], a [subtitle] line that may end in [subtitleTrailing], a [chips]
/// wrap and a [progress] bar. To the right sit [metadata] and [avatars], and
/// then [trailing].
///
/// [semanticLabel] is required because this app is driven from outside over
/// `adb shell uiautomator` (see `tool/adb_drive.py`), which can only find a row
/// that names itself. It also has to be complete: [M3EPressable] replaces the
/// subtree's semantics with the label, so anything the row draws — state icon,
/// priority, labels, avatars — is invisible unless the label says it.
class PlaneRow extends StatefulWidget {
  /// Leading icon. Ignored when [leading] is given.
  final IconData? icon;
  final Color? iconColor;

  /// Arbitrary leading widget, for the rows an icon cannot express.
  final Widget? leading;

  /// Short identifier above the title — an issue's `PLM-123`.
  final String? identifier;

  /// Small indicators on the identifier line. The priority glyph lives here.
  final List<Widget> badges;

  final String title;
  final int titleMaxLines;

  /// Takes the emphasized cut of the title role. One row in a list at most —
  /// an unread notification — or the emphasis stops meaning anything.
  final bool emphasizeTitle;

  final String? subtitle;

  /// Right-hand end of the subtitle line: a timestamp, a `3/8` count. Rendered
  /// after a bullet when there is a [subtitle] to separate it from.
  final String? subtitleTrailing;

  /// Pills under the title — issue labels, and anything else that flows.
  final List<Widget> chips;

  /// Completion bar, 0..1.
  final double? progress;
  final Color? progressColor;

  /// Compact indicators at the right of the row. Non-interactive: they sit
  /// inside the row's own semantics node, which replaces theirs.
  final List<Widget> metadata;

  final List<PlaneAvatar> avatars;

  /// Right-most slot, and the only one outside the row's semantics node, so a
  /// button here keeps its own label and stays reachable from automation.
  final Widget? trailing;

  final PlaneRowDensity density;

  /// The row that has to stand out from its neighbours — an unread
  /// notification, a card currently under the finger being dragged. Steps the
  /// surface up rather than tinting it, which is how M3 says "lifted".
  final bool highlighted;

  final bool? selected;
  final String semanticLabel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Names what [onLongPress] does, for the rows where the long-press is the
  /// only route to an action rather than a shortcut to one drawn in the row.
  final String? longPressHint;

  const PlaneRow({
    super.key,
    this.icon,
    this.iconColor,
    this.leading,
    this.identifier,
    this.badges = const [],
    required this.title,
    this.titleMaxLines = 1,
    this.emphasizeTitle = false,
    this.subtitle,
    this.subtitleTrailing,
    this.chips = const [],
    this.progress,
    this.progressColor,
    this.metadata = const [],
    this.avatars = const [],
    this.trailing,
    this.density = PlaneRowDensity.standard,
    this.highlighted = false,
    this.selected,
    required this.semanticLabel,
    this.onTap,
    this.onLongPress,
    this.longPressHint,
  });

  /// The identifier treatment, exposed because the table view draws its ID
  /// column outside a row and has to match it.
  static TextStyle identifierStyle(ThemeData theme) =>
      theme.textTheme.labelSmall!
          .copyWith(color: theme.colorScheme.onSurfaceVariant);

  @override
  State<PlaneRow> createState() => _PlaneRowState();
}

class _PlaneRowState extends State<PlaneRow> {
  /// Card press scale, matching [M3EPressable]'s own default for surfaces.
  static const double _pressedScale = 0.96;

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (widget.density) {
      case PlaneRowDensity.standard:
        return _surface(
          theme,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: BoxDecoration(
            color: widget.highlighted
                ? theme.colorScheme.surfaceContainerHigh
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(M3EShape.large),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          content: _horizontalContent(theme),
        );
      case PlaneRowDensity.compact:
        return _surface(
          theme,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          // No fill, but the text still starts where a standard row's text
          // starts, so switching a list between the two does not shift it.
          decoration: widget.highlighted
              ? BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(M3EShape.large),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          content: _horizontalContent(theme),
        );
      case PlaneRowDensity.card:
        return _surface(
          theme,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: widget.highlighted
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(M3EShape.large),
            border: Border.all(
              color: widget.highlighted
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: 0.8,
            ),
          ),
          padding: const EdgeInsets.all(12),
          content: _verticalContent(theme),
        );
    }
  }

  /// Wraps [content] in the row's surface and its press behaviour.
  ///
  /// The gesture and the semantics node cover the content only, while the
  /// scale covers the whole surface. That split is what lets [PlaneRow.trailing]
  /// hold a real button: `M3EPressable`'s label *replaces* the subtree's
  /// semantics, so a delete button sitting inside it would vanish from screen
  /// readers and from `adb shell uiautomator` both. Lifting the press scale out
  /// here keeps the card moving as one piece anyway.
  Widget _surface(
    ThemeData theme, {
    required EdgeInsets margin,
    required BoxDecoration? decoration,
    required EdgeInsets padding,
    required Widget content,
  }) {
    final pressable = M3EPressable(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      longPressHint: widget.longPressHint,
      semanticLabel: widget.semanticLabel,
      selected: widget.selected,
      // The scale lives on the surface below, not here.
      pressedScale: 1.0,
      onPressedChanged: (pressed) {
        if (mounted) setState(() => _pressed = pressed);
      },
      child: Padding(
        padding: widget.trailing == null
            ? padding
            : padding.copyWith(right: padding.right / 2),
        child: content,
      ),
    );

    final surface = Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: decoration ?? const BoxDecoration(),
        child: Row(
          children: [
            Expanded(child: pressable),
            if (widget.trailing != null)
              Padding(
                padding: EdgeInsets.only(right: padding.right / 2),
                child: widget.trailing,
              ),
          ],
        ),
      ),
    );

    return M3ESpringBuilder(
      value: _pressed ? _pressedScale : 1.0,
      spring: M3EMotion.fastSpatial,
      child: surface,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
    );
  }

  Widget _horizontalContent(ThemeData theme) {
    final right = _rightCluster(theme);
    return Row(
      children: [
        if (_leading(theme) case final lead?) ...[
          lead,
          const SizedBox(width: 12),
        ],
        Expanded(child: _textColumn(theme)),
        if (right != null) ...[
          const SizedBox(width: 8),
          right,
        ],
      ],
    );
  }

  Widget _verticalContent(ThemeData theme) {
    final right = _rightCluster(theme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _textColumn(theme),
        // The card is too narrow for a side cluster, so the indicators wrap
        // under the text instead of being dropped.
        if (right != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (_leading(theme) case final lead?) ...[
                lead,
                const SizedBox(width: 8),
              ],
              right,
            ],
          ),
        ],
      ],
    );
  }

  Widget? _leading(ThemeData theme) {
    if (widget.leading != null) return widget.leading;
    if (widget.icon == null) return null;
    return Icon(
      widget.icon,
      size: PlaneTheme.iconLarge,
      color: widget.iconColor ?? theme.colorScheme.onSurfaceVariant,
    );
  }

  Widget _textColumn(ThemeData theme) {
    final secondary = theme.colorScheme.onSurfaceVariant;
    final hasMetaLine = widget.identifier != null || widget.badges.isNotEmpty;
    final hasSubtitleLine =
        widget.subtitle != null || widget.subtitleTrailing != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasMetaLine) ...[
          Row(
            children: [
              if (widget.identifier != null)
                Flexible(
                  child: Text(
                    widget.identifier!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PlaneRow.identifierStyle(theme),
                  ),
                ),
              for (final badge in widget.badges) ...[
                const SizedBox(width: 8),
                badge,
              ],
            ],
          ),
          const SizedBox(height: 4),
        ],
        Text(
          widget.title,
          maxLines: widget.titleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: widget.emphasizeTitle
              ? M3EType.emphasized(theme.textTheme.titleMedium!)
              : theme.textTheme.titleMedium,
        ),
        if (hasSubtitleLine) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              if (widget.subtitle != null)
                Expanded(
                  child: Text(
                    widget.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                )
              else
                const Spacer(),
              if (widget.subtitleTrailing != null)
                Text(
                  widget.subtitle == null
                      ? widget.subtitleTrailing!
                      : ' • ${widget.subtitleTrailing!}',
                  // A quieter cut of the subtitle role: this is the least
                  // important string in the row, and `outline` is a border
                  // colour, not a text one.
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: secondary.withValues(alpha: 0.7)),
                ),
            ],
          ),
        ],
        if (widget.chips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: widget.chips),
        ],
        if (widget.progress != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(M3EShape.full),
            child: LinearProgressIndicator(
              value: widget.progress,
              minHeight: 4,
              backgroundColor: theme.colorScheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                  widget.progressColor ?? theme.colorScheme.primary),
            ),
          ),
        ],
      ],
    );
  }

  Widget? _rightCluster(ThemeData theme) {
    final items = <Widget>[
      ...widget.metadata,
      if (widget.avatars.isNotEmpty) PlaneAvatarStack(avatars: widget.avatars),
    ];
    if (items.isEmpty) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          items[i],
        ],
      ],
    );
  }
}

/// A trailing indicator on a row: an icon, optionally with a number beside it.
///
/// Exists so that a sub-issue count, an overdue clock and a project marker are
/// the same size and the same colour wherever they appear, which is what they
/// were not when every screen drew its own.
class PlaneRowMeta extends StatelessWidget {
  final IconData icon;
  final String? text;

  /// Only for indicators that carry meaning in their colour — an overdue date
  /// is red because it is overdue, not for decoration.
  final Color? color;

  const PlaneRowMeta({
    super.key,
    required this.icon,
    this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effective = color ?? theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: PlaneTheme.iconSmall, color: effective),
        if (text != null) ...[
          const SizedBox(width: 2),
          Text(text!,
              style: theme.textTheme.labelSmall?.copyWith(color: effective)),
        ],
      ],
    );
  }
}

/// Overlapping avatars, capped at three.
class PlaneAvatarStack extends StatelessWidget {
  static const double _size = 24;
  static const double _overlap = 14;
  static const int _max = 3;

  final List<PlaneAvatar> avatars;

  const PlaneAvatarStack({super.key, required this.avatars});

  @override
  Widget build(BuildContext context) {
    final shown = avatars.take(_max).toList();
    if (shown.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: _size + (shown.length - 1) * _overlap,
      height: _size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * _overlap,
              child: _Avatar(avatar: shown[i]),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final PlaneAvatar avatar;
  const _Avatar({required this.avatar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = avatar.imageUrl;

    if (url != null && url.isNotEmpty) {
      return Container(
        width: PlaneAvatarStack._size,
        height: PlaneAvatarStack._size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border:
              Border.all(color: theme.colorScheme.outlineVariant, width: 0.8),
        ),
        child: CircleAvatar(
          radius: PlaneAvatarStack._size / 2,
          backgroundImage: NetworkImage(url),
          backgroundColor: theme.colorScheme.surface,
        ),
      );
    }

    return CircleAvatar(
      radius: PlaneAvatarStack._size / 2,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      child: Text(
        (avatar.name.isNotEmpty ? avatar.name : '?')[0].toUpperCase(),
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
