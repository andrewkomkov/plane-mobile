import 'reaction.dart';

class Comment {
  final String id;
  final String? commentHtml;
  final String? actorDetail;
  final String? createdBy;

  /// Reactions on this comment.
  ///
  /// These arrive embedded in the comment itself — `IssueCommentSerializer`
  /// declares `comment_reactions` as a nested many serialiser — so the whole
  /// activity feed's reactions come back with the comment list in one request.
  /// Fetching them per comment instead would be one round trip per card.
  final List<Reaction> reactions;

  /// User id of whoever wrote the comment.
  ///
  /// This is what decides whether the current user may edit or delete it. The
  /// v1 API does not send an `actor_detail` object the way the internal API
  /// does, so the id is the only identity that reliably arrives, and the
  /// display name has to be resolved against the project member list.
  final String? actor;

  /// Set by the server the first time the body actually changes, so an edited
  /// comment can say so rather than silently differing from what people read.
  final DateTime? editedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  Comment({
    required this.id,
    this.commentHtml,
    this.actorDetail,
    this.createdBy,
    this.actor,
    this.editedAt,
    this.reactions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// A copy with [reactions] replaced.
  ///
  /// Reacting answers with the reaction row, not the comment, so the card is
  /// updated in place from what the caller already holds rather than by
  /// refetching the whole feed and losing the reader's scroll position.
  Comment copyWithReactions(List<Reaction> reactions) => Comment(
        id: id,
        commentHtml: commentHtml,
        actorDetail: actorDetail,
        createdBy: createdBy,
        actor: actor,
        editedAt: editedAt,
        reactions: reactions,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// Whether [userId] wrote this comment.
  ///
  /// Both `actor` and `created_by` are checked because they are set by
  /// different mechanisms server-side — `actor` explicitly at creation,
  /// `created_by` by the base model from the request user — and a comment made
  /// through an integration can carry one without the other.
  bool isAuthoredBy(String? userId) =>
      userId != null &&
      userId.isNotEmpty &&
      (actor == userId || createdBy == userId);

  static String? _id(dynamic value) {
    if (value == null) return null;
    if (value is Map) return value['id']?.toString();
    return value.toString();
  }

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id']?.toString() ?? '',
        commentHtml: json['comment_html'],
        actorDetail: (json['actor_detail'] is Map
                ? json['actor_detail']['display_name']
                : json['actor_detail']) ??
            json['created_by']?.toString(),
        createdBy: _id(json['created_by']),
        actor: _id(json['actor']),
        editedAt: DateTime.tryParse(json['edited_at']?.toString() ?? ''),
        reactions: (json['comment_reactions'] as List?)
                ?.whereType<Map>()
                .map((e) => Reaction.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        updatedAt:
            DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      );
}
