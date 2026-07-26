/// A single reaction row: one emoji, put on one thing, by one person.
///
/// The same shape serves work items and comments. Plane keeps them in two
/// tables (`issue_reactions`, `comment_reactions`) with two serialisers, but
/// the fields this app needs — the id to nothing, the emoji, and who — are the
/// same in both, so one model reads either.
class Reaction {
  final String id;

  /// The emoji as the server stores it. See [emoji] for why this is not
  /// usually a character you can display.
  final String reaction;

  /// User id of whoever reacted. Decides whether the current user's own
  /// reaction is being shown back to them, which is what makes the chip a
  /// toggle rather than an add button.
  final String? actor;

  /// Present on the comment serialiser, absent from the work item one (which
  /// sends a whole nested `actor_detail` instead). Both are read.
  final String? displayName;

  const Reaction({
    required this.id,
    required this.reaction,
    this.actor,
    this.displayName,
  });

  static String? _id(dynamic value) {
    if (value == null) return null;
    if (value is Map) return value['id']?.toString();
    return value.toString();
  }

  factory Reaction.fromJson(Map<String, dynamic> json) {
    final actorDetail = json['actor_detail'];
    return Reaction(
      id: json['id']?.toString() ?? '',
      reaction: json['reaction']?.toString() ?? '',
      actor: _id(json['actor']),
      displayName: json['display_name']?.toString() ??
          (actorDetail is Map ? actorDetail['display_name']?.toString() : null),
    );
  }

  /// The character to actually draw.
  ///
  /// Plane does not store the emoji — it stores its Unicode code point as a
  /// decimal string, so a thumbs up is the four-to-six digit text "128077" and
  /// never "👍". Its web client renders with
  /// `isNaN(parseInt(e)) ? e : String.fromCodePoint(parseInt(e))`
  /// (`apps/web/helpers/emoji.helper.tsx`), and this mirrors that exactly,
  /// including the fallback: a value that is not a number is passed through as
  /// itself, so a reaction written by some other client as a literal emoji
  /// still displays instead of vanishing.
  ///
  /// Getting this wrong is invisible locally and obvious to everyone else — a
  /// literal "👍" posted from here would be stored verbatim and the web would
  /// render it fine, but it would never group with the web's own "128077",
  /// leaving two separate thumbs-up chips on the same work item.
  String get emoji => codeToEmoji(reaction);

  static String codeToEmoji(String code) {
    final point = int.tryParse(code);
    if (point == null) return code;
    // Guard the range before handing it to fromCharCode, which throws on a
    // negative or out-of-plane value rather than returning something drawable.
    if (point < 0 || point > 0x10FFFF) return code;
    return String.fromCharCode(point);
  }
}

/// Identical reactions collapsed into one chip.
///
/// The server sends one row per person per emoji, which is the wrong grain to
/// render — eight people agreeing should be one chip reading "👍 8", not eight
/// thumbs up in a row.
class ReactionGroup {
  /// The stored code, which is what a toggle has to send back.
  final String reaction;

  /// What to draw.
  final String emoji;

  final int count;

  /// Whether the current user is one of the [count]. Drives both the chip's
  /// selected styling and whether tapping it adds or removes.
  final bool reactedByMe;

  /// Display names of the reactors, in the order the server sent them. Used
  /// for the tooltip and the semantic label, so the chip says who and not just
  /// how many.
  final List<String> actorNames;

  const ReactionGroup({
    required this.reaction,
    required this.emoji,
    required this.count,
    required this.reactedByMe,
    this.actorNames = const [],
  });
}

/// The eight emoji Plane's own client offers, in its order.
///
/// Kept identical to `ISSUE_REACTION_EMOJI_CODES` in
/// `packages/constants/src/emoji.ts` so the picker here and the picker on the
/// web produce reactions that group together.
const List<String> kReactionEmojiCodes = [
  '128077', // thumbs up
  '128078', // thumbs down
  '128516', // grinning
  '128165', // collision
  '128533', // confused
  '129505', // brain
  '9992', // airplane
  '128064', // eyes
];

/// Collapses rows into per-emoji groups.
///
/// Order is first appearance, not count: a chip that jumps left when someone
/// else reacts is harder to hit than one that stays put, and the server
/// already returns rows newest-first so the order is at least stable between
/// loads.
List<ReactionGroup> groupReactions(
  List<Reaction> reactions,
  String? currentUserId,
) {
  final order = <String>[];
  final byCode = <String, List<Reaction>>{};
  for (final r in reactions) {
    if (r.reaction.isEmpty) continue;
    if (!byCode.containsKey(r.reaction)) {
      order.add(r.reaction);
      byCode[r.reaction] = [];
    }
    byCode[r.reaction]!.add(r);
  }

  return order.map((code) {
    final rows = byCode[code]!;
    return ReactionGroup(
      reaction: code,
      emoji: Reaction.codeToEmoji(code),
      count: rows.length,
      // An empty current user id must not match an absent actor, or every
      // reaction would come back looking like the viewer's own and the toggle
      // would try to delete other people's.
      reactedByMe: currentUserId != null &&
          currentUserId.isNotEmpty &&
          rows.any((r) => r.actor == currentUserId),
      actorNames: rows
          .map((r) => r.displayName)
          .whereType<String>()
          .where((n) => n.isNotEmpty)
          .toList(),
    );
  }).toList();
}
