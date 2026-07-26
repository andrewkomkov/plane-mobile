import '../config/api_client.dart';
import '../models/draft_issue.dart';
import '../models/issue.dart';

/// Reads and writes draft work items.
///
/// Drafts are **workspace-scoped**, not project-scoped: the routes are
/// `workspaces/{slug}/draft-issues/` with no project segment, and a draft's
/// project is a nullable column on the row. `WorkspaceDraftIssueViewSet.list`
/// also filters on `created_by=request.user`, so this only ever returns the
/// caller's own drafts — there is no way to see anyone else's, and no
/// parameter that would widen it.
///
/// Separate from `IssueService` for the same reason `ArchivedIssueService` is:
/// a different model behind a different view, reached by a path that shares
/// nothing with `issues/`. Nothing on the live work-item path has to grow a
/// "unless it is a draft" branch.
class DraftIssueService {
  /// Renames relation keys to what `DraftIssueCreateSerializer` expects.
  ///
  /// The draft serialiser declares the same four explicit id fields as
  /// `IssueCreateSerializer` — `state_id`, `parent_id`, `label_ids`,
  /// `assignee_ids`. As there, a payload using the plain names is not
  /// rejected; the unknown keys are dropped and the write silently does
  /// nothing. `IssueService` keeps its own copy of this map private, and there
  /// is no shared write path to hang one on, so it is repeated rather than
  /// reached across for.
  static Map<String, dynamic> toWritePayload(Map<String, dynamic> data) {
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

  /// The caller's drafts, newest first.
  ///
  /// [projectId] goes through Plane's shared `issue_filters`, which turns
  /// `?project=` into `project__in`. A project-scoped screen wants that: the
  /// workspace listing would otherwise mix in drafts belonging to projects the
  /// user is looking away from. It also means a draft saved with no project at
  /// all is not listed here — that draft cannot be promoted either
  /// (`create_draft_to_issue` refuses without a project), so a project's work
  /// item list is not the place to show it.
  ///
  /// Ordering is not negotiable: the view hardcodes `order_by("-created_at")`
  /// after applying filters, so an `order_by` parameter would be accepted and
  /// ignored. It is not sent.
  static Future<List<DraftIssue>> getDrafts(
    String workspaceSlug, {
    String? projectId,
    int perPage = 100,
  }) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/draft-issues/',
      queryParameters: {
        'per_page': perPage,
        if (projectId != null) 'project': projectId,
      },
    );
    return parseDrafts(response.data);
  }

  /// Split out so the envelope handling is testable without a server.
  ///
  /// The list runs through the same `self.paginate` as `issues/`, so it answers
  /// `{results: [...], next_cursor: ...}` rather than a bare list.
  static List<DraftIssue> parseDrafts(dynamic data) {
    final raw = data is Map ? data['results'] : data;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => DraftIssue.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Saves a new draft.
  ///
  /// `project_id` rides in the body rather than the path: the route has no
  /// project segment, and the view reads `request.data["project_id"]` into the
  /// serialiser's context. The serialiser itself has no field by that name, so
  /// it is passed through untouched — and everything the serialiser validates
  /// against the project (state, labels, assignees) is validated against
  /// whatever this key says. Omitting it makes those validations run against a
  /// null project and fail.
  static Future<DraftIssue> createDraft(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/draft-issues/',
      data: {...toWritePayload(data), 'project_id': projectId},
    );
    return DraftIssue.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// Edits a draft in place.
  ///
  /// Returns nothing because the server returns nothing: `partial_update`
  /// answers 204 with an empty body on success. A caller that needs the new
  /// state has to re-list.
  ///
  /// Genuinely partial. Omitting `assignee_ids`, `label_ids` or `module_ids`
  /// leaves those relations alone, and omitting `cycle_id` makes the view pass
  /// the sentinel `"not_provided"`, which the serialiser checks for before it
  /// clears the cycle. Sending any of them as an empty list *does* clear them.
  ///
  /// [projectId] is required for the same reason it is on create: it is what
  /// the serialiser validates state, labels and assignees against.
  static Future<void> updateDraft(
    String workspaceSlug,
    String draftId,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.patch(
      '/workspaces/$workspaceSlug/draft-issues/$draftId/',
      data: {...toWritePayload(data), 'project_id': projectId},
    );
  }

  /// Discards a draft. Gone, not recoverable — the row is soft-deleted and
  /// Plane exposes no route that would bring it back.
  static Future<void> deleteDraft(
    String workspaceSlug,
    String draftId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete('/workspaces/$workspaceSlug/draft-issues/$draftId/');
  }

  /// Turns a draft into a real work item and destroys the draft.
  ///
  /// One request, and it is not reversible: the view creates the work item,
  /// moves any file assets over, then calls `draft_issue.delete()`. If the
  /// payload is short of something the draft held, that something is lost with
  /// the draft — see [DraftIssue.toPromoteJson], which is why the whole draft
  /// is re-sent rather than an empty body.
  ///
  /// [overrides] carries edits the user made in the editor without saving them
  /// to the draft first, in the model's own key vocabulary.
  static Future<Issue> promoteDraft(
    String workspaceSlug,
    DraftIssue draft, {
    Map<String, dynamic> overrides = const {},
  }) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/draft-to-issue/${draft.id}/',
      data: toWritePayload({...draft.toPromoteJson(), ...overrides}),
    );
    return Issue.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}
