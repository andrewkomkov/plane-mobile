import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/favorite.dart';

void main() {
  group('Favorite.fromJson', () {
    test('keeps the favourite row id apart from the entity id', () {
      // The whole reason this model exists. `user-favorites/{id}/` deletes by
      // the row's own id; a client that stored only the entity id would be able
      // to star something and never unstar it.
      final favorite = Favorite.fromJson({
        'id': 'fav-1',
        'entity_type': 'cycle',
        'entity_identifier': 'cycle-9',
        'project_id': 'proj-1',
      });

      expect(favorite.id, 'fav-1');
      expect(favorite.entityIdentifier, 'cycle-9');
      expect(favorite.projectId, 'proj-1');
      expect(favorite.key, 'cycle:cycle-9');
    });

    test('a folder occupies no key', () {
      // Folders are `UserFavorite` rows too, with no entity behind them. They
      // are containers to be read through, never things to star.
      final folder = Favorite.fromJson({
        'id': 'fav-2',
        'entity_type': 'folder',
        'entity_identifier': null,
        'is_folder': true,
        'name': 'Sprint stuff',
      });

      expect(folder.isFolder, isTrue);
      expect(folder.key, isNull);
    });

    test('an entity type this build does not know occupies no key', () {
      // Plane's own map also holds `issue`. Nothing in this app can draw a star
      // on one, so it must not silently take a slot in the state map either.
      final issue = Favorite.fromJson({
        'id': 'fav-3',
        'entity_type': 'issue',
        'entity_identifier': 'issue-4',
      });

      expect(issue.key, isNull);
    });
  });

  group('FavoriteEntity', () {
    test('spells the wire values Plane stores', () {
      expect(
        FavoriteEntity.values.map((e) => e.wire),
        ['project', 'cycle', 'module', 'view', 'page'],
      );
    });

    test('reads a wire value back, and refuses one it does not know', () {
      expect(FavoriteEntity.fromWire('module'), FavoriteEntity.module);
      expect(FavoriteEntity.fromWire('issue'), isNull);
      expect(FavoriteEntity.fromWire(null), isNull);
    });
  });
}
