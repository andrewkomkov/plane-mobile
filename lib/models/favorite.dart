/// What kind of thing a favourite points at.
///
/// The wire strings are Plane's own `UserFavorite.entity_type` values, from
/// `plane/app/serializers/favorite.py`'s `get_entity_model_and_serializer` map.
/// That map also knows `issue` and `folder`; neither is offered here — the app
/// has no issue-level favourite affordance, and folders are a web-only
/// organising device that mobile only ever reads through (see
/// [FavoriteService.getFavorites]).
///
/// The wire value is spelled out rather than taken from `Enum.name` so that
/// renaming a constant here cannot silently change what goes over the wire.
enum FavoriteEntity {
  project('project'),
  cycle('cycle'),
  module('module'),
  view('view'),
  page('page');

  const FavoriteEntity(this.wire);

  /// The value Plane stores in `user_favorites.entity_type`.
  final String wire;

  /// How the entity is named in a spoken label — "Add Sprint 4 to favorites".
  String get noun => wire;

  static FavoriteEntity? fromWire(String? value) {
    for (final e in FavoriteEntity.values) {
      if (e.wire == value) return e;
    }
    return null;
  }
}

/// One row of Plane's `user_favorites` table.
///
/// The [id] is the part that matters and the part that is easy to lose: the
/// generic favourites endpoint removes by the favourite's *own* id, not by the
/// id of the thing favourited. A client that keeps only "cycle X is starred"
/// can add a favourite but can never take it away again.
class Favorite {
  /// The `UserFavorite` row id. `DELETE user-favorites/{id}/` keys on this.
  final String id;

  /// One of [FavoriteEntity.wire], or something a newer server invented.
  final String entityType;

  /// The id of the favourited cycle, module, view, page or project.
  ///
  /// Nullable on the wire because a folder is also a `UserFavorite` row and
  /// points at nothing.
  final String? entityIdentifier;

  /// The project the favourite is scoped to, absent for workspace-level rows.
  final String? projectId;

  /// True for the folders the web client lets a user group favourites into.
  final bool isFolder;

  const Favorite({
    required this.id,
    required this.entityType,
    this.entityIdentifier,
    this.projectId,
    this.isFolder = false,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) => Favorite(
        id: json['id']?.toString() ?? '',
        entityType: json['entity_type']?.toString() ?? '',
        entityIdentifier: json['entity_identifier']?.toString(),
        projectId: json['project_id']?.toString(),
        isFolder: json['is_folder'] == true,
      );

  /// The key this favourite occupies in [FavoritesState]: type plus target.
  ///
  /// Null for anything that cannot be toggled from a row — a folder, or an
  /// entity type this build does not know about.
  String? get key {
    final id = entityIdentifier;
    if (isFolder || id == null || id.isEmpty) return null;
    if (FavoriteEntity.fromWire(entityType) == null) return null;
    return favoriteKey(entityType, id);
  }
}

/// How a favourite is addressed in the app's own state map.
String favoriteKey(String entityType, String entityId) =>
    '$entityType:$entityId';
