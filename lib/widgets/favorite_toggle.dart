import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/favorite.dart';
import '../providers/favorites_provider.dart';
import 'm3e/icon_button.dart';

/// The star that puts a cycle, module, view, page or project in the user's
/// favourites, and takes it out again.
///
/// One control for all five, in the same place on every row, for the reason
/// [ArchiveToggle] is one control: a user who finds it once has found all of
/// them. It belongs in [PlaneRow]'s `trailing` slot specifically — that is the
/// only slot left outside the row's own semantics node, so the star keeps a
/// name of its own instead of being swallowed by the row's label and vanishing
/// from screen readers and from `tool/adb_drive.py`.
///
/// State is optimistic and reverts on failure, like the reaction chips do:
/// starring is a small, frequent, undoable act, and waiting on a round trip
/// before the star fills makes it feel broken.
class FavoriteToggle extends ConsumerWidget {
  final String workspaceSlug;
  final FavoriteEntity entity;
  final String entityId;

  /// The project the entity lives in. Required for everything but a project,
  /// which passes its own id — see [FavoriteService.addFavorite].
  final String? projectId;

  /// What the thing is called, for the spoken label. Rows repeat, so "Add to
  /// favorites" alone would give a list of identical controls.
  final String entityName;

  final M3EIconButtonSize size;

  const FavoriteToggle({
    super.key,
    required this.workspaceSlug,
    required this.entity,
    required this.entityId,
    required this.entityName,
    this.projectId,
    this.size = M3EIconButtonSize.small,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites.isFavorite(entity, entityId);

    return M3EIconButton(
      icon: isFavorite ? Icons.star : Icons.star_border,
      // Names the action and the target both. M3EIconButton passes the tooltip
      // straight through as the accessibility label.
      tooltip: isFavorite
          ? 'Remove ${entity.noun} $entityName from favorites'
          : 'Add ${entity.noun} $entityName to favorites',
      size: size,
      selected: isFavorite,
      onPressed: () => _toggle(context, ref),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(favoritesProvider.notifier).toggle(
          workspaceSlug,
          entity: entity,
          entityId: entityId,
          projectId: projectId,
        );
    if (ok) return;
    // The star has already snapped back by the time this runs, so the message
    // says what failed rather than what to do about it.
    messenger.showSnackBar(
      SnackBar(content: Text('Could not update favorites for $entityName')),
    );
  }
}
