/// Models behind the analytics screen.
///
/// ## Where the numbers come from
///
/// The database. Every figure on this screen is an aggregate Plane computed
/// server-side; none of it is folded on the phone.
///
/// That is a recent change. The analytics views live on Plane's internal API
/// (`plane/app/urls/analytic.py`) behind a session cookie, and the app
/// authenticates with an API token, which used to mean `/api/v1/` — a surface
/// with no analytics module at all. So the screen paged every project's
/// work-item list onto the device and counted there. The session proxy in
/// `plane-mobile-api` removed the constraint, and the sweep went with it.
///
/// Four reads carry the screen:
///
///   * `advance-analytics/?tab=work-items` — total, and the count in each open
///     state group. Feeds the overview cards.
///   * `advance-analytics-charts/?type=custom-work-items&x_axis=STATE_GROUPS`
///   * `advance-analytics-charts/?type=custom-work-items&x_axis=PRIORITY`
///   * `advance-analytics-stats/?type=work-items` — one row per project, split
///     by state group.
///
/// The overdue count has no equivalent in that family — none of those views
/// accepts an issue filter — so it comes from the older `default-analytics/`
/// endpoint, which does. See `AnalyticsService`.
///
/// ## Scope
///
/// The three `advance-*` views restrict themselves to projects the caller is an
/// active member of (`get_analytics_filters` joins `project_projectmember`).
/// `default-analytics/` does not; it counts the whole workspace. The overdue
/// call therefore passes an explicit project list so that every figure on the
/// screen describes the same set of projects.
///
/// This is a narrower set than the sweep used to cover: the project list the
/// sweep walked includes public projects the user has not joined, and those are
/// now excluded. Narrower, but it is the set Plane's own analytics reports.
///
/// ## Null
///
/// Every figure here is nullable and null means exactly one thing: the server
/// did not answer for that panel. It is never a stand-in for zero. The five
/// reads have two different permission classes between them and fail
/// independently, so a partial answer is normal — and a panel that is missing
/// is shown as missing rather than drawn as an empty chart.
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

/// Maps the column names in the `advance-analytics*` payloads onto the state
/// group values Plane stores.
///
/// The two differ by one underscore: the annotations are called
/// `un_started_work_items` while `state.group` holds `unstarted`. Normalising
/// here means [kStateGroups] and the theme's per-group colours keep working on
/// both shapes.
const _statsColumns = <String, String>{
  'backlog_work_items': 'backlog',
  'un_started_work_items': 'unstarted',
  'started_work_items': 'started',
  'completed_work_items': 'completed',
  'cancelled_work_items': 'cancelled',
};

/// Folds one `advance-analytics-charts/` payload into key -> count.
///
/// The response is `{"data": [{"key": ..., "name": ..., "count": n}], "schema":
/// {}}`. `schema` is only populated when the request asked for a `group_by`,
/// which these two do not, so the rows are flat.
///
/// Keys are lower-cased on the way in. `build_simple_chart_response` writes the
/// literal string `"None"` where the grouped column was null, and every value
/// Plane stores in `priority` and `state.group` is lower case, so folding the
/// case is what puts an unset priority on the `none` row the chart already
/// knows how to draw.
Map<String, int> analyticsChartCounts(dynamic body) {
  final rows = body is Map ? body['data'] : body;
  if (rows is! List) return const {};

  final counts = <String, int>{};
  for (final row in rows.whereType<Map>()) {
    final key = (row['key'] ?? '').toString().toLowerCase();
    if (key.isEmpty) continue;
    final count = (row['count'] as num?)?.toInt() ?? 0;
    if (count == 0) continue;
    counts[key] = (counts[key] ?? 0) + count;
  }
  return counts;
}

/// The overview counts, from `advance-analytics/?tab=work-items`.
class WorkItemCounts {
  final int total;
  final int backlog;
  final int unstarted;
  final int started;
  final int completed;

  const WorkItemCounts({
    required this.total,
    required this.backlog,
    required this.unstarted,
    required this.started,
    required this.completed,
  });

