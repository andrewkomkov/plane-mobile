import '../config/api_client.dart';
import '../models/cycle.dart';
import '../models/issue.dart';
import '../models/label.dart';
import '../models/module.dart';
import '../models/state.dart';
import '../models/workspace_rollup.dart';

/// Plane's cross-project reads: the same entities the app already shows inside
/// a project, listed for the whole workspace at once.
///
/// Routes are the internal API's, declared in `plane/app/urls/views.py` and
/// `plane/app/urls/workspace.py` and reached through the proxy in [ApiClient].
///
/// Kept apart from `IssueService`, `CycleService`, `ModuleService` and
/// `ViewService` on purpose. Those are project-scoped end to end — every method
/// takes a project id and every route has a `projects/{id}/` segment — and
/// these routes have neither. They also do not agree with their project-level
/// siblings on shape:
///
/// - `workspaces/{slug}/issues/` paginates; the others send a bare list.
/// - `workspaces/{slug}/issues/` serialises with `ViewIssueListSerializer`,
///   which is a hand-written `to_representation` and not the project list's
///   `issue_on_results`. It carries no description and no project detail —
///   only `project_id`.
/// - `workspaces/{slug}/cycles/` and `.../modules/` do not filter by project
///   membership at all, unlike everything else here. See [parseCycles].
class WorkspaceRollupService {
  /// One page of every work item in the workspace.
  ///
  /// `WorkspaceViewIssuesViewSet` applies a project-membership filter of its
  /// own (`_get_project_permission_filters`), including the guest rule that
  /// hides other people's work items in projects with `guest_view_all_features`
  /// off, so the result is already scoped to what the caller may see.
  ///
  /// [filters] are passed through as query parameters and applied server-side.
  /// The keys are the ones `issue_filters` understands, which is exactly the
  /// vocabulary a saved view stores — see [filtersToQuery].
  static Future<WorkspaceIssuePage> getIssues(
    String workspaceSlug, {
    String? cursor,
    int perPage = 50,
    String orderBy = '-created_at',
    Map<String, dynamic> filters = const {},
  }) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/issues/',
      queryParameters: {
        'per_page': perPage,
        'order_by': orderBy,
        // Omitted on the first page: the paginator defaults it to
        // "{per_page}:0:0", which is the same thing said twice.
        if (cursor != null) 'cursor': cursor,
        ...filtersToQuery(filters),
      },
    );
    return parseIssuePage(response.data);
  }

  /// Split out so the envelope handling is testable without a server.
  static WorkspaceIssuePage parseIssuePage(dynamic data) {
    if (data is! Map) {
      // A bare list is not what this route sends, but reading one costs
      // nothing and beats showing an empty workspace if it ever does.
      if (data is List) {
        final issues = _issuesFrom(data);
        return WorkspaceIssuePage(
          issues: issues,
          hasMore: false,
          totalCount: issues.length,
        );
      }
      return WorkspaceIssuePage.empty;
    }

    final issues = _issuesFrom(data['results']);
    // `next_cursor` is always a string — the view stringifies the Cursor
    // unconditionally — so "is there more" has to come from the flag beside
    // it, not from the cursor being absent.
    final hasMore = data['next_page_results'] == true;
    final cursor = data['next_cursor']?.toString();
    return WorkspaceIssuePage(
      issues: issues,
      nextCursor:
          hasMore && cursor != null && cursor.isNotEmpty ? cursor : null,
      hasMore: hasMore,
      totalCount: _asInt(data['total_results']) ?? issues.length,
    );
  }

  /// Turns a saved view's `filters` map into query parameters.
  ///
  /// `issue_filters` reads each supported key with `.split(",")`, so a list
  /// becomes one comma-joined parameter. Empty lists are dropped rather than
  /// sent empty: several of the server's filter functions branch on the raw
  /// string before validating it, and an empty one is a filter that means
  /// nothing but still costs a round of parsing.
  ///
  /// `filters` itself is never forwarded even if a view somehow stores a key by
  /// that name. It is `ComplexFilterBackend.filter_param`, and the backend
  /// tries to JSON-decode it before the legacy filters run — a non-JSON value
  /// there is a 400 for the whole request.
  static Map<String, String> filtersToQuery(Map<String, dynamic> filters) {
    final out = <String, String>{};
    filters.forEach((key, value) {
      if (key == 'filters') return;
      if (value is List) {
        final values =
            value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty);
        if (values.isNotEmpty) out[key] = values.join(',');
      } else if (value != null && value.toString().isNotEmpty) {
        out[key] = value.toString();
      }
    });
    return out;
  }

  /// Saved views that belong to the workspace rather than to a project.
  ///
  /// `WorkspaceViewViewSet.list` returns a bare list — no envelope — filtered
  /// to `project__isnull=True` and to views that are public or the caller's
  /// own. A workspace guest sees only their own, which the server does rather
  /// than the client.
  static Future<List<WorkspaceView>> getViews(String workspaceSlug) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/workspaces/$workspaceSlug/views/');
    return parseViews(response.data);
  }

  static List<WorkspaceView> parseViews(dynamic data) {
    final raw = data is Map ? data['results'] : data;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => WorkspaceView.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Delete a workspace view.
  ///
  /// The server allows this to the workspace admin or to the view's owner and
  /// answers 400 — not 403 — to anyone else, so the caller has to surface the
  /// failure rather than assume permission was checked before the tap.
  static Future<void> deleteView(String workspaceSlug, String viewId) async {
    final dio = await ApiClient.getInstance();
    await dio.delete('/workspaces/$workspaceSlug/views/$viewId/');
  }

  /// Every live cycle in the workspace, each with the project it belongs to.
  static Future<List<ProjectScoped<Cycle>>> getCycles(
      String workspaceSlug) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/workspaces/$workspaceSlug/cycles/');
    return parseCycles(response.data);
  }

  /// Reads the cycle rollup.
  ///
  /// Archived cycles are already excluded server-side. Two things this
  /// endpoint's serialiser does *not* send, both of which the project-level
  /// list does: `created_at` and `archived_at`. `CycleSerializer.Meta.fields`
  /// omits them, so `Cycle.createdAt` falls back to now and `isArchived` reads
  /// false — true here by luck rather than by data. Nothing on this screen
  /// sorts by creation, which is what keeps that harmless.
  ///
  /// Membership is *not* filtered by the server: the queryset is
  /// `Cycle.objects.filter(workspace__slug=slug)` behind
  /// `WorkspaceViewerPermission`, which only asks for workspace membership. A
  /// workspace member therefore gets cycles out of projects they are not in.
  /// Filtering that is the caller's job — see the screen, which drops any row
  /// whose project is not in the caller's project list.
  static List<ProjectScoped<Cycle>> parseCycles(dynamic data) {
    final raw = data is Map ? data['results'] : data;
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) {
      final json = Map<String, dynamic>.from(e);
      return ProjectScoped<Cycle>(
        item: Cycle.fromJson(json),
        projectId:
            json['project_id']?.toString() ?? json['project']?.toString(),
      );
    }).toList();
  }

  /// Every live module in the workspace, each with the project it belongs to.
  static Future<List<ProjectScoped<Module>>> getModules(
      String workspaceSlug) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/workspaces/$workspaceSlug/modules/');
    return parseModules(response.data);
  }

  /// Reads the module rollup. Carries the same missing membership filter as
  /// [parseCycles], and the same remedy.
  static List<ProjectScoped<Module>> parseModules(dynamic data) {
    final raw = data is Map ? data['results'] : data;
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) {
      final json = Map<String, dynamic>.from(e);
      return ProjectScoped<Module>(
        item: Module.fromJson(json),
        projectId:
            json['project_id']?.toString() ?? json['project']?.toString(),
      );
    }).toList();
  }

  /// Every state in every project the caller belongs to.
  ///
  /// A work item listed at workspace level names its state by id, and the ids
  /// come from all over the workspace, so the project-level `states/` call the
  /// rest of the app makes cannot resolve them. This one is joined on
  /// `project_projectmember` server-side, so it is already membership-scoped.
  ///
  /// Names are not unique across projects — every project ships its own
  /// "Backlog" — so this is a lookup by id and nothing else.
  static Future<Map<String, IssueState>> getStates(String workspaceSlug) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/workspaces/$workspaceSlug/states/');
    return parseStates(response.data);
  }

  static Map<String, IssueState> parseStates(dynamic data) {
    final raw = data is Map ? data['results'] : data;
    if (raw is! List) return const {};
    final states = raw
        .whereType<Map>()
        .map((e) => IssueState.fromJson(Map<String, dynamic>.from(e)));
    return {for (final s in states) s.id: s};
  }

  /// Every label in every project the caller belongs to. Membership-scoped
  /// server-side, like [getStates], and cached there for two hours.
  static Future<List<Label>> getLabels(String workspaceSlug) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/workspaces/$workspaceSlug/labels/');
    return parseLabels(response.data);
  }

  static List<Label> parseLabels(dynamic data) {
    final raw = data is Map ? data['results'] : data;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Label.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static List<Issue> _issuesFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Issue.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
