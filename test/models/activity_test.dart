import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/activity.dart';

void main() {
  group('Activity.fromJson', () {
    test('parses full JSON with actor display_name', () {
      final json = {
        'id': 'act-1',
        'field': 'state',
        'old_value': 'Todo',
        'new_value': 'In Progress',
        'verb': 'updated',
        'actor_detail': {'display_name': 'Alice', 'first_name': 'Alice'},
        'created_at': '2025-03-01T10:00:00Z',
        'old_identifier': 'old-id',
        'new_identifier': 'new-id',
        'comment': 'Changed state',
      };

      final activity = Activity.fromJson(json);

      expect(activity.id, 'act-1');
      expect(activity.field, 'state');
      expect(activity.oldValue, 'Todo');
      expect(activity.newValue, 'In Progress');
      expect(activity.verb, 'updated');
      expect(activity.actorDetail, 'Alice');
      expect(activity.createdAt, DateTime.utc(2025, 3, 1, 10));
      expect(activity.oldIdentifier, 'old-id');
      expect(activity.newIdentifier, 'new-id');
      expect(activity.comment, 'Changed state');
    });

    test('falls back to first_name when display_name is missing', () {
      final json = {
        'id': 'act-2',
        'actor_detail': {'first_name': 'Bob'},
      };
      final activity = Activity.fromJson(json);
      expect(activity.actorDetail, 'Bob');
    });

    test('falls back to actor string when actor_detail is null', () {
      final json = {
        'id': 'act-3',
        'actor': 'user-uuid',
      };
      final activity = Activity.fromJson(json);
      expect(activity.actorDetail, 'user-uuid');
    });

    test('handles empty JSON', () {
      final activity = Activity.fromJson(<String, dynamic>{});
      expect(activity.id, '');
      expect(activity.field, isNull);
      expect(activity.oldValue, isNull);
      expect(activity.newValue, isNull);
      expect(activity.verb, isNull);
      expect(activity.actorDetail, isNull);
    });
  });

  group('Activity.formattedDescription', () {
    Activity makeActivity({
      String? field,
      String? oldValue,
      String? newValue,
      String? verb,
      String? actorDetail,
    }) =>
        Activity(
          id: 'a1',
          field: field,
          oldValue: oldValue,
          newValue: newValue,
          verb: verb,
          actorDetail: actorDetail,
          createdAt: DateTime(2025),
        );

    test('created issue with no field', () {
      final a = makeActivity(verb: 'created', actorDetail: 'Alice');
      expect(a.formattedDescription, 'Alice created the issue');
    });

    test('updated issue with no field', () {
      final a = makeActivity(verb: 'updated', actorDetail: 'Bob');
      expect(a.formattedDescription, 'Bob updated the issue');
    });

    test('null verb with no field returns updated message', () {
      final a = makeActivity(actorDetail: 'Eve');
      expect(a.formattedDescription, 'Eve updated the issue');
    });

    test('uses Someone when actorDetail is null', () {
      final a = makeActivity(verb: 'created');
      expect(a.formattedDescription, 'Someone created the issue');
    });

    test('created verb with field and newValue', () {
      final a = makeActivity(
        field: 'priority',
        verb: 'created',
        newValue: 'high',
        actorDetail: 'Alice',
      );
      expect(a.formattedDescription, 'Alice set priority to high');
    });

    test('created verb with field but no newValue falls back', () {
      final a = makeActivity(
        field: 'state',
        verb: 'created',
        actorDetail: 'Alice',
      );
      expect(a.formattedDescription, 'Alice created the issue');
    });

    test('updated with old and new values', () {
      final a = makeActivity(
        field: 'state',
        verb: 'updated',
        oldValue: 'Todo',
        newValue: 'Done',
        actorDetail: 'Bob',
      );
      expect(a.formattedDescription, 'Bob changed status from Todo to Done');
    });

    test('updated with only newValue', () {
      final a = makeActivity(
        field: 'assignees',
        verb: 'updated',
        newValue: 'Alice',
        actorDetail: 'Bob',
      );
      expect(a.formattedDescription, 'Bob set assignee to Alice');
    });

    test('updated with only oldValue', () {
      final a = makeActivity(
        field: 'labels',
        verb: 'updated',
        oldValue: 'Bug',
        actorDetail: 'Bob',
      );
      expect(a.formattedDescription, 'Bob removed label Bug');
    });

    test('updated with neither old nor new value', () {
      final a = makeActivity(
        field: 'description',
        verb: 'updated',
        actorDetail: 'Bob',
      );
      expect(a.formattedDescription, 'Bob updated description');
    });

    test('deleted verb', () {
      final a = makeActivity(
        field: 'labels',
        verb: 'deleted',
        oldValue: 'Feature',
        actorDetail: 'Eve',
      );
      expect(a.formattedDescription, 'Eve removed label Feature');
    });

    test('deleted verb without oldValue', () {
      final a = makeActivity(
        field: 'parent',
        verb: 'deleted',
        actorDetail: 'Eve',
      );
      expect(a.formattedDescription, 'Eve removed parent issue');
    });

    test('unknown verb falls through', () {
      final a = makeActivity(
        field: 'blocks',
        verb: 'linked',
        actorDetail: 'Eve',
      );
      expect(a.formattedDescription, 'Eve linked blocking');
    });

    test('field name mapping: target_date -> due date', () {
      final a = makeActivity(
        field: 'target_date',
        verb: 'updated',
        newValue: '2025-03-15',
        actorDetail: 'Bob',
      );
      expect(a.formattedDescription, 'Bob set due date to 2025-03-15');
    });

    test('field name mapping: name -> title', () {
      final a = makeActivity(
        field: 'name',
        verb: 'updated',
        oldValue: 'Old',
        newValue: 'New',
        actorDetail: 'Bob',
      );
      expect(a.formattedDescription, 'Bob changed title from Old to New');
    });

    test('field name mapping: unknown field uses underscore replacement', () {
      final a = makeActivity(
        field: 'some_custom_field',
        verb: 'updated',
        newValue: 'val',
        actorDetail: 'Bob',
      );
      expect(a.formattedDescription, 'Bob set some custom field to val');
    });
  });
}
