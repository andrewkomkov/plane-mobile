import '../config/api_client.dart';

/// Workspace-wide search.
///
/// This goes through the proxy to Plane's own `workspaces/{slug}/search/`, so
/// `GlobalSearchEndpoint` decides what comes back: every entity it searches is
/// filtered on `project_projectmember__member=request.user`, so a caller only
/// ever sees projects they belong to. The mobile shim this replaced selected
/// rows by workspace slug alone, which meant any token in the instance could
/// search any workspace.
class SearchService {
  /// Plane names its entities in the singular and nests them under `results`;
  /// the search screen and the command palette group by the plural key.
  static const Map<String, String> _sections = {
    'issue': 'issues',
    'project': 'projects',
    'page': 'pages',
    'cycle': 'cycles',
    'module': 'modules',
  };

  static Future<Map<String, List<Map<String, dynamic>>>> searchAll(
      String workspaceSlug, String query) async {
    try {
      final dio = await ApiClient.getInstance();
      final response = await dio.get(
        '/workspaces/$workspaceSlug/search/',
        queryParameters: {
          'search': query,
          'entities': _sections.keys.join(','),
          // Left at its default the endpoint narrows every entity to
          // `project_id` when that parameter is present. We never send one and
          // always want the whole workspace, so say so explicitly.
          'workspace_search': 'true',
        },
      );
      final raw = response.data is Map ? response.data['results'] : null;
      if (raw is! Map) return {};

      final results = <String, List<Map<String, dynamic>>>{};
      _sections.forEach((entity, section) {
        final list = raw[entity];
        if (list is List && list.isNotEmpty) {
          results[section] = list
              .whereType<Map>()
              .map((e) => _flattenProject(Map<String, dynamic>.from(e)))
              .toList();
        }
      });
      return results;
    } catch (_) {}

    return {};
  }

  /// A page can be linked to several projects, so Plane reports a page hit's
  /// projects as `project_ids` / `project_identifiers` arrays. The row and the
  /// route need one project to open the page in, so lift the first. Every other
  /// entity already carries the scalar keys and passes through untouched.
  static Map<String, dynamic> _flattenProject(Map<String, dynamic> item) {
    if (item['project_id'] == null) {
      final ids = item['project_ids'];
      if (ids is List && ids.isNotEmpty) item['project_id'] = ids.first;
    }
    if (item['project__identifier'] == null) {
      final identifiers = item['project_identifiers'];
      if (identifiers is List && identifiers.isNotEmpty) {
        item['project__identifier'] = identifiers.first;
      }
    }
    return item;
  }
}
