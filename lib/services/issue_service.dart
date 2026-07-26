import 'package:dio/dio.dart';

import '../config/api_client.dart';
import '../models/issue.dart';
import '../models/state.dart';
import '../models/activity.dart';
import '../models/link.dart';
import '../models/reaction.dart';
import '../models/estimate_point.dart';

class IssueService {
  static Future<Map<String, dynamic>> getIssues(
    String workspaceSlug,
    String projectId, {
    String? cursor,
    int perPage = 50,
    String orderBy = '-created_at',
  }) async {
    final dio = await ApiClient.getInstance();
    final params = <String, dynamic>{
      'per_page': perPage,
      'order_by': orderBy,
    };
    if (cursor != null) params['cursor'] = cursor;

    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/',
      queryParameters: params,
    );

    final data = response.data;
    final issues =
        (data['results'] as List?)?.map((e) => Issue.fromJson(e)).toList() ??
            [];

    return {
      'issues': issues,
      'next_cursor': data['next_cursor'],
      'next_page_results': data['next_page_results'] ?? false,
      'total_results': data['total_results'] ?? 0,
    };
  }

  static Future<Issue> getIssue(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/',
    );
    return Issue.fromJson(response.data);
  }

  /// Renames relation keys to what Plane's internal write serializer expects.
  ///
  /// `IssueCreateSerializer` declares `state_id`, `parent_id`, `label_ids` and
  /// `assignee_ids` (see `plane/app/serializers/issue.py`). A payload using the
  /// plain names is not rejected — the serialiser simply ignores the unknown
  /// keys — so changing a state or an assignee would appear to succeed and
  /// then quietly do nothing. Translating in one place keeps every call site
  /// speaking the model's own field names.
  static Map<String, dynamic> _toWritePayload(Map<String, dynamic> data) {
    const renames = {
      'state': 'state_id',
      'parent': 'parent_id',
      'labels': 'label_ids',
      'assignees': 'assignee_ids',
    };
    final out = <String, dynamic>{};
    data.forEach((key, value) => out[renames[key] ?? key] = value);
    return out;
  }

  static Future<Issue> createIssue(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/',
      data: _toWritePayload(data),
    );
    return Issue.fromJson(response.data);
  }

  static Future<Issue> updateIssue(
    String workspaceSlug,
    String projectId,
    String issueId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.patch(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/',
      data: _toWritePayload(data),
    );
    return Issue.fromJson(response.data);
  }

  static Future<void> deleteIssue(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/',
    );
  }

  static Future<List<IssueState>> getStates(
    String workspaceSlug,
    String projectId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/states/',
    );
    final data = response.data;
    if (data is List) {
      return data.map((e) => IssueState.fromJson(e)).toList();
    }
    if (data is Map && data.containsKey('results')) {
      return (data['results'] as List)
          .map((e) => IssueState.fromJson(e))
          .toList();
    }
    return [];
  }

  /// Sub-issues of [issueId].
  ///
  /// This lives only on Plane's internal API, which used to be unreachable —
  /// it authenticates by session cookie and ignores the `X-Api-Key` this app
  /// sends, and the v1 API the app was pinned to has no sub-issue route at all.
  /// It works now because requests go through the proxy in plane-mobile-api,
  /// which exchanges the token for a real session. Verified against the live
  /// instance.
  static Future<List<Issue>> getSubIssues(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/sub-issues/',
    );
    // The internal API answers with an object, not a list:
    // {"sub_issues": [...], "state_distribution": {...}}.
    final data = response.data;
    if (data is Map && data['sub_issues'] is List) {
      return (data['sub_issues'] as List)
          .map((e) => Issue.fromJson(e))
          .toList();
    }
    if (data is List) {
      return data.map((e) => Issue.fromJson(e)).toList();
    }
    return [];
  }

  /// Relations (blocking / blocked by / duplicate / relates to) on [issueId].
  ///
  /// Reachable through the proxy, like [getSubIssues]. Two bugs had to be
  /// fixed before it could work: the path was `issue-relations/`, plural,
  /// which is a route on neither API, and the response is not a list — the
  /// server returns an object keyed by relation kind
  /// (`{"blocking": [...], "blocked_by": [...], ...}`), so the old `is List`
  /// check never matched and the method always returned empty.
  ///
  /// The write path is [addRelation] and [removeRelation].
  static Future<List<Map<String, dynamic>>> getIssueRelations(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/issue-relation/',
    );
    return parseIssueRelations(response.data);
  }

  /// Flattens the server's kind-keyed relation object into one list, tagging
  /// each entry with the kind it was filed under.
  ///
  /// Kept separate from the request so the shape can be tested without a server.
  static List<Map<String, dynamic>> parseIssueRelations(dynamic data) {
    if (data is! Map) return [];
    final out = <Map<String, dynamic>>[];
    data.forEach((kind, entries) {
      if (entries is! List) return;
      for (final entry in entries) {
        if (entry is! Map) continue;
        out.add(<String, dynamic>{
          ...Map<String, dynamic>.from(entry),
          // The rows carry their own relation_type, but only the key is
          // guaranteed present, so the key wins as the authoritative kind.
          'relation_type': kind.toString(),
        });
      }
    });
    return out;
  }

  static Future<List<Activity>> getActivities(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/history/',
      // activity_type is not optional here, whatever the route suggests.
      // Without it Plane falls through to a branch that sorts unserialised
      // model instances as if they were dicts (`instance["created_at"]` in
      // plane/app/views/issue/activity.py), which throws and returns a 500.
      // The property feed already embeds actor_detail, and comments are
      // fetched separately by CommentService, so this is the branch we want.
      queryParameters: {'activity_type': 'issue-property'},
    );
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    if (list is List) {
      return list.map((e) => Activity.fromJson(e)).toList();
    }
    return [];
  }

  static Future<List<IssueLink>> getLinks(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/issue-links/',
    );
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    if (list is List) {
      return list.map((e) => IssueLink.fromJson(e)).toList();
    }
    return [];
  }

  static Future<IssueLink> addLink(
    String workspaceSlug,
    String projectId,
    String issueId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/issues/$issueId/issue-links/',
      data: data,
    );
    return IssueLink.fromJson(response.data);
  }

  static Future<IssueState> createState(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/states/',
      data: data,
    );
    return IssueState.fromJson(response.data);
  }

  static Future<IssueState> updateState(
    String workspaceSlug,
    String projectId,
    String stateId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.patch(
      '/workspaces/$workspaceSlug/projects/$projectId/states/$stateId/',
      data: data,
    );
    return IssueState.fromJson(response.data);
  }

  static Future<void> deleteState(
    String workspaceSlug,
    String projectId,
    String stateId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/states/$stateId/',
    );
  }

  // --- Reactions (#7) ---

  static String _issueBase(String ws, String pid, String iid) =>
      '/workspaces/$ws/projects/$pid/issues/$iid';

  /// Everyone's reactions on a work item.
  static Future<List<Reaction>> getReactions(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '${_issueBase(workspaceSlug, projectId, issueId)}/reactions/',
    );
    return parseReactions(response.data);
  }

  /// Reads a reaction list off whichever envelope the server used.
  ///
  /// The viewset is a plain `BaseViewSet`, so `list` answers with a bare array,
  /// but the same parser is pointed at the comment reaction route and at
  /// anything a future paginator wraps, hence the `results` branch. Split out
  /// from the request so the shape is testable without a server.
  static List<Reaction> parseReactions(dynamic data) {
    final list = data is Map ? data['results'] : data;
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Reaction.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Adds [reactionCode] to a work item.
  ///
  /// [reactionCode] is Plane's decimal code point string, not an emoji — see
  /// [Reaction.emoji]. Passing a literal emoji here would store it verbatim
  /// and it would never group with the web client's reactions.
  static Future<Reaction> addReaction(
    String workspaceSlug,
    String projectId,
    String issueId,
    String reactionCode,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '${_issueBase(workspaceSlug, projectId, issueId)}/reactions/',
      data: {'reaction': reactionCode},
    );
    return Reaction.fromJson(Map<String, dynamic>.from(response.data));
  }

  /// Removes the current user's [reactionCode] from a work item.
  ///
  /// The route is keyed by the reaction *code*, not by the reaction row's id —
  /// `reactions/<str:reaction_code>/` — and the view scopes the delete to
  /// `actor=request.user`, so this can only ever remove your own. A code point
  /// string is URL-safe as-is, which is the other reason Plane stores emoji
  /// this way.
  static Future<void> removeReaction(
    String workspaceSlug,
    String projectId,
    String issueId,
    String reactionCode,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(
      '${_issueBase(workspaceSlug, projectId, issueId)}/reactions/$reactionCode/',
    );
  }

  // --- Subscription (#8) ---

  /// Whether the current user is subscribed to this work item.
  ///
  /// Prefer `Issue.isSubscribed` off the detail response, which the server
  /// already annotates; this exists for the case where that came back null.
  ///
  /// Note the neighbouring `issue-subscribers/` GET is *not* the way to ask:
  /// despite the name its `list` returns every active member of the project,
  /// not the subscribers, so testing your own id against it would report
  /// everyone as subscribed.
  static Future<bool> getSubscriptionStatus(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '${_issueBase(workspaceSlug, projectId, issueId)}/subscribe/',
    );
    final data = response.data;
    return data is Map && data['subscribed'] == true;
  }

  /// Subscribes the current user.
  ///
  /// Subscribing twice answers 400 with "User already subscribed to the
  /// issue.", which is a no-op dressed as a failure. The desired end state has
  /// been reached either way, so that one case is swallowed rather than thrown
  /// at a user who would only be confused by it.
  static Future<void> subscribe(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    try {
      await dio.post(
        '${_issueBase(workspaceSlug, projectId, issueId)}/subscribe/',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) return;
      rethrow;
    }
  }

  /// Unsubscribes the current user.
  ///
  /// The view fetches the row with `.get()` and does not catch DoesNotExist, so
  /// unsubscribing when not subscribed is a 500, not a 404. Same reasoning as
  /// [subscribe]: the end state is what was wanted, so it is not surfaced.
  static Future<void> unsubscribe(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    try {
      await dio.delete(
        '${_issueBase(workspaceSlug, projectId, issueId)}/subscribe/',
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404 || status == 500) return;
      rethrow;
    }
  }

  // --- Relation writes (#14) ---

  /// Relation kinds this app offers, mapped to their labels.
  ///
  /// Plane's model also carries `start_before` / `finish_before` pairs, which
  /// are date-dependency relations belonging to a Gantt view this app does not
  /// have. They are read back by [parseIssueRelations] if the server sends
  /// them; they are just not offered for creation.
  static const Map<String, String> relationKinds = {
    'blocking': 'Blocking',
    'blocked_by': 'Blocked by',
    'duplicate': 'Duplicate of',
    'relates_to': 'Relates to',
  };

  /// Links work items to [issueId] under [relationType].
  ///
  /// The payload is `{"relation_type": ..., "issues": [...]}` — a list, because
  /// the view bulk-creates. Direction is the server's business: for `blocking`
  /// it stores the row the other way round (the related item is the one doing
  /// the blocking) and maps the kind through `get_actual_relation`, so callers
  /// pass the relation as the *user* sees it from this work item and do not
  /// try to pre-invert it.
  static Future<void> addRelation(
    String workspaceSlug,
    String projectId,
    String issueId,
    String relationType,
    List<String> relatedIssueIds,
  ) async {
    if (relatedIssueIds.isEmpty) return;
    final dio = await ApiClient.getInstance();
    await dio.post(
      '${_issueBase(workspaceSlug, projectId, issueId)}/issue-relation/',
      data: {
        'relation_type': relationType,
        'issues': relatedIssueIds,
      },
    );
  }

  /// Unlinks [relatedIssueId] from [issueId].
  ///
  /// A POST, not a DELETE, and the kind is not part of the request: the view
  /// matches the pair in either direction and deletes whatever relation joins
  /// them.
  static Future<void> removeRelation(
    String workspaceSlug,
    String projectId,
    String issueId,
    String relatedIssueId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.post(
      '${_issueBase(workspaceSlug, projectId, issueId)}/remove-relation/',
      data: {'related_issue': relatedIssueId},
    );
  }

  // --- Archive (#15) ---

  /// State groups the server will accept an archive for.
  ///
  /// `IssueArchiveViewSet.archive` rejects anything else with a 400. Checking
  /// here as well is not duplication for its own sake — it is what lets the UI
  /// explain why the action is unavailable instead of offering it and then
  /// showing an error.
  static const Set<String> archivableStateGroups = {'completed', 'cancelled'};

  /// Archives a work item. Returns the server's `archived_at` timestamp.
  static Future<String?> archiveIssue(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '${_issueBase(workspaceSlug, projectId, issueId)}/archive/',
    );
    final data = response.data;
    return data is Map ? data['archived_at']?.toString() : null;
  }

  /// Restores an archived work item.
  static Future<void> unarchiveIssue(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(
      '${_issueBase(workspaceSlug, projectId, issueId)}/archive/',
    );
  }

  // --- Estimates (#11) ---

  /// The estimate scale configured on this project, or empty if there is none.
  ///
  /// A project points at zero or one `Estimate`; `ProjectEstimatePointEndpoint`
  /// answers 200 with `[]` when `project.estimate_id` is null. An empty list is
  /// therefore the normal, expected answer for most projects and means the
  /// control should not be shown at all rather than shown empty.
  ///
  /// The endpoint is gated to ADMIN and MEMBER, so a guest gets a 403. That is
  /// also "no estimates for you" as far as the UI is concerned, so it is folded
  /// into the empty case by the caller rather than raised.
  static Future<List<EstimatePoint>> getEstimatePoints(
    String workspaceSlug,
    String projectId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/project-estimates/',
    );
    return parseEstimatePoints(response.data);
  }

  /// Parses and orders an estimate scale. Split out for testability.
  static List<EstimatePoint> parseEstimatePoints(dynamic data) {
    final list = data is Map ? data['results'] : data;
    if (list is! List) return [];
    final points = list
        .whereType<Map>()
        .map((e) => EstimatePoint.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    // The endpoint applies no ordering, and an unordered scale reads as
    // nonsense ("8, 1, 3, 2"). `key` is the field the scale is authored in.
    points.sort((a, b) => a.key.compareTo(b.key));
    return points;
  }

  // --- Cycle and module assignment from the work item (#11) ---

  /// Replaces the set of modules a work item belongs to.
  ///
  /// This is the one genuinely issue-side route of the two:
  /// `issues/<issue_id>/modules/` takes both halves of the change at once,
  /// `{"modules": [...], "removed_modules": [...]}`, so a picker can send the
  /// whole new selection in a single call. Sending only `modules` would add
  /// without ever removing, which is why the caller must diff.
  static Future<void> setIssueModules(
    String workspaceSlug,
    String projectId,
    String issueId, {
    required List<String> added,
    required List<String> removed,
  }) async {
    if (added.isEmpty && removed.isEmpty) return;
    final dio = await ApiClient.getInstance();
    await dio.post(
      '${_issueBase(workspaceSlug, projectId, issueId)}/modules/',
      data: {'modules': added, 'removed_modules': removed},
    );
  }

  /// Puts a work item into a cycle.
  ///
  /// There is no issue-side cycle route to match the module one, so this goes
  /// through the cycle's own collection. The server moves an item that is
  /// already in a different cycle rather than rejecting it, so switching
  /// cycles needs only this call — but leaving a cycle for none needs
  /// [removeIssueFromCycle], because there is no "cycle: null" to write.
  static Future<void> addIssueToCycle(
    String workspaceSlug,
    String projectId,
    String cycleId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/cycles/$cycleId/cycle-issues/',
      data: {
        'issues': [issueId]
      },
    );
  }

  /// Takes a work item out of a cycle.
  static Future<void> removeIssueFromCycle(
    String workspaceSlug,
    String projectId,
    String cycleId,
    String issueId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/cycles/$cycleId/cycle-issues/$issueId/',
    );
  }
}
