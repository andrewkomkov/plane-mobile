/// Models behind the analytics screen.
///
/// ## Why so little of this comes from the server
///
/// Plane computes analytics itself — `workspaces/{slug}/analytics/`,
/// `default-analytics/`, `advance-analytics*`, `project-stats/`. None of those
/// are reachable from this app. They are routed by `plane/app/urls/analytic.py`
/// under `/api/`, and every view there inherits `BaseSessionAuthentication`,
/// i.e. a Django session cookie. This app authenticates with an API token
/// (`setup_screen.dart` stores one for both sign-in paths), so `ApiClient`
/// talks to `/api/v1/`, whose route package (`plane/api/urls/`) has no
/// analytics module at all. A request to any analytics endpoint with the
/// credentials the app holds is a 404 or a 403, never a figure.
///
/// The v1 surface exposes exactly one aggregate the screen can use: the
/// paginated work-item list reports `total_count`, which the database computes
/// over the whole project rather than the page. Everything else — the split by
/// state, by priority, and the overdue count — has to be counted here.
///
/// So it is counted here, over *every* work item, not over one page, and the
/// screen says which figures are which. See [WorkspaceAnalytics.scanned] and
/// [WorkspaceAnalytics.isComplete].
library;

/// The state groups Plane defines, in workflow order.
///
/// Fixed rather than derived from the data so a chart keeps the same row order
/// between refreshes and does not lose a group just because it is empty.
const kStateGroups = <String>[
  'backlog',
  'unstarted',
  'started',
  'completed',
  'cancelled',
];

/// The priorities Plane defines, most urgent first.
const kPriorities = <String>['urgent', 'high', 'medium', 'low', 'none'];

/// Groups that mean the work is no longer open, so cannot be late.
const _closedGroups = <String>{'completed', 'cancelled'};

/// The few fields of a work item the analytics sweep actually needs.
///
/// The sweep asks the API for `fields=id,state,priority,target_date` and this
/// is what comes back. Deliberately not [Issue]: pulling full work items —
/// description HTML, assignees, labels — over a whole workspace to count them
/// by priority would move megabytes to answer a question about integers.
class ScannedWorkItem {
  /// The state *group*, already resolved from the state UUID against the
  /// project's states. The raw UUID is useless for aggregation because states
  /// are per-project, so two projects' "In Progress" are different rows.
  final String stateGroup;
  final String priority;
  final DateTime? targetDate;

  const ScannedWorkItem({
    required this.stateGroup,
    required this.priority,
    this.targetDate,
  });

  /// Open work whose target date has passed.
  ///
  /// Same rule as `Issue.isOverdue` — a target date of today counts as passed,
  /// because the date parses to midnight — with the addition that finished and
  /// cancelled work is never late.
  bool isOverdueAt(DateTime now) {
    final target = targetDate;
    if (target == null) return false;
    if (_closedGroups.contains(stateGroup)) return false;
    return now.isAfter(target);
  }

  /// [stateGroups] maps state UUID to group for the project being scanned.
  /// A state the map does not know is treated as backlog, which is what the
  /// screen did before and what Plane falls back to for an unset state.
  factory ScannedWorkItem.fromJson(
    Map<String, dynamic> json,
    Map<String, String> stateGroups,
  ) {
    final stateId = json['state']?.toString();
    final raw = json['target_date']?.toString();
    return ScannedWorkItem(
      stateGroup: stateGroups[stateId] ?? 'backlog',
      priority: (json['priority'] ?? 'none').toString(),
      targetDate: (raw == null || raw.isEmpty) ? null : DateTime.tryParse(raw),
    );
  }
}

/// One project's contribution to the sweep.
class ProjectScan {
  final String projectId;
  final String projectName;

  /// What the server said the project holds — `total_count` from the work-item
  /// list, a `COUNT(*)` over the project rather than over the page. This is the
  /// one figure on the screen the device did not compute.
  final int serverTotal;

  final List<ScannedWorkItem> items;

  /// Set when the project could not be read at all — the request failed, or the
  /// sweep ran out of budget before reaching it.
  ///
  /// This exists because such a project has no [serverTotal] either: the total
  /// arrives *with* the first page, so a project that was never requested looks
  /// exactly like an empty one. Without the flag, skipping a project would make
  /// the sweep report itself as complete, which is the precise dishonesty this
  /// screen was rewritten to remove.
  final bool failed;

  const ProjectScan({
    required this.projectId,
    required this.projectName,
    required this.serverTotal,
    required this.items,
    this.failed = false,
  });

  /// True when the sweep read every work item the server said was there.
  bool get isComplete => !failed && items.length >= serverTotal;

  Map<String, int> countBy(String Function(ScannedWorkItem) key) {
    final counts = <String, int>{};
    for (final item in items) {
      final k = key(item);
      counts[k] = (counts[k] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> get byStateGroup => countBy((i) => i.stateGroup);
}

/// Everything the analytics screen displays, and where each number came from.
class WorkspaceAnalytics {
  /// Sum of the per-project `total_count`s. Server-computed.
  final int total;

  /// How many work items the sweep actually read and counted. Equal to [total]
  /// on any workspace the budget could cover.
  final int scanned;

  /// Counted on the device, over [scanned] work items.
  final Map<String, int> byStateGroup;
  final Map<String, int> byPriority;
  final int overdue;

  final List<ProjectScan> projects;

  const WorkspaceAnalytics({
    required this.total,
    required this.scanned,
    required this.byStateGroup,
    required this.byPriority,
    required this.overdue,
    required this.projects,
  });

  static const empty = WorkspaceAnalytics(
    total: 0,
    scanned: 0,
    byStateGroup: {},
    byPriority: {},
    overdue: 0,
    projects: [],
  );

  int get completed => byStateGroup['completed'] ?? 0;

  /// Open work: everything not finished and not cancelled.
  int get pending => scanned - completed - (byStateGroup['cancelled'] ?? 0);

  /// Projects the sweep could not read to the end.
  ///
  /// Reported separately from [total] versus [scanned] because a project that
  /// was never requested contributes nothing to either — its work items are
  /// missing from the breakdowns *and* from the total, so counting alone cannot
  /// reveal it.
  int get incompleteProjects => projects.where((p) => !p.isComplete).length;

  /// Whether the device-side figures cover the whole workspace.
  ///
  /// When false the breakdowns describe a subset, and the screen shows the
  /// coverage rather than pretending the numbers are workspace-wide.
  bool get isComplete => incompleteProjects == 0;

  bool get isEmpty => total == 0 && scanned == 0;

  /// Folds the per-project scans into one workspace-level view.
  ///
  /// [now] is injected so the overdue count is deterministic in tests; it
  /// defaults to the wall clock in production.
  factory WorkspaceAnalytics.aggregate(
    List<ProjectScan> projects, {
    DateTime? now,
  }) {
    final asOf = now ?? DateTime.now();
    final byStateGroup = <String, int>{};
    final byPriority = <String, int>{};
    var total = 0;
    var scanned = 0;
    var overdue = 0;

    for (final project in projects) {
      total += project.serverTotal;
      for (final item in project.items) {
        scanned++;
        byStateGroup[item.stateGroup] =
            (byStateGroup[item.stateGroup] ?? 0) + 1;
        byPriority[item.priority] = (byPriority[item.priority] ?? 0) + 1;
        if (item.isOverdueAt(asOf)) overdue++;
      }
    }

    return WorkspaceAnalytics(
      total: total,
      scanned: scanned,
      byStateGroup: byStateGroup,
      byPriority: byPriority,
      overdue: overdue,
      projects: projects,
    );
  }
}
