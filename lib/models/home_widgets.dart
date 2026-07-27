/// A note pinned to the workspace home.
///
/// Stickies are **per user**, not per workspace: `WorkspaceStickyViewSet`
/// filters on `owner_id=request.user.id` and sets the owner itself on create,
/// so there is no way to see or write anyone else's, and no parameter that
/// would widen it.
class Sticky {
  final String id;

  /// Optional server-side — `extra_kwargs` marks `name` not required and the
  /// web client saves without one — so an untitled sticky is a shape the app
  /// will meet.
  final String? name;

  final String descriptionHtml;

  /// Hex, or null for the default paper. Two colours: `color` is the ink,
  /// `background_color` the paper.
  final String? color;
  final String? backgroundColor;

  final DateTime updatedAt;

  const Sticky({
    required this.id,
    this.name,
    this.descriptionHtml = '',
    this.color,
    this.backgroundColor,
    required this.updatedAt,
  });

  factory Sticky.fromJson(Map<String, dynamic> json) => Sticky(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['name'] as String,
        descriptionHtml: (json['description_html'] as String?) ?? '',
        color: json['color'] as String?,
        backgroundColor: json['background_color'] as String?,
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  /// What an untitled sticky is called on screen.
  static const String untitled = 'Untitled note';

  String get displayName => name ?? untitled;
}

/// A bookmarked URL on the workspace home.
///
/// Same ownership rule as [Sticky]: `WorkspaceUserLink` carries an owner and
/// the view scopes to the caller.
class QuickLink {
  final String id;
  final String? title;
  final String url;

  const QuickLink({required this.id, required this.url, this.title});

  factory QuickLink.fromJson(Map<String, dynamic> json) => QuickLink(
        id: (json['id'] ?? '').toString(),
        url: (json['url'] ?? '').toString(),
        title: (json['title'] as String?)?.trim().isEmpty ?? true
            ? null
            : json['title'] as String,
      );

  /// The title, or the host it points at — a row showing a bare URL is
  /// unreadable at a phone's width.
  String get displayTitle {
    final t = title;
    if (t != null) return t;
    final host = Uri.tryParse(url)?.host;
    return host == null || host.isEmpty ? url : host;
  }
}
