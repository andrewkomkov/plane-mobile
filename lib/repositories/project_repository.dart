import '../models/project.dart';
import '../services/project_service.dart';

class ProjectRepository {
  final Map<String, List<Project>> _cache = {};

  Future<List<Project>> getProjects(
    String workspaceSlug, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache.containsKey(workspaceSlug)) {
      return _cache[workspaceSlug]!;
    }
    final projects = await ProjectService.getProjects(workspaceSlug);
    _cache[workspaceSlug] = projects;
    return projects;
  }

  void invalidate(String workspaceSlug) {
    _cache.remove(workspaceSlug);
  }

  void invalidateAll() {
    _cache.clear();
  }
}
