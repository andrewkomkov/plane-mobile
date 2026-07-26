import 'package:flutter/material.dart';

import '../../models/project.dart';
import '../../models/workspace_rollup.dart';
import '../../widgets/section_header.dart';

/// A workspace rollup laid out under one heading per project.
///
/// Cycles and modules are the two rollups that arrive without any grouping and
/// mean nothing ungrouped: "Sprint 12" is three different cycles in a workspace
/// with three teams. A per-project heading answers that once for a run of rows
/// rather than repeating the project on every one.
///
/// It is also where the membership filter these two endpoints are missing gets
/// applied. `WorkspaceCyclesEndpoint` and `WorkspaceModulesEndpoint` select on
/// `workspace__slug` alone behind `WorkspaceViewerPermission`, which asks only
/// that the caller be in the workspace — so they return cycles and modules out
/// of projects the caller is not a member of, unlike every other rollup here.
/// [projects] is the caller's own project list, which the server does scope, so
/// anything whose project is not in it is dropped: it could not be opened
/// anyway (the detail screens are project-scoped and would 403) and it could
/// not be named, which is the other half of what makes a row readable out of
/// context.
class ProjectGroupedList<T> extends StatelessWidget {
  final List<ProjectScoped<T>> items;

  /// Projects by id, from `workspaces/{slug}/projects/`.
  final Map<String, Project> projects;

  final Widget Function(BuildContext context, Project project, T item)
      rowBuilder;

  final Widget emptyState;

  const ProjectGroupedList({
    super.key,
    required this.items,
    required this.projects,
    required this.rowBuilder,
    required this.emptyState,
  });

  /// Rows the caller may actually see, keyed by project and ordered by project
  /// name. Static and pure so the filtering is testable on its own.
  static List<MapEntry<Project, List<T>>> group<T>(
    List<ProjectScoped<T>> items,
    Map<String, Project> projects,
  ) {
    final byProject = <String, List<T>>{};
    for (final entry in items) {
      final id = entry.projectId;
      if (id == null || !projects.containsKey(id)) continue;
      byProject.putIfAbsent(id, () => []).add(entry.item);
    }
    final groups = byProject.entries
        .map((e) => MapEntry(projects[e.key]!, e.value))
        .toList()
      ..sort((a, b) =>
          a.key.name.toLowerCase().compareTo(b.key.name.toLowerCase()));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = group<T>(items, projects);
    if (groups.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(child: emptyState),
      ]);
    }

    // One header plus its rows per group, flattened into a single builder so
    // the whole thing stays lazy on a workspace with a lot of projects.
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: groups.fold<int>(0, (sum, g) => sum + 1 + g.value.length),
      itemBuilder: (ctx, index) {
        var cursor = 0;
        for (final group in groups) {
          if (index == cursor) {
            return SectionHeader(
              label: group.key.name,
              count: group.value.length,
            );
          }
          cursor++;
          final offset = index - cursor;
          if (offset < group.value.length) {
            return rowBuilder(ctx, group.key, group.value[offset]);
          }
          cursor += group.value.length;
        }
        return const SizedBox.shrink();
      },
    );
  }
}
