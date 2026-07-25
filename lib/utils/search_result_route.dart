import 'package:flutter/material.dart';

import '../models/cycle.dart';
import '../models/module.dart';
import '../models/project.dart';
import '../models/state.dart';
import '../screens/cycles/cycle_detail_screen.dart';
import '../screens/issues/issue_detail_screen.dart';
import '../screens/modules/module_detail_screen.dart';
import '../screens/pages/page_detail_screen.dart';
import '../screens/project/project_screen.dart';
import '../services/issue_service.dart';
import '../services/project_service.dart';

/// Opens a workspace search hit.
///
/// Search is the one place where a result arrives as a bare map rather than a
/// model: [SearchService] has two backends with slightly different field names,
/// and neither returns enough to build a full model. So the read helpers below
/// accept both spellings, and each branch fills the gaps from the API before
/// pushing a screen that expects a complete object.
///
/// Returns false when the hit carries too little to route on — an issue with no
/// project, say — so the caller can leave the tile inert rather than push a
/// screen that would fail to load.
Future<bool> openSearchResult(
  BuildContext context, {
  required String workspaceSlug,
  required String type,
  required Map<String, dynamic> item,
}) async {
  final id = _str(item, ['id']);
  if (id.isEmpty) return false;

  switch (type) {
    case 'issues':
      return _openIssue(context, workspaceSlug, item, id);
    case 'projects':
      return _openProject(context, workspaceSlug, item, id);
    case 'pages':
      return _openPage(context, workspaceSlug, item, id);
    case 'cycles':
      return _openCycle(context, workspaceSlug, item, id);
    case 'modules':
      return _openModule(context, workspaceSlug, item, id);
    default:
      return false;
  }
}

/// The mobile proxy returns `project_identifier`; Plane's own search API
/// returns the Django-ORM spelling `project__identifier`. Read both.
String _str(Map<String, dynamic> item, List<String> keys) {
  for (final key in keys) {
    final value = item[key];
    if (value != null && value.toString().isNotEmpty) return value.toString();
  }
  return '';
}

String searchResultProjectId(Map<String, dynamic> item) =>
    _str(item, ['project_id', 'project__id', 'project']);

String searchResultProjectIdentifier(Map<String, dynamic> item) =>
    _str(item, ['project_identifier', 'project__identifier', 'identifier']);

Future<bool> _openIssue(
  BuildContext context,
  String workspaceSlug,
  Map<String, dynamic> item,
  String id,
) async {
  final projectId = searchResultProjectId(item);
  if (projectId.isEmpty) return false;

  // The detail screen colours its state chip from this map. Failing to load it
  // is not a reason to refuse the navigation — the screen degrades to an
  // uncoloured chip and still shows the issue.
  var states = <String, IssueState>{};
  try {
    final list = await IssueService.getStates(workspaceSlug, projectId);
    states = {for (final s in list) s.id: s};
  } catch (_) {}

  if (!context.mounted) return false;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => IssueDetailScreen(
        workspaceSlug: workspaceSlug,
        projectId: projectId,
        issueId: id,
        projectIdentifier: searchResultProjectIdentifier(item),
        states: states,
      ),
    ),
  );
  return true;
}

Future<bool> _openProject(
  BuildContext context,
  String workspaceSlug,
  Map<String, dynamic> item,
  String id,
) async {
  // A search hit carries only id, name and identifier, and the project screen
  // shows counts, so fetch the real thing. The hit is the fallback rather than
  // the source: an offline push showing zeroed counts beats no push at all.
  Project project;
  try {
    project = await ProjectService.getProject(workspaceSlug, id);
  } catch (_) {
    project = Project.fromJson(item);
  }

  if (!context.mounted) return false;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProjectScreen(
        workspaceSlug: workspaceSlug,
        project: project,
      ),
    ),
  );
  return true;
}

Future<bool> _openPage(
  BuildContext context,
  String workspaceSlug,
  Map<String, dynamic> item,
  String id,
) async {
  final projectId = searchResultProjectId(item);
  if (projectId.isEmpty) return false;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PageDetailScreen(
        workspaceSlug: workspaceSlug,
        projectId: projectId,
        pageId: id,
        pageName: _str(item, ['name', 'title']),
      ),
    ),
  );
  return true;
}

Future<bool> _openCycle(
  BuildContext context,
  String workspaceSlug,
  Map<String, dynamic> item,
  String id,
) async {
  final projectId = searchResultProjectId(item);
  if (projectId.isEmpty) return false;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CycleDetailScreen(
        workspaceSlug: workspaceSlug,
        projectId: projectId,
        cycle: Cycle.fromJson(item),
      ),
    ),
  );
  return true;
}

Future<bool> _openModule(
  BuildContext context,
  String workspaceSlug,
  Map<String, dynamic> item,
  String id,
) async {
  final projectId = searchResultProjectId(item);
  if (projectId.isEmpty) return false;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ModuleDetailScreen(
        workspaceSlug: workspaceSlug,
        projectId: projectId,
        module: Module.fromJson(item),
      ),
    ),
  );
  return true;
}
