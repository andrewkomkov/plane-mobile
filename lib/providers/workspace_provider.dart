import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/secure_storage.dart';

class WorkspaceState {
  final String slug;
  final bool loading;

  const WorkspaceState({this.slug = '', this.loading = true});

  WorkspaceState copyWith({String? slug, bool? loading}) {
    return WorkspaceState(
      slug: slug ?? this.slug,
      loading: loading ?? this.loading,
    );
  }
}

class WorkspaceNotifier extends Notifier<WorkspaceState> {
  @override
  WorkspaceState build() {
    _load();
    return const WorkspaceState();
  }

  Future<void> _load() async {
    final slug = await SecureStorage.getWorkspaceSlug() ?? '';
    state = WorkspaceState(slug: slug, loading: false);
  }

  Future<void> refresh() async {
    final slug = await SecureStorage.getWorkspaceSlug() ?? '';
    state = WorkspaceState(slug: slug, loading: false);
  }

  void setSlug(String slug) {
    state = WorkspaceState(slug: slug, loading: false);
  }
}

final workspaceProvider =
    NotifierProvider<WorkspaceNotifier, WorkspaceState>(() {
  return WorkspaceNotifier();
});
