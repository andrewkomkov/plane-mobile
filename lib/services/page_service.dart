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
/// Plane's own endpoints now cover everything the app does. This fork carries a
/// local commit adding pages to the token API, so `plane/api/urls/page.py`
/// routes list/create on `pages/` and retrieve/update/delete on `pages/{id}/`.
/// That matters because the app always authenticates with an API token and is
/// therefore always based at `{host}/api/v1` — the reason the shim existed in
/// the first place (no pages on v1) is gone.
///
/// One shape difference to keep in mind: the list serialiser omits
/// `description_html` (only the detail serialiser carries it), so a page from
/// [getPages] has a null body until [getPage] is called for it.
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
}
