import 'package:flutter_test/flutter_test.dart';
import 'package:plane_mobile/services/workspace_rollup_service.dart';

void main() {
  // `workspaces/{slug}/issues/` is the one rollup that paginates — its view
  // ends in `self.paginate`, while the cycle, module and view rollups all
  // return a bare list. A parser that guessed the same shape for all four
  // would show an empty workspace for one of them and never say why.
  group('WorkspaceRollupService.parseIssuePage', () {
    test('reads the paginated envelope', () {
      final page = WorkspaceRollupService.parseIssuePage({
        'results': [
          {'id': 'i1', 'name': 'Fix login', 'sequence_id': 7},
        ],
        'next_cursor': '50:1:0',
        'prev_cursor': '50:-1:1',
        'next_page_results': true,
        'total_results': 132,
      });

      expect(page.issues, hasLength(1));
      expect(page.issues.single.name, 'Fix login');
      expect(page.issues.single.sequenceId, 7);
      expect(page.totalCount, 132);
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, '50:1:0');
    });

    test('withholds the cursor on the last page', () {
      // The view stringifies the next Cursor unconditionally, so `next_cursor`
      // is a plausible-looking string even when there is nothing after this
      // page. Following it would re-request an offset past the end forever.
      final page = WorkspaceRollupService.parseIssuePage({
        'results': [
          {'id': 'i1', 'name': 'Fix login'},
        ],
        'next_cursor': '50:3:0',
        'next_page_results': false,
        'total_results': 101,
      });

      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
    });

    test('reads the internal API id spellings', () {
      // ViewIssueListSerializer is a hand-written to_representation and emits
      // state_id / assignee_ids / label_ids / project_id, not the external
      // API's state / assignees / labels / project.
      final page = WorkspaceRollupService.parseIssuePage({
        'results': [
          {
            'id': 'i1',
            'name': 'Fix login',
            'state_id': 'state-9',
            'assignee_ids': ['u1', 'u2'],
            'label_ids': ['l1'],
            'project_id': 'p3',
            'sub_issues_count': 4,
          },
        ],
      });

      final issue = page.issues.single;
      expect(issue.state, 'state-9');
      expect(issue.assignees, ['u1', 'u2']);
      expect(issue.labels, ['l1']);
      // Without this the row cannot name its project, and a work item shown
      // outside its project is unidentifiable.
      expect(issue.project, 'p3');
      expect(issue.subIssuesCount, 4);
    });

    test('falls back to the row count when the envelope omits a total', () {
      final page = WorkspaceRollupService.parseIssuePage({
        'results': [
          {'id': 'i1', 'name': 'A'},
          {'id': 'i2', 'name': 'B'},
        ],
      });
      expect(page.totalCount, 2);
    });

    test('accepts a bare list, and returns empty on anything else', () {
      final list = WorkspaceRollupService.parseIssuePage([
        {'id': 'i1', 'name': 'A'},
      ]);
      expect(list.issues, hasLength(1));
      expect(list.hasMore, isFalse);

      expect(WorkspaceRollupService.parseIssuePage(null).issues, isEmpty);
      expect(WorkspaceRollupService.parseIssuePage('nope').issues, isEmpty);
      expect(
          WorkspaceRollupService.parseIssuePage({'grouped_by': 'state'}).issues,
          isEmpty);
    });
  });

  // A saved view's filters are handed straight back to the server rather than
  // reapplied here, so this conversion is the whole of the filtering.
  group('WorkspaceRollupService.filtersToQuery', () {
    test('joins a list with commas, the way issue_filters splits it', () {
      final query = WorkspaceRollupService.filtersToQuery({
        'state': ['s1', 's2'],
        'priority': ['urgent', 'high'],
      });
      expect(query['state'], 's1,s2');
      expect(query['priority'], 'urgent,high');
    });

    test('drops empty lists and nulls rather than sending them empty', () {
      // Plane stores every key a view's filter editor has ever touched, so a
      // view that once filtered by label keeps `"labels": []` forever.
      final query = WorkspaceRollupService.filtersToQuery({
        'state': ['s1'],
        'labels': <String>[],
        'assignees': null,
        'cycle': [null, ''],
      });
      expect(query.keys, ['state']);
    });

    test('never forwards a key named filters', () {
      // `filters` is ComplexFilterBackend.filter_param: the backend JSON-parses
      // it before the legacy filters run, so a non-JSON value there fails the
      // whole request with a 400.
      final query = WorkspaceRollupService.filtersToQuery({
        'filters': ['whatever'],
        'state': ['s1'],
      });
      expect(query.containsKey('filters'), isFalse);
      expect(query['state'], 's1');
    });

    test('passes a scalar through as-is', () {
      final query =
          WorkspaceRollupService.filtersToQuery({'sub_issue': false, 'x': 3});
      expect(query['sub_issue'], 'false');
      expect(query['x'], '3');
    });
  });

  group('WorkspaceRollupService.parseViews', () {
    test('reads filters, access and lock off a bare list', () {
      final views = WorkspaceRollupService.parseViews([
        {
          'id': 'v1',
          'name': 'My urgent work',
          'description': '',
          'filters': {
            'priority': ['urgent']
          },
          'access': 0,
          'is_locked': true,
          'owned_by': 'u1',
          'updated_at': '2025-06-01T09:00:00Z',
        },
      ]);

      final view = views.single;
      expect(view.name, 'My urgent work');
      // Empty server-side text becomes no subtitle, not an empty line.
      expect(view.description, isNull);
      expect(view.filters['priority'], ['urgent']);
      expect(view.isPrivate, isTrue);
      expect(view.isLocked, isTrue);
      expect(view.updatedAt, DateTime.utc(2025, 6, 1, 9));
    });

    test('a view with no filters parses to an empty map, not a null one', () {
      // `IssueView.filters` defaults to {} and `query_data` — which the
      // project-level view model reads — is not a field on the model at all.
      final view = WorkspaceRollupService.parseViews([
        {'id': 'v1', 'name': 'Everything'},
      ]).single;
      expect(view.filters, isEmpty);
      expect(view.isPrivate, isFalse);
    });

    test('returns empty on an unexpected shape', () {
      expect(WorkspaceRollupService.parseViews(null), isEmpty);
      expect(WorkspaceRollupService.parseViews({'detail': 'nope'}), isEmpty);
    });
  });

  group('WorkspaceRollupService.parseCycles / parseModules', () {
    test('keeps the project a cycle belongs to', () {
      final cycles = WorkspaceRollupService.parseCycles([
        {
          'id': 'c1',
          'name': 'Sprint 12',
          'project_id': 'p1',
          'total_issues': 10,
          'completed_issues': 4,
          'start_date': '2025-06-01',
          'end_date': '2025-06-14',
        },
      ]);

      expect(cycles.single.projectId, 'p1');
      expect(cycles.single.item.name, 'Sprint 12');
      expect(cycles.single.item.progress, closeTo(0.4, 0.001));
    });

    test('keeps the project a module belongs to', () {
      final modules = WorkspaceRollupService.parseModules([
        {
          'id': 'm1',
          'name': 'Payments',
          'project_id': 'p2',
          'status': 'in-progress',
          'total_issues': 4,
          'completed_issues': 1,
        },
      ]);

      expect(modules.single.projectId, 'p2');
      expect(modules.single.item.status, 'in-progress');
    });

    test('leaves the project null when the row has none', () {
      // Nothing on the wire should do this, but a row that cannot be attributed
      // to a project must be distinguishable so the screen can drop it rather
      // than draw an unattributable cycle.
      final cycles = WorkspaceRollupService.parseCycles([
        {'id': 'c1', 'name': 'Orphan'},
      ]);
      expect(cycles.single.projectId, isNull);
    });

    test('returns empty on an unexpected shape', () {
      expect(WorkspaceRollupService.parseCycles(null), isEmpty);
      expect(WorkspaceRollupService.parseModules('nope'), isEmpty);
    });
  });

  group('WorkspaceRollupService.parseStates / parseLabels', () {
    test('states come back keyed by id', () {
      // Names are not unique across a workspace — every project ships its own
      // "Backlog" — so the id is the only usable key.
      final states = WorkspaceRollupService.parseStates([
        {'id': 's1', 'name': 'Backlog', 'group': 'backlog', 'color': '#888'},
        {'id': 's2', 'name': 'Backlog', 'group': 'backlog', 'color': '#999'},
      ]);
      expect(states.keys, containsAll(['s1', 's2']));
      expect(states['s2']!.color, '#999');
    });

    test('labels come back as a list', () {
      final labels = WorkspaceRollupService.parseLabels([
        {'id': 'l1', 'name': 'bug', 'color': '#f00'},
      ]);
      expect(labels.single.name, 'bug');
    });

    test('return empty on an unexpected shape', () {
      expect(WorkspaceRollupService.parseStates(null), isEmpty);
      expect(WorkspaceRollupService.parseLabels(null), isEmpty);
    });
  });
}
