import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../repositories/project_repository.dart';

class ProjectListState {
  final List<Project> projects;
  final bool loading;
  final String? error;
  final bool loaded;

  const ProjectListState({
    this.projects = const [],
    this.loading = false,
    this.error,
    this.loaded = false,
  });

  ProjectListState copyWith({
    List<Project>? projects,
    bool? loading,
    String? error,
    bool? loaded,
  }) {
    return ProjectListState(
      projects: projects ?? this.projects,
      loading: loading ?? this.loading,
      error: error,
      loaded: loaded ?? this.loaded,
    );
  }
}

class ProjectListNotifier extends Notifier<ProjectListState> {
  @override
  ProjectListState build() {
    return const ProjectListState();
  }

  ProjectRepository get _repository => ref.read(projectRepositoryProvider);

  Future<void> load(String workspaceSlug, {bool forceRefresh = false}) async {
    if (workspaceSlug.isEmpty) return;
    if (!forceRefresh && state.loaded) return;
    state = state.copyWith(loading: !state.loaded);
    try {
      final projects = await _repository.getProjects(
        workspaceSlug,
        forceRefresh: forceRefresh,
      );
      state = ProjectListState(
        projects: projects,
        loading: false,
        loaded: true,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> refresh(String workspaceSlug) async {
    await load(workspaceSlug, forceRefresh: true);
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository();
});

final projectListProvider =
    NotifierProvider<ProjectListNotifier, ProjectListState>(() {
  return ProjectListNotifier();
});
