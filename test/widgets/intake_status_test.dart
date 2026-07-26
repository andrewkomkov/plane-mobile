import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/config/theme.dart';
import 'package:plane_mobile/models/intake_issue.dart';
import 'package:plane_mobile/screens/intake/intake_status.dart';

IntakeIssue entry(int status, {DateTime? snoozedTill, String? duplicateName}) =>
    IntakeIssue.fromJson({
      'id': 'row-1',
      'status': status,
      if (snoozedTill != null)
        'snoozed_till': snoozedTill.toUtc().toIso8601String(),
      if (duplicateName != null)
        'duplicate_issue_detail': {'id': 'wi-9', 'name': duplicateName},
      'issue': {'id': 'wi-1', 'name': 'Broken export', 'sequence_id': 42},
    });

Widget wrap(Widget child) => MaterialApp(
      theme: PlaneTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  // Every subtitle says what the status means for this entry rather than
  // repeating the status word, which the row already draws as an icon.
  group('intakeSubtitle', () {
    test('a pending entry says it is waiting', () {
      expect(intakeSubtitle(entry(IntakeStatus.pending)), 'Waiting for triage');
    });

    test('a live snooze names its wake date', () {
      final till = DateTime.utc(2030, 3, 12);
      expect(
        intakeSubtitle(entry(IntakeStatus.snoozed, snoozedTill: till)),
        'Snoozed until ${intakeDateLabel(till)}',
      );
    });

    // The server never sweeps an expired snooze back to pending, so the wording
    // has to distinguish "come back later" from "this is due now" — otherwise
    // a due entry reads identically to one nobody needs to look at.
    test('an expired snooze says so', () {
      final till = DateTime.now().subtract(const Duration(days: 3));
      expect(
        intakeSubtitle(entry(IntakeStatus.snoozed, snoozedTill: till)),
        startsWith('Snooze ran out'),
      );
    });

    test('a duplicate names its original when the server expanded it', () {
      expect(
        intakeSubtitle(
            entry(IntakeStatus.duplicate, duplicateName: 'The first report')),
        'Duplicate of The first report',
      );
    });

    test('a duplicate with nothing expanded does not invent a name', () {
      expect(
        intakeSubtitle(entry(IntakeStatus.duplicate)),
        'Marked duplicate',
      );
    });

    test('accepted says where the work item went', () {
      expect(
        intakeSubtitle(entry(IntakeStatus.accepted)),
        'Accepted into the project',
      );
    });
  });

  group('IntakeStatusLook', () {
    // The app's Inbox tab is the notification feed and uses Icons.inbox_outlined.
    // Intake is a different place entirely, and Plane calling both of them
    // "inbox" historically is exactly why this is worth pinning.
    test('no status borrows the notification inbox glyph', () {
      for (final status in const [-2, -1, 0, 1, 2]) {
        expect(IntakeStatusLook.icon(status), isNot(Icons.inbox_outlined));
        expect(IntakeStatusLook.icon(status), isNot(Icons.inbox));
      }
    });

    test('each status gets its own glyph', () {
      final icons = [
        for (final status in const [-2, -1, 0, 1, 2])
          IntakeStatusLook.icon(status),
      ];
      expect(icons.toSet(), hasLength(5));
    });
  });

  group('IntakeStatusPill', () {
    testWidgets('names the status', (tester) async {
      await tester.pumpWidget(
          wrap(IntakeStatusPill(entry: entry(IntakeStatus.accepted))));
      expect(find.text('Accepted'), findsOneWidget);
    });

    testWidgets('an expired snooze reads as over, not as snoozed',
        (tester) async {
      await tester.pumpWidget(wrap(IntakeStatusPill(
        entry: entry(
          IntakeStatus.snoozed,
          snoozedTill: DateTime.now().subtract(const Duration(days: 1)),
        ),
      )));

      expect(find.text('Snooze over'), findsOneWidget);
      expect(find.text('Snoozed'), findsNothing);
    });
  });

  // PlaneRow hands this to M3EPressable, which replaces the whole subtree's
  // semantics — so anything not in this string is invisible to a screen reader
  // and to tool/adb_drive.py, which is how this repo drives the app.
  group('intakeRowSemanticLabel', () {
    test('carries everything the row draws', () {
      final label = intakeRowSemanticLabel(
        IntakeIssue.fromJson({
          'status': IntakeStatus.pending,
          'issue': {
            'id': 'wi-1',
            'name': 'Broken export',
            'sequence_id': 42,
            'priority': 'high',
          },
        }),
        'PLM',
      );

      // The identifier leads: the adb driver locates a row by substring.
      expect(label, startsWith('PLM-42'));
      expect(label, contains('Broken export'));
      expect(label, contains('pending'));
      expect(label, contains('priority high'));
      expect(label, contains('Waiting for triage'));
    });

    test('says nothing about priority when there is none to say', () {
      final label = intakeRowSemanticLabel(
        IntakeIssue.fromJson({
          'status': IntakeStatus.pending,
          'issue': {'id': 'wi-1', 'name': 'Broken export', 'sequence_id': 42},
        }),
        'PLM',
      );

      expect(label, isNot(contains('priority')));
    });

    test('falls back to the sequence number with no project identifier', () {
      final label = intakeRowSemanticLabel(
        IntakeIssue.fromJson({
          'status': IntakeStatus.pending,
          'issue': {'id': 'wi-1', 'name': 'Broken export', 'sequence_id': 42},
        }),
        '',
      );

      expect(label, startsWith('Work item 42'));
    });
  });

  group('intakeDateLabel', () {
    test('is an absolute day, zero padded', () {
      expect(intakeDateLabel(DateTime(2030, 3, 7)), '07.03.2030');
    });
  });
}
