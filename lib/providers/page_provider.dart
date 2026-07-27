import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/page.dart';
import '../repositories/page_repository.dart';

class PageListState {
  final List<PlanePage> pages;
  final bool loading;
  final String? error;
  final bool loaded;

  const PageListState({
    this.pages = const [],
    this.loading = false,
    this.error,
    this.loaded = false,
  });

  PageListState copyWith({
    List<PlanePage>? pages,
    bool? loading,
    String? error,
    bool? loaded,
  }) {
    return PageListState(
      pages: pages ?? this.pages,
      loading: loading ?? this.loading,
      error: error,
      loaded: loaded ?? this.loaded,
    );
  }
}

class PageListNotifier extends Notifier<PageListState> {
  @override
  PageListState build() {
    return const PageListState();
  }

  PageRepository get _repository => ref.read(pageRepositoryProvider);

  Future<void> load(
    String workspaceSlug,
    String projectId, {
    bool forceRefresh = false,
  }) async {
    if (workspaceSlug.isEmpty || projectId.isEmpty) return;
    if (!forceRefresh && state.loaded) return;
    state = state.copyWith(loading: !state.loaded);
    try {
      final pages = await _repository.getPages(
        workspaceSlug,
        projectId,
        forceRefresh: forceRefresh,
      );
      state = PageListState(
        pages: pages,
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
    state = const PageListState();
  }
}

final pageRepositoryProvider = Provider<PageRepository>((ref) {
  return PageRepository();
});

final pageListProvider = NotifierProvider<PageListNotifier, PageListState>(() {
  return PageListNotifier();
});
