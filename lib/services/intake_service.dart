import '../config/api_client.dart';
import '../models/intake_issue.dart';

/// One work item offered as a possible duplicate target.
///
/// `search-issues/` answers with a flat `.values()` projection rather than a
/// serialised issue, so the keys are the ORM's double-underscore joins and
/// nothing here maps onto [Issue]. Modelling it separately keeps that shape
/// where it belongs instead of half-filling a work item with nulls.
class IntakeDuplicateCandidate {
  final String id;
  final String name;
  final int sequenceId;
  final String projectIdentifier;
  final String? stateName;

  const IntakeDuplicateCandidate({
    required this.id,
    required this.name,
    required this.sequenceId,
    required this.projectIdentifier,
    this.stateName,
  });

  factory IntakeDuplicateCandidate.fromJson(Map<String, dynamic> json) =>
      IntakeDuplicateCandidate(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        sequenceId: json['sequence_id'] ?? 0,
        projectIdentifier: json['project__identifier']?.toString() ?? '',
        stateName: json['state__name']?.toString(),
      );

  String get label => '$projectIdentifier-$sequenceId';
}

/// Intake — the per-project triage queue for work items submitted from outside
/// the project. Plane shipped this as "Inbox" and renamed it to "Intake".
///
/// Not to be confused with the app's own Inbox tab, which is the notification
/// feed. Plane uses both words for both things; nothing here touches that.
///
/// Requests go through the session proxy onto the internal API, so the surface
/// to check against is `plane/app/urls/intake.py` and `IntakeIssueViewSet` in
/// `plane/app/views/intake/base.py`. The paths below are spelled the way the
/// v1 API spells them, which the internal API also serves under the same
/// names.
///
/// Three things about these routes are worth knowing before editing them:
///
/// 1. There is no intake id in any of these paths. The old code fetched the
///    project's inbox first and threaded its id through every subsequent call.
///    That round-trip is gone, and it was not merely redundant — `inboxes/`
///    has no v1 route at all, so that lookup was returning 404 and taking the
///    whole feature down with it. A project has exactly one Intake and the
///    server resolves it from `project_id` itself. Only the internal API ever
///    exposed an `intakes/` collection; do not reintroduce a call to it.
///
/// 2. The detail routes are keyed by the **work item** id, not by the
///    IntakeIssue row id. The internal URL conf spells the parameter `pk`,
///    which looks like the row, but every handler behind it looks the object
///    up with `issue_id=pk`. Passing [IntakeIssue.id] here 404s; callers must
///    pass [IntakeIssue.issueId].
///
/// 3. **The list defaults to pending only.** `IntakeIssueViewSet.list` reads
///    `request.GET.get("status", "-2")`, so a request that names no status
///    gets the pending queue and nothing else — which looks exactly like an
///    empty archive rather than like a filter. Every read here is explicit
///    about the statuses it wants.
class IntakeService {
  /// Lists intake entries with the given [statuses].
  ///
  /// The response is the internal API's cursor-paginated envelope; `results`
  /// holds the rows and `total_count` the unpaginated total. Ordering is the
  /// server's default, newest submission first.
  static Future<List<IntakeIssue>> getIntakeIssues(
    String workspaceSlug,
    String projectId, {
    List<int> statuses = IntakeStatus.open,
  }) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/intake-issues/',
      queryParameters: {'status': statuses.join(',')},
    );
    return parseIntakeIssues(response.data);
  }

  /// Reads the list response.
  ///
  /// `IntakeIssueViewSet.list` goes through `self.paginate`, so the rows are
  /// under `results` in an envelope. The bare-list branch is for the v1 API,
  /// which does not paginate this collection — both spellings have been served
  /// to this app depending on which surface the proxy was pointed at.
  static List<IntakeIssue> parseIntakeIssues(dynamic data) {
    List list;
    if (data is Map && data.containsKey('results')) {
      list = data['results'] as List;
    } else if (data is List) {
      list = data;
    } else {
      return [];
    }
    return list
        .whereType<Map>()
        .map((e) => IntakeIssue.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// How many entries are still pending, without pulling them down.
  ///
  /// `per_page: 1` because only `total_count` is wanted — the paginator counts
  /// the whole queryset regardless of the slice it returns. Answers null when
  /// the project has no Intake row at all, which the server reports as a 404
  /// rather than as an empty list.
  static Future<int?> getPendingCount(
    String workspaceSlug,
    String projectId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/intake-issues/',
      queryParameters: {
        'status': '${IntakeStatus.pending}',
        'per_page': 1,
      },
    );
    final data = response.data;
    if (data is Map && data['total_count'] is int) return data['total_count'];
    return null;
  }

  static Future<IntakeIssue> getIntakeIssue(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/intake-issues/$issueId/',
    );
    return IntakeIssue.fromJson(response.data);
  }

  /// Triages an entry.
  ///
  /// The payloads are the ones Plane's own client sends — see
  /// `updateInboxIssueStatus` / `updateInboxIssueSnoozeTill` /
  /// `updateInboxIssueDuplicateTo` in `web/core/store/inbox/inbox-issue.store.ts`.
  /// Fields of the work item itself go under an `issue` key; everything at the
  /// top level belongs to the intake row.
  ///
  /// **A 200 here does not mean the change took.** `partial_update` lets the
  /// creator of a work item through regardless of role, but only applies the
  /// intake half of the payload when the caller is a project admin or a
  /// workspace admin. A project member triaging their own submission therefore
  /// gets a success response with the status unchanged. The returned entry is
  /// the server's, not an echo of the request, so callers must read the status
  /// back off it rather than assume — see [triage].
  static Future<IntakeIssue> updateIntakeIssue(
    String workspaceSlug,
    String projectId,
    String issueId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.patch(
      '/workspaces/$workspaceSlug/projects/$projectId/intake-issues/$issueId/',
      data: data,
    );
    return IntakeIssue.fromJson(response.data);
  }

  /// Moves an entry to [status] and reports whether the server agreed.
  ///
  /// Wraps [updateIntakeIssue] with the silent-no-op check described there:
  /// the result carries the entry as the server now holds it plus whether that
  /// is what was asked for, so a caller can say "you are not allowed to do
  /// that" instead of drawing a state change that did not happen.
  static Future<IntakeTriageResult> triage(
    String workspaceSlug,
    String projectId,
    String issueId, {
    required int status,
    DateTime? snoozedTill,
    bool clearSnooze = false,
    String? duplicateTo,
  }) async {
    final updated = await updateIntakeIssue(
      workspaceSlug,
      projectId,
      issueId,
      triagePayload(
        status: status,
        snoozedTill: snoozedTill,
        clearSnooze: clearSnooze,
        duplicateTo: duplicateTo,
      ),
    );
    return IntakeTriageResult(
        entry: updated, applied: updated.status == status);
  }

  /// Builds the body of a triage PATCH.
  ///
  /// Kept separate and public because the serializer silently ignores keys it
  /// does not recognise: a misspelled field here returns 200 and changes
  /// nothing, which is indistinguishable from success at the call site. The
  /// only defence is pinning the exact shape in a test.
  static Map<String, dynamic> triagePayload({
    required int status,
    DateTime? snoozedTill,
    bool clearSnooze = false,
    String? duplicateTo,
  }) {
    final payload = <String, dynamic>{'status': status};
    if (snoozedTill != null) {
      // The column is a DateTimeField; Plane's own client sends a JS Date,
      // which serialises to UTC ISO-8601. The toUtc() is not cosmetic — a
      // local-time string carrying no offset is read as UTC by DRF, which
      // would move the wake date by the timezone difference.
      payload['snoozed_till'] = snoozedTill.toUtc().toIso8601String();
    } else if (clearSnooze) {
      // Explicitly null, not absent: `partial_update` only clears a field the
      // request actually names, so omitting this would leave a stale wake date
      // on an entry that is back in the pending queue.
      payload['snoozed_till'] = null;
    }
    if (duplicateTo != null) payload['duplicate_to'] = duplicateTo;
    return payload;
  }

  /// Whether Intake is switched on for a project, and how much is waiting.
  ///
  /// Two requests, because no single endpoint answers both. The project read
  /// comes first and is the gate: `intake_view` (published as `inbox_view`) is
  /// the only field that says the feature is on, and an Intake row outliving
  /// the toggle being switched off means the queue endpoint answering proves
  /// nothing. The count is only asked for once the gate is open.
  ///
  /// Callers already holding a freshly listed [Project] have both values on it
  /// and do not need this; it exists because the project a screen is handed
  /// may have come out of the SQLite cache, which predates both columns.
  ///
  /// Note that the project read is not free of side effects: `retrieve` fires
  /// Plane's `recent_visited_task`, so calling this records a visit. That is
  /// the truth — the user did open the project — but it is not obvious from
  /// the call site.
  static Future<IntakeAvailability> resolveAvailability(
    String workspaceSlug,
    String projectId,
  ) async {
    final dio = await ApiClient.getInstance();
    final project =
        await dio.get('/workspaces/$workspaceSlug/projects/$projectId/');
    final data = project.data;
    final enabled = data is Map &&
        (data['inbox_view'] == true || data['intake_view'] == true);
    if (!enabled) return const IntakeAvailability(enabled: false);

    // A count is a nicety; being unable to get one is not a reason to hide a
    // queue that is demonstrably on.
    try {
      return IntakeAvailability(
        enabled: true,
        pendingCount: await getPendingCount(workspaceSlug, projectId),
      );
    } catch (_) {
      return const IntakeAvailability(enabled: true);
    }
  }

  /// Work items in the project that could be the original of a duplicate.
  ///
  /// `search-issues/` rather than the workspace search: the duplicate target
  /// has to live in the same project, and this endpoint reads through
  /// `Issue.issue_objects`, whose manager excludes anything in a triage state.
  /// That is what stops the picker offering one intake entry as the duplicate
  /// of another. An empty [query] is allowed and returns the first hundred.
  static Future<List<IntakeDuplicateCandidate>> searchDuplicateTargets(
    String workspaceSlug,
    String projectId,
    String query,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/search-issues/',
      queryParameters: {'search': query, 'workspace_search': 'false'},
    );
    final data = response.data;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) =>
            IntakeDuplicateCandidate.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

/// Whether a project offers Intake, and the size of its pending queue.
class IntakeAvailability {
  final bool enabled;

  /// Null when not known — see [Project.pendingIntakeCount].
  final int? pendingCount;

  const IntakeAvailability({required this.enabled, this.pendingCount});
}

/// The outcome of a triage write.
class IntakeTriageResult {
  /// The entry as the server holds it after the write.
  final IntakeIssue entry;

  /// Whether the server actually moved the entry to the requested status.
  /// False means the write was accepted and ignored — see
  /// [IntakeService.updateIntakeIssue].
  final bool applied;

  const IntakeTriageResult({required this.entry, required this.applied});
}
