import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/issue.dart';
import '../models/state.dart';
import '../repositories/issue_repository.dart';

class IssueListState {
  final List<Issue> issues;
  final Map<String, IssueState> states;
  final bool loading;
  final String? error;
  final bool loaded;

  const IssueListState({
    this.issues = const [],
    this.states = const {},
    this.loading = false,
    this.error,
    this.loaded = false,
  });

  IssueListState copyWith({
    List<Issue>? issues,
    Map<String, IssueState>? states,
    bool? loading,
    String? error,
    bool? loaded,
  }) {
    return IssueListState(
      issues: issues ?? this.issues,
      states: states ?? this.states,
      loading: loading ?? this.loading,
      error: error,
      loaded: loaded ?? this.loaded,
    );
  }
}

class IssueListNotifier extends Notifier<IssueListState> {
  @override
  IssueListState build() {
    return const IssueListState();
  }

  IssueRepository get _repository => ref.read(issueRepositoryProvider);

  Future<void> load(
    String workspaceSlug,
    String projectId, {
    bool forceRefresh = false,
  }) async {
    if (workspaceSlug.isEmpty || projectId.isEmpty) return;
    if (!forceRefresh && state.loaded) return;
    state = state.copyWith(loading: !state.loaded);
    try {
      final states = await _repository.getStates(
        workspaceSlug,
        projectId,
        forceRefresh: forceRefresh,
      );
      final issues = await _repository.getIssues(
        workspaceSlug,
        projectId,
        forceRefresh: forceRefresh,
      );
      state = IssueListState(
        issues: issues,
        states: states,
        loading: false,
        loaded: true,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> refresh(String workspaceSlug, String projectId) async {
    await load(workspaceSlug, projectId, forceRefresh: true);
  }

  void invalidate() {
    state = const IssueListState();
  }
}

final issueRepositoryProvider = Provider<IssueRepository>((ref) {
  return IssueRepository();
});

final issueListProvider =
    NotifierProvider<IssueListNotifier, IssueListState>(() {
  return IssueListNotifier();
});
