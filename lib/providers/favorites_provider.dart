import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/favorite.dart';
import '../services/favorite_service.dart';

/// Which things the current user has starred, and the ids needed to unstar them.
///
/// One map for all five entity types, because one endpoint serves all five —
/// see [FavoriteService]. Keys are `entityType:entityId`; values are the id of
/// the `UserFavorite` row, which is what removal is keyed on.
class FavoritesState {
  /// The workspace these favourites belong to. A workspace switch invalidates
  /// the lot rather than mixing two workspaces into one map.
  final String? workspaceSlug;

  /// `entityType:entityId` -> favourite row id. An empty value means the
  /// create is still in flight and the real id is not known yet.
  final Map<String, String> ids;

  /// Keys with a request in the air. A second tap on one of these is dropped:
  /// removal needs the favourite's own id, and between the optimistic star
  /// lighting up and the create answering, that id does not exist. Dropping the
  /// tap leaves the row showing what the server is about to agree with; the
  /// alternative is a DELETE against an id we would have to invent.
  final Set<String> pending;

  final bool loaded;

  const FavoritesState({
    this.workspaceSlug,
    this.ids = const {},
    this.pending = const {},
    this.loaded = false,
  });

  FavoritesState copyWith({
    String? workspaceSlug,
    Map<String, String>? ids,
    Set<String>? pending,
    bool? loaded,
  }) =>
      FavoritesState(
        workspaceSlug: workspaceSlug ?? this.workspaceSlug,
        ids: ids ?? this.ids,
        pending: pending ?? this.pending,
        loaded: loaded ?? this.loaded,
      );

  bool isFavorite(FavoriteEntity entity, String entityId) =>
      ids.containsKey(favoriteKey(entity.wire, entityId));

  bool isPending(FavoriteEntity entity, String entityId) =>
      pending.contains(favoriteKey(entity.wire, entityId));

  /// [items] with the favourited ones moved to the front, order otherwise kept.
  ///
  /// Plane's own cycle, module, view and page lists already come back ordered
  /// `-is_favorite` first; projects do not, because `ProjectViewSet.list`
  /// projects away the annotation the queryset carries. Doing it here makes the
  /// five lists agree with each other, and makes the reorder happen when the
  /// star is tapped rather than at the next fetch.
  List<T> favoritesFirst<T>(
    FavoriteEntity entity,
    List<T> items,
    String Function(T item) idOf,
  ) {
    if (ids.isEmpty) return items;
    final starred = <T>[];
    final rest = <T>[];
    for (final item in items) {
      (isFavorite(entity, idOf(item)) ? starred : rest).add(item);
    }
    if (starred.isEmpty) return items;
    return [...starred, ...rest];
  }
}

class FavoritesNotifier extends Notifier<FavoritesState> {
  @override
  FavoritesState build() => const FavoritesState();

  /// Reads the workspace's favourites once, or again on [force].
  ///
  /// A failure leaves the map empty and [FavoritesState.loaded] false rather
  /// than raising: a list screen that cannot say which of its rows are starred
  /// is still a working list screen, and the star heals on the next tap because
  /// the create endpoint is idempotent.
  Future<void> load(String workspaceSlug, {bool force = false}) async {
    if (workspaceSlug.isEmpty) return;
    final sameWorkspace = state.workspaceSlug == workspaceSlug;
    if (sameWorkspace && state.loaded && !force) return;
    if (!sameWorkspace) {
      // Off the current frame before touching state.
      //
      // Eight list screens call this from `initState`, which runs *during* the
      // build phase — and writing to a provider there is an assertion failure
      // in Riverpod, not a warning. Deferring here rather than at the eight
      // call sites means a ninth screen cannot reintroduce it: whoever calls
      // this is asking for the workspace's favourites, not for a particular
      // moment to be told about it.
      await Future<void>.delayed(Duration.zero);
      state = FavoritesState(workspaceSlug: workspaceSlug);
    }
    try {
      final favorites = await FavoriteService.getFavorites(workspaceSlug);
      final ids = <String, String>{};
      for (final favorite in favorites) {
        final key = favorite.key;
        if (key != null) ids[key] = favorite.id;
      }
      // Anything mid-flight outranks what the server just said: the list we
      // were handed was built before that request was answered, so honouring it
      // would flip a star back under the user's finger.
      for (final key in state.pending) {
        final optimistic = state.ids[key];
        if (optimistic != null) {
          ids[key] = optimistic;
        } else {
          ids.remove(key);
        }
      }
      state = FavoritesState(
        workspaceSlug: workspaceSlug,
        ids: ids,
        pending: state.pending,
        loaded: true,
      );
    } catch (_) {
      state = state.copyWith(workspaceSlug: workspaceSlug);
    }
  }

  /// Stars or unstars [entityId], optimistically, reverting if the server says
  /// no. Answers false when the state on screen did not survive the round trip.
  Future<bool> toggle(
    String workspaceSlug, {
    required FavoriteEntity entity,
    required String entityId,
    String? projectId,
  }) async {
    final key = favoriteKey(entity.wire, entityId);
    if (state.pending.contains(key)) return true;

    final existingId = state.ids[key];
    final before = state.ids;
    state = state.copyWith(pending: {...state.pending, key});

    try {
      if (existingId != null) {
        state = state.copyWith(ids: {...before}..remove(key));
        await FavoriteService.removeFavorite(workspaceSlug, existingId);
      } else {
        // Starred immediately with a placeholder id; the create answers with
        // the real one, which is what a later unstar will need.
        state = state.copyWith(ids: {...before, key: ''});
        final created = await FavoriteService.addFavorite(
          workspaceSlug,
          entity: entity,
          entityId: entityId,
          projectId: projectId,
        );
        state = state.copyWith(ids: {...state.ids, key: created.id});
      }
      return true;
    } catch (_) {
      state = state.copyWith(ids: before);
      return false;
    } finally {
      state = state.copyWith(pending: {...state.pending}..remove(key));
    }
  }

  /// Forgets everything. For sign-out and workspace teardown.
  void clear() {
    state = const FavoritesState();
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, FavoritesState>(FavoritesNotifier.new);
