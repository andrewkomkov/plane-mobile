import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_client.dart';
import '../models/favorite.dart';

/// Plane's favourites, through the generic `user-favorites` collection.
///
/// Plane ships two favourites schemes against one table. The older one is
/// per entity — `user-favorite-cycles/`, `user-favorite-modules/`,
/// `user-favorite-views/`, `favorite-pages/{id}/`, `user-favorite-projects/` —
/// and the newer one is this single collection. They write the same
/// `UserFavorite` rows, so they cannot disagree about storage, but they
/// disagree about everything else, and only one of them can actually be used:
///
///  * **Reading.** Every per-entity `list` action is a `BaseViewSet` with
///    `model = UserFavorite` and no `serializer_class`, so DRF's
///    `get_serializer_class` assertion fires and the request 500s. There is no
///    working read on that side at all. `favorite-pages/` does not even route a
///    list. This collection's GET is the only one that answers.
///  * **Coverage.** The per-entity scheme could be read indirectly off the
///    `is_favorite` annotation the cycle, module, view and page list endpoints
///    already carry — but not for projects: `ProjectViewSet.list` builds its own
///    `.values(...)` projection that drops the annotation, and only
///    `projects/details/` keeps it. One of the five entity types has no
///    per-entity read either way.
///  * **Removal.** This is the cost of choosing the collection. Per-entity
///    DELETE is keyed by the *entity* id, which a row already knows. This one is
///    keyed by the favourite row's own id, which is only learnt by listing or by
///    creating. [FavoritesNotifier] keeps those ids for exactly that reason.
///
/// So: the generic collection, for reads and writes both, for all five entity
/// types. Mixing would mean two vocabularies for one table.
class FavoriteService {
  /// Injected by tests in place of a real HTTP client.
  @visibleForTesting
  static Dio? debugClient;

  static Future<Dio> _client() async {
    final injected = debugClient;
    if (injected != null) return injected;
    return ApiClient.getInstance();
  }

  static String _base(String workspaceSlug) =>
      '/workspaces/$workspaceSlug/user-favorites/';

  /// Every favourite the caller has in this workspace, folders flattened.
  ///
  /// `WorkspaceFavoriteEndpoint.get` filters `parent__isnull=True`, so anything
  /// the user dragged into a favourites folder on the web is missing from the
  /// top-level answer. Left there, a foldered cycle would draw as unstarred and
  /// the star would read as an invitation to favourite what is already
  /// favourited. Each folder is therefore expanded through
  /// `user-favorites/{id}/group/`, which is one extra request per folder and
  /// zero for the usual case of no folders at all.
  ///
  /// The same endpoint also excludes workspace-level pages
  /// (`project__isnull=True & entity_type == "page"`). Mobile only ever sees
  /// project pages, so nothing reachable from this app falls in that hole.
  static Future<List<Favorite>> getFavorites(String workspaceSlug) async {
    final dio = await _client();
    final response = await dio.get(_base(workspaceSlug));
    final top = _parseList(response.data);

    final folders = top.where((f) => f.isFolder).toList();
    if (folders.isEmpty) return top;

    final nested = await Future.wait(
      folders.map((f) => _folderContents(dio, workspaceSlug, f.id)),
    );
    return [...top, ...nested.expand((e) => e)];
  }

  static Future<List<Favorite>> _folderContents(
    Dio dio,
    String workspaceSlug,
    String folderId,
  ) async {
    try {
      final response = await dio.get('${_base(workspaceSlug)}$folderId/group/');
      return _parseList(response.data);
    } catch (_) {
      // A folder that cannot be read costs the stars inside it, not the whole
      // list — the top-level favourites are already in hand and are the ones a
      // mobile user is far more likely to have.
      return const [];
    }
  }

  /// Favourites [entityId], and answers with the row that now represents it.
  ///
  /// [projectId] is required for everything except a workspace-level entity:
  /// `UserFavoriteSerializer` marks `project_id` read-only, so the view takes it
  /// from the request body by hand and drops it if absent, leaving a favourite
  /// the workspace list will not return. For a project it is the project's own
  /// id, which is what `ProjectFavoritesViewSet` writes too.
  ///
  /// The endpoint is idempotent: asked for a favourite that already exists it
  /// answers 200 with the existing row rather than tripping the table's unique
  /// constraint. That is what makes a star tapped against stale state heal
  /// instead of failing.
  static Future<Favorite> addFavorite(
    String workspaceSlug, {
    required FavoriteEntity entity,
    required String entityId,
    String? projectId,
  }) async {
    final dio = await _client();
    final response = await dio.post(
      _base(workspaceSlug),
      data: {
        'entity_type': entity.wire,
        'entity_identifier': entityId,
        if (projectId != null) 'project_id': projectId,
      },
    );
    final data = response.data;
    if (data is Map) {
      return Favorite.fromJson(Map<String, dynamic>.from(data));
    }
    throw StateError('user-favorites/ answered ${data.runtimeType}, not a row');
  }

  /// Removes a favourite by the id of the favourite row itself.
  static Future<void> removeFavorite(
    String workspaceSlug,
    String favoriteId,
  ) async {
    final dio = await _client();
    await dio.delete('${_base(workspaceSlug)}$favoriteId/');
  }

  /// Both favourites routes answer with a bare list, but every other list in
  /// this app has turned out to be an envelope at least once, so this reads
  /// either shape.
  @visibleForTesting
  static List<Favorite> parseFavorites(dynamic data) => _parseList(data);

  static List<Favorite> _parseList(dynamic data) {
    final list = data is Map ? (data['results'] ?? const []) : data;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Favorite.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
