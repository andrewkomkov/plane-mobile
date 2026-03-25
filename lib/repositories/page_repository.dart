import '../models/page.dart';
import '../services/page_service.dart';

class PageRepository {
  final Map<String, List<PlanePage>> _cache = {};

  Future<List<PlanePage>> getPages(
    String workspaceSlug,
    String projectId, {
    bool forceRefresh = false,
  }) async {
    final key = '$workspaceSlug/$projectId';
    if (!forceRefresh && _cache.containsKey(key)) {
      return _cache[key]!;
    }
    final pages = await PageService.getPages(workspaceSlug, projectId);
    _cache[key] = pages;
    return pages;
  }

  Future<PlanePage> getPage(
    String workspaceSlug,
    String projectId,
    String pageId,
  ) async {
    return PageService.getPage(workspaceSlug, projectId, pageId);
  }

  Future<PlanePage> createPage(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final page = await PageService.createPage(workspaceSlug, projectId, data);
    _cache.remove('$workspaceSlug/$projectId');
    return page;
  }

  Future<PlanePage> updatePage(
    String workspaceSlug,
    String projectId,
    String pageId,
    Map<String, dynamic> data,
  ) async {
    final page = await PageService.updatePage(workspaceSlug, projectId, pageId, data);
    _cache.remove('$workspaceSlug/$projectId');
    return page;
  }

  void invalidate(String workspaceSlug, String projectId) {
    _cache.remove('$workspaceSlug/$projectId');
  }

  void invalidateAll() {
    _cache.clear();
  }
}
