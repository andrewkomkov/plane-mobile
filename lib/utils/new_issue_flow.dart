import 'package:flutter/material.dart';

import '../models/project.dart';
import '../providers/data_providers.dart';
import '../screens/issues/issue_create_screen.dart';

/// Starts issue creation from a workspace-level surface.
///
/// Nothing above a project screen knows which project to file into, so this
/// asks — except when the answer is forced. Callers that already have a project
/// should push [IssueCreateScreen] directly.
///
/// [onReturn] runs after the create screen pops, so a list behind it can
/// refresh.
Future<void> startNewIssue(
  BuildContext context, {
  required DataCache cache,
  required String workspaceSlug,
  VoidCallback? onReturn,
}) async {
  var projects = cache.getProjects(workspaceSlug) ?? [];
  if (projects.isEmpty) {
    // A workspace surface may be reached before the project list has loaded,
    // in which case an empty cache means "not yet", not "none".
    await cache.loadProjects(workspaceSlug);
    projects = cache.getProjects(workspaceSlug) ?? [];
  }

  if (!context.mounted) return;
  if (projects.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No projects available')),
    );
    return;
  }

  final project = projects.length == 1
      ? projects.first
      : await _pickProject(context, projects);
  if (project == null || !context.mounted) return;

  await cache.loadProjectCoreData(workspaceSlug, project.id);
  final states = cache.getStates(workspaceSlug, project.id) ?? {};
  if (!context.mounted) return;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => IssueCreateScreen(
        workspaceSlug: workspaceSlug,
        projectId: project.id,
        states: states,
      ),
    ),
  );
  onReturn?.call();
}

Future<Project?> _pickProject(
  BuildContext context,
  List<Project> projects,
) {
  return showModalBottomSheet<Project>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select project',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          ...projects.map((p) => ListTile(
                leading: const Icon(Icons.folder_outlined, size: 20),
                title: Text(
                  '${p.identifier} - ${p.name}',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                onTap: () => Navigator.pop(ctx, p),
              )),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
