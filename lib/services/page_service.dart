import '../config/api_client.dart';
import '../models/page.dart';

/// Project pages, served by Plane itself.
///
/// This used to try a FastAPI shim at `/auth/mobile/{slug}/projects/{pid}/pages/`
/// first and fall back to Plane only when that failed. The shim is gone from
/// this path deliberately: it read and wrote Plane's Postgres tables directly,
/// which meant no project-membership check (a valid API key could reach any
/// project's pages in the instance), no page-lock enforcement, no activity or
/// version history, and a hand-rolled `INSERT` that had to be corrected once
/// already when the schema moved pages onto the `project_pages` join table.
///
/// Plane's own endpoints now cover everything the app does. The authoritative
/// routes are the internal ones in `plane/app/urls/page.py`, which the proxy
/// puts within reach: list/create on `pages/`, retrieve/update/delete on
/// `pages/{id}/`, and archive/unarchive on `pages/{id}/archive/`.
///
/// Two shape differences to keep in mind:
///
/// - The list serialiser omits `description_html` (only the detail serialiser
///   carries it), so a page from [getPages] has a null body until [getPage] is
///   called for it.
/// - [getPages] returns archived pages alongside live ones. `PageViewSet`'s
///   queryset filters on project membership, access and `parent__isnull`, but
///   never on `archived_at` — unlike cycles and modules, which have a separate
///   archive endpoint precisely because their own lists exclude archived rows.
///   Callers that want only live pages have to say so.
class PageService {
  static Future<List<PlanePage>> getPages(
    String workspaceSlug,
    String projectId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/pages/',
    );
    final data = response.data;
    if (data is Map && data.containsKey('results')) {
      return (data['results'] as List)
          .map((e) => PlanePage.fromJson(e))
          .toList();
    }
    if (data is List) {
      return data.map((e) => PlanePage.fromJson(e)).toList();
    }
    return [];
  }

  static Future<PlanePage> getPage(
    String workspaceSlug,
    String projectId,
    String pageId,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get(
      '/workspaces/$workspaceSlug/projects/$projectId/pages/$pageId/',
    );
    return PlanePage.fromJson(response.data);
  }

  static Future<PlanePage> createPage(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/pages/',
      data: data,
    );
    return PlanePage.fromJson(response.data);
  }

  /// Rejected with 400 "Page is locked" if the page is locked — the shim had no
  /// such notion and would happily overwrite a locked page.
  static Future<PlanePage> updatePage(
    String workspaceSlug,
    String projectId,
    String pageId,
    Map<String, dynamic> data,
  ) async {
    final dio = await ApiClient.getInstance();
    // PATCH answers with the updated page, so the extra GET the shim needed
    // (it only ever returned `{"ok": true}`) is no longer necessary.
    final response = await dio.patch(
      '/workspaces/$workspaceSlug/projects/$projectId/pages/$pageId/',
      data: data,
    );
    return PlanePage.fromJson(response.data);
  }

  /// Deletes a page, which Plane only allows once it is archived.
  ///
  /// `PageViewSet.destroy` answers 400 "The page should be archived before
  /// deleting" for a live page, so this is the second half of a two-step
  /// flow, not an alternative to [archivePage].
  static Future<void> deletePage(
    String workspaceSlug,
    String projectId,
    String pageId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/pages/$pageId/',
    );
  }

  /// Archives a page and every page nested under it.
  ///
  /// The route is registered as `{"post": "archive", "delete": "unarchive"}`,
  /// so one path carries both directions. Rejected with 400 for a member who
  /// neither owns the page nor administers the project.
  ///
  /// The cascade is not incidental: `unarchive_archive_page_and_descendants`
  /// walks the parent chain in raw SQL, so archiving a page with children
  /// removes all of them from the live list at once.
  static Future<void> archivePage(
    String workspaceSlug,
    String projectId,
    String pageId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/pages/$pageId/archive/',
    );
  }

  /// Restores an archived page and its descendants.
  ///
  /// If the page's parent is still archived the server detaches the page from
  /// it rather than refusing, so a restored page can come back at the top
  /// level instead of where it was nested.
  static Future<void> unarchivePage(
    String workspaceSlug,
    String projectId,
    String pageId,
  ) async {
    final dio = await ApiClient.getInstance();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/pages/$pageId/archive/',
    );
  }
}
