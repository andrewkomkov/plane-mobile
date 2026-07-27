import '../models/issue.dart';
import '../models/state.dart';
import '../services/issue_service.dart';

class IssueRepository {
  final Map<String, List<Issue>> _issueCache = {};
  final Map<String, Map<String, IssueState>> _stateCache = {};

  Future<List<Issue>> getIssues(
    String workspaceSlug,
    String projectId, {
    bool forceRefresh = false,
    String orderBy = '-created_at',
    int perPage = 50,
  }) async {
    final key = '$workspaceSlug/$projectId';
    if (!forceRefresh && _issueCache.containsKey(key)) {
      return _issueCache[key]!;
    }
    final result = await IssueService.getIssues(
      workspaceSlug,
      projectId,
      orderBy: orderBy,
      perPage: perPage,
    );
    final issues = result['issues'] as List<Issue>;
    _issueCache[key] = issues;
    return issues;
  }

  Future<Issue> getIssue(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    return IssueService.getIssue(workspaceSlug, projectId, issueId);
  }

  Future<Issue> createIssue(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final issue =
        await IssueService.createIssue(workspaceSlug, projectId, data);
    _issueCache.remove('$workspaceSlug/$projectId');
    return issue;
  }

  Future<Issue> updateIssue(
    String workspaceSlug,
    String projectId,
    String issueId,
    Map<String, dynamic> data,
  ) async {
    final issue =
        await IssueService.updateIssue(workspaceSlug, projectId, issueId, data);
    _issueCache.remove('$workspaceSlug/$projectId');
    return issue;
  }

  Future<Map<String, IssueState>> getStates(
    String workspaceSlug,
    String projectId, {
    bool forceRefresh = false,
  }) async {
    final key = '$workspaceSlug/$projectId';
    if (!forceRefresh && _stateCache.containsKey(key)) {
      return _stateCache[key]!;
    }
    final states = await IssueService.getStates(workspaceSlug, projectId);
    final map = {for (var s in states) s.id: s};
    _stateCache[key] = map;
    return map;
  }

  void invalidateIssues(String workspaceSlug, String projectId) {
    _issueCache.remove('$workspaceSlug/$projectId');
  }

  void invalidateAll() {
    _issueCache.clear();
    _stateCache.clear();
  }
}