  /// Work that is neither finished nor cancelled.
  ///
  /// Summed from the three open groups rather than taken as
  /// `total - completed - cancelled`, because this payload has no cancelled
  /// count in it. The two are equal — the five groups partition the work items
  /// — and each addend is itself a database count.
  int get pending => backlog + unstarted + started;

  /// Each value in the payload is wrapped as `{"count": n}`.
  ///
  /// `AdvanceAnalyticsEndpoint.get_filtered_counts` used to return a
  /// previous-period figure alongside it; the second key is commented out
  /// upstream but the wrapper outlived it.
  factory WorkItemCounts.fromJson(Map<String, dynamic> json) {
    int at(String key) {
      final cell = json[key];
      if (cell is Map) return (cell['count'] as num?)?.toInt() ?? 0;
      return (cell as num?)?.toInt() ?? 0;
    }

    return WorkItemCounts(
      total: at('total_work_items'),
      backlog: at('backlog_work_items'),
      unstarted: at('un_started_work_items'),
      started: at('started_work_items'),
      completed: at('completed_work_items'),
    );
  }
}

/// One project's work items, split by state group.
///
/// From `advance-analytics-stats/?type=work-items`, which groups the caller's
/// work items by project and counts each state group in one query. Only
/// projects holding at least one work item appear — the endpoint groups over
/// issues, so an empty project has no row to be in.
class ProjectAnalytics {
  final String projectId;
  final String projectName;
  final Map<String, int> byStateGroup;

  const ProjectAnalytics({
    required this.projectId,
    required this.projectName,
    required this.byStateGroup,
  });

  int get total => byStateGroup.values.fold(0, (sum, n) => sum + n);

  factory ProjectAnalytics.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    for (final column in _statsColumns.entries) {
      final value = (json[column.key] as num?)?.toInt() ?? 0;
      if (value > 0) counts[column.value] = value;
    }
    return ProjectAnalytics(
      projectId: (json['project_id'] ?? '').toString(),
      // The endpoint selects `project__name`, so the join gives the name
      // directly and no separate project list is needed to label the rows.
      projectName: (json['project__name'] ?? 'Untitled').toString(),
      byStateGroup: counts,
    );
  }

  /// The endpoint answers with a bare list. Anything else is treated as no
  /// rows rather than as a failure — a failure is the service's `null`.
  static List<ProjectAnalytics> listFromJson(dynamic body) {
    final rows = body is Map ? (body['results'] ?? body['data']) : body;
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => ProjectAnalytics.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }
}

/// Everything the analytics screen displays.
///
/// Each field is one server-side aggregate, or null where the server did not
/// answer. Nothing here is derived from a sample.
class WorkspaceAnalytics {
  final int? total;
  final int? completed;
  final int? pending;
  final int? overdue;
  final Map<String, int>? byStateGroup;
  final Map<String, int>? byPriority;
  final List<ProjectAnalytics>? projects;

  const WorkspaceAnalytics({
    this.total,
    this.completed,
    this.pending,
    this.overdue,
    this.byStateGroup,
    this.byPriority,
    this.projects,
  });

  static const empty = WorkspaceAnalytics(
    total: 0,
    completed: 0,
    pending: 0,
    overdue: 0,
    byStateGroup: {},
    byPriority: {},
    projects: [],
  );

  /// Panels the server did not answer for, phrased for the note on screen.
  ///
  /// In the order the screen lays them out, so the sentence reads top to
  /// bottom.
  List<String> get unavailable => [
        if (total == null) 'the overview counts',
        if (overdue == null) 'the overdue count',
        if (byPriority == null) 'the priority breakdown',
        if (byStateGroup == null) 'the state breakdown',
        if (projects == null) 'the per-project breakdown',
      ];

  /// True when all five reads came back.
  bool get isComplete => unavailable.isEmpty;

  /// False when every read failed — nothing to show and nothing to say about
  /// it, which is an error rather than a partial answer.
  bool get hasAnyFigure =>
      total != null ||
      overdue != null ||
      byPriority != null ||
      byStateGroup != null ||
      projects != null;

  /// A workspace with no work items in it.
  ///
  /// Requires the total to have actually arrived: a missing panel is not an
  /// empty one, and reporting "no work items yet" because a request failed is
  /// the class of lie this screen exists to avoid.
  bool get isEmpty => total == 0;
}
