import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/project.dart';

void main() {
  // Whether a project offers Intake is what decides whether the project screen
  // shows a way into it. Reading it wrong either hides a queue people are
  // using or offers a queue that does not exist.
  group('Project intake fields', () {
    test('reads the alias the project list annotates', () {
      // ProjectViewSet.list annotates inbox_view=F("intake_view") and
      // ProjectListSerializer declares the same alias, so this is the spelling
      // that arrives from both the list and the detail route.
      final project = Project.fromJson({
        'id': 'p1',
        'name': 'Plane Mobile',
        'identifier': 'PLM',
        'inbox_view': true,
        'intake_count': 3,
      });

      expect(project.intakeEnabled, isTrue);
      expect(project.pendingIntakeCount, 3);
    });

    test('reads the raw column name too', () {
      // ProjectSerializer has fields = "__all__", so the model's own
      // intake_view comes through beside the alias on some responses.
      final project = Project.fromJson({
        'id': 'p1',
        'name': 'Plane Mobile',
        'identifier': 'PLM',
        'intake_view': true,
      });

      expect(project.intakeEnabled, isTrue);
    });

    test('defaults to off when the response says nothing', () {
      // A project built from a search hit carries neither field, and the
      // column itself defaults to False. Off is the safe reading: it hides an
      // entry point rather than offering one that 404s.
      final project = Project.fromJson({
        'id': 'p1',
        'name': 'Plane Mobile',
        'identifier': 'PLM',
      });

      expect(project.intakeEnabled, isFalse);
    });

    test('an unknown pending count is null, not zero', () {
      // Only the list endpoint annotates intake_count. A zero invented here
      // would draw a badge claiming the queue is empty when nobody looked.
      final project = Project.fromJson({
        'id': 'p1',
        'name': 'Plane Mobile',
        'identifier': 'PLM',
        'inbox_view': true,
      });

      expect(project.pendingIntakeCount, isNull);
    });

    test('a genuine zero is kept as zero', () {
      final project = Project.fromJson({
        'id': 'p1',
        'name': 'Plane Mobile',
        'identifier': 'PLM',
        'inbox_view': true,
        'intake_count': 0,
      });

      expect(project.pendingIntakeCount, 0);
    });
  });
}
