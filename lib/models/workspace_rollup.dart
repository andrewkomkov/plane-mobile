import 'issue.dart';

/// Shapes returned by Plane's workspace-level rollup endpoints.
///
/// These are the cross-project counterparts of the project lists the app is
/// otherwise built from: `workspaces/{slug}/issues/`, `.../views/`,
/// `.../cycles/` and `.../modules/`. They are not simply the project routes
/// with the project segment dropped — the querysets, the serialisers and the
/// pagination all differ — so the differences live here rather than being
/// guessed at each call site.

/// An entity from a workspace rollup, paired with the project it came from.
///
/// `WorkspaceCyclesEndpoint` and `WorkspaceModulesEndpoint` serialise with the
/// same `CycleSerializer` / `ModuleSerializer` the project lists use, so every
/// row carries `project_id`. `Cycle` and `Module` have no field for it, and
/// giving them one would put a value on every cycle and module in the app that
/// only these two endpoints ever populate. Pairing it on the outside keeps the
/// cost where it is paid.
///
/// The project id is not decoration here. A cycle listed outside its project
/// cannot be opened without one — the detail screen is project-scoped — and a
/// user cannot tell two identically named cycles apart without it.
class ProjectScoped<T> {
  final T item;

  /// Null only if the server omitted `project_id`, which neither serialiser
  /// does. A row whose project cannot be named is not shown.
  final String? projectId;

  const ProjectScoped({required this.item, this.projectId});
}

/// A saved view that spans the workspace rather than one project.
///
/// Deliberately not `PlaneView`. That model reads `query_data`, a key
/// `IssueView` does not have — the model's fields are `filters` (what the user
/// picked) and `query` (the compiled ORM kwargs the server derives from it on
/// save). So `PlaneView.queryData` is empty for every view the server has ever
/// sent, and a screen that filters on it filters on nothing.
///
/// This reads `filters`, which is the half a client can act on: its keys are
/// exactly the ones `plane.utils.issue_filters.issue_filters` understands as
/// query parameters, so a view's filters can be handed back to
/// `workspaces/{slug}/issues/` and applied by the server rather than
/// reimplemented here.
class WorkspaceView {
  final String id;
  final String name;
  final String? description;

  /// What the view selects, in the vocabulary `issue_filters` reads:
  /// `state`, `priority`, `assignees`, `labels`, `project`, `cycle`, `module`,
  /// `created_by`, `target_date` and friends, each a list.
  final Map<String, dynamic> filters;

  /// 0 private, 1 public. The list endpoint only ever returns views that are
  /// public or owned by the caller, so this is display-only.
  final int access;

  /// A locked view refuses PATCH server-side, with a 400.
  final bool isLocked;

  final String? ownedBy;
  final DateTime updatedAt;

  const WorkspaceView({
    required this.id,
    required this.name,
    this.description,
    required this.filters,
    required this.access,
    required this.isLocked,
    this.ownedBy,
    required this.updatedAt,
  });

  bool get isPrivate => access == 0;

  factory WorkspaceView.fromJson(Map<String, dynamic> json) => WorkspaceView(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        // `description` is a non-null TextField server-side, so an empty view
        // description arrives as '' rather than absent. Rendering an empty
        // subtitle line is worse than rendering none.
        description: (json['description']?.toString().isNotEmpty ?? false)
            ? json['description'].toString()
            : null,
        filters: json['filters'] is Map
            ? Map<String, dynamic>.from(json['filters'] as Map)
            : const {},
        access: json['access'] is int
            ? json['access'] as int
            : int.tryParse(json['access']?.toString() ?? '') ?? 1,
        isLocked: json['is_locked'] == true,
        // `owned_by` is a bare user id: IssueViewSerializer is
        // fields = "__all__" on the model, with no nested serialiser.
        ownedBy: json['owned_by']?.toString(),
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// One page of `workspaces/{slug}/issues/`.
///
/// This is the rollup that does not behave like its project-level sibling:
/// `WorkspaceViewIssuesViewSet.list` ends in `self.paginate`, so it answers
/// with an envelope, while `workspaces/{slug}/cycles/`, `.../modules/` and
/// `.../views/` all answer with a bare list.
class WorkspaceIssuePage {
  final List<Issue> issues;

  /// Feed straight back as the `cursor` parameter, together with the same
  /// `per_page` — the paginator takes the limit from `per_page`, not from the
  /// cursor, and mixing the two shifts the offset.
  final String? nextCursor;

  /// The server's own answer to "is there another page", rather than an
  /// inference from a short page.
  final bool hasMore;

  /// Total across every page, which is what a count in the header should show.
  final int totalCount;

  const WorkspaceIssuePage({
    required this.issues,
    this.nextCursor,
    required this.hasMore,
    required this.totalCount,
  });

  static const WorkspaceIssuePage empty = WorkspaceIssuePage(
    issues: [],
    hasMore: false,
    totalCount: 0,
  );
}
