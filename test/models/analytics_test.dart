import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/models/analytics.dart';

/// One row of `advance-analytics-stats/?type=work-items`.
Map<String, dynamic> statsRow({
  String id = 'proj-1',
  String name = 'Project One',
  int backlog = 0,
  int unstarted = 0,
  int started = 0,
  int completed = 0,
  int cancelled = 0,
}) =>
    {
      'project_id': id,
      'project__name': name,
      'backlog_work_items': backlog,
      'un_started_work_items': unstarted,
      'started_work_items': started,
      'completed_work_items': completed,
      'cancelled_work_items': cancelled,
    };

void main() {
  group('analyticsChartCounts', () {
    test('folds an advance-analytics-charts payload into key -> count', () {
      final counts = analyticsChartCounts({
        'data': [
          {'key': 'urgent', 'name': 'urgent', 'count': 3},
          {'key': 'low', 'name': 'low', 'count': 1},
        ],
        'schema': <String, dynamic>{},
      });

      expect(counts, {'urgent': 3, 'low': 1});
    });

    test('folds the null bucket onto the none row', () {
      // build_simple_chart_response writes the literal "None" where the
      // grouped column was null; every value Plane stores in these columns is
      // lower case, so "None" and "none" are the same bucket.
      final counts = analyticsChartCounts({
        'data': [
          {'key': 'None', 'count': 2},
          {'key': 'none', 'count': 1},
        ],
      });

      expect(counts, {'none': 3});
    });

    test('drops empty buckets so the chart does not draw zero-length bars', () {
      final counts = analyticsChartCounts({
        'data': [
          {'key': 'urgent', 'count': 0},
          {'key': 'high', 'count': 4},
        ],
      });

      expect(counts, {'high': 4});
    });

    test('an unexpected shape counts as no rows, not as a crash', () {
      expect(analyticsChartCounts(null), isEmpty);
      expect(analyticsChartCounts({'detail': 'Not found'}), isEmpty);
    });
  });

  group('WorkItemCounts', () {
    test('unwraps the {count: n} cells the endpoint returns', () {
      final counts = WorkItemCounts.fromJson({
        'total_work_items': {'count': 10},
        'backlog_work_items': {'count': 2},
        'un_started_work_items': {'count': 1},
        'started_work_items': {'count': 3},
        'completed_work_items': {'count': 4},
      });

      expect(counts.total, 10);
      expect(counts.completed, 4);
      // The three open groups; cancelled is not in this payload and is not
      // needed, because the five groups partition the work items.
      expect(counts.pending, 6);
    });

    test('a missing key is zero, not a failure', () {
      final counts = WorkItemCounts.fromJson({
        'total_work_items': {'count': 1},
      });

      expect(counts.total, 1);
      expect(counts.pending, 0);
      expect(counts.completed, 0);
    });
  });

  group('ProjectAnalytics', () {
    test('renames un_started to the state group value', () {
      final project =
          ProjectAnalytics.fromJson(statsRow(unstarted: 2, started: 1));

      // The annotation is called un_started_work_items but state.group holds
      // "unstarted", and the chart order and the theme both key on the latter.
      expect(project.byStateGroup, {'unstarted': 2, 'started': 1});
      expect(project.total, 3);
    });

    test('takes the project name from the joined column', () {
      final project = ProjectAnalytics.fromJson(statsRow(name: 'Alpha'));
      expect(project.projectName, 'Alpha');
      expect(project.projectId, 'proj-1');
    });

    test('drops empty groups so the stacked bar has no zero-width segments',
        () {
      final project = ProjectAnalytics.fromJson(statsRow(completed: 5));
      expect(project.byStateGroup, {'completed': 5});
    });

    test('parses the bare list the endpoint answers with', () {
      final projects = ProjectAnalytics.listFromJson([
        statsRow(id: 'p1', name: 'Alpha', started: 1),
        statsRow(id: 'p2', name: 'Beta', completed: 2),
      ]);

      expect(projects.map((p) => p.projectName), ['Alpha', 'Beta']);
      expect(projects.last.total, 2);
    });

    test('an unexpected shape is no rows', () {
      expect(ProjectAnalytics.listFromJson({'detail': 'nope'}), isEmpty);
    });
  });

  group('WorkspaceAnalytics', () {
    WorkspaceAnalytics full() => WorkspaceAnalytics(
          total: 10,
          completed: 4,
          pending: 6,
          overdue: 2,
          byStateGroup: const {'started': 6, 'completed': 4},
          byPriority: const {'urgent': 10},
          projects: [ProjectAnalytics.fromJson(statsRow(started: 6))],
        );

    test('a full answer names nothing as unavailable', () {
      final data = full();
      expect(data.unavailable, isEmpty);
      expect(data.isComplete, isTrue);
      expect(data.hasAnyFigure, isTrue);
    });

    test('names each panel the server did not answer for', () {
      const data = WorkspaceAnalytics(
        total: 10,
        completed: 4,
        pending: 6,
        byPriority: {'urgent': 10},
      );

      expect(data.unavailable, [
        'the overdue count',
        'the state breakdown',
        'the per-project breakdown',
      ]);
      expect(data.isComplete, isFalse);
      expect(data.hasAnyFigure, isTrue);
    });

    test('nothing at all is distinguishable from everything at zero', () {
      // The trap this replaces: the old sweep could report a workspace as
      // complete and empty when it had simply failed to read anything.
      const nothing = WorkspaceAnalytics();
      expect(nothing.hasAnyFigure, isFalse);
      expect(nothing.isEmpty, isFalse);

      expect(WorkspaceAnalytics.empty.hasAnyFigure, isTrue);
      expect(WorkspaceAnalytics.empty.isEmpty, isTrue);
    });

    test('a missing overview is not an empty workspace', () {
      const data = WorkspaceAnalytics(
        byStateGroup: {},
        byPriority: {},
        projects: [],
      );

      expect(data.isEmpty, isFalse);
      expect(data.unavailable, contains('the overview counts'));
    });
  });
}
