import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cycle.dart';
import '../services/cycle_service.dart';

class CycleListState {
  final List<Cycle> cycles;
  final bool loading;
  final String? error;
  final bool loaded;

  const CycleListState({
    this.cycles = const [],
    this.loading = false,
    this.error,
    this.loaded = false,
  });

  CycleListState copyWith({
    List<Cycle>? cycles,
    bool? loading,
    String? error,
    bool? loaded,
  }) {
    return CycleListState(
      cycles: cycles ?? this.cycles,
      loading: loading ?? this.loading,
      error: error,
      loaded: loaded ?? this.loaded,
    );
  }
}

class CycleListNotifier extends Notifier<CycleListState> {
  @override
  CycleListState build() {
    return const CycleListState();
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
      final cycles = await CycleService.getCycles(workspaceSlug, projectId);
      state = CycleListState(
        cycles: cycles,
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
    state = const CycleListState();
  }
}

final cycleListProvider =
    NotifierProvider<CycleListNotifier, CycleListState>(() {
  return CycleListNotifier();
});
