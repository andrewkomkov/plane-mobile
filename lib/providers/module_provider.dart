import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/module.dart';
import '../services/module_service.dart';

class ModuleListState {
  final List<Module> modules;
  final bool loading;
  final String? error;
  final bool loaded;

  const ModuleListState({
    this.modules = const [],
    this.loading = false,
    this.error,
    this.loaded = false,
  });

  ModuleListState copyWith({
    List<Module>? modules,
    bool? loading,
    String? error,
    bool? loaded,
  }) {
    return ModuleListState(
      modules: modules ?? this.modules,
      loading: loading ?? this.loading,
      error: error,
      loaded: loaded ?? this.loaded,
    );
  }
}

class ModuleListNotifier extends Notifier<ModuleListState> {
  @override
  ModuleListState build() {
    return const ModuleListState();
  }

  Future<void> load(
    String workspaceSlug,
    String projectId, {
    bool forceRefresh = false,
  }) async {
    if (workspaceSlug.isEmpty || projectId.isEmpty) return;
    if (!forceRefresh && state.loaded) return;
    state = state.copyWith(loading: !state.loaded);
    try {
      final modules = await ModuleService.getModules(workspaceSlug, projectId);
      state = ModuleListState(
        modules: modules,
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
    state = const ModuleListState();
  }
}

final moduleListProvider =
    NotifierProvider<ModuleListNotifier, ModuleListState>(() {
  return ModuleListNotifier();
});
