import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_client.dart';

/// One saved state of a work item's description.
class DescriptionVersion {
  final String id;

  /// The body as it was. Null on a list row — the list serialiser omits it and
  /// only the detail carries it, the same shape the page list has.
  final String? descriptionHtml;

  /// When this version stopped being the current one.
  final DateTime lastSavedAt;

  /// The user id that saved it.
  final String? ownedBy;

  const DescriptionVersion({
    required this.id,
    required this.lastSavedAt,
    this.descriptionHtml,
    this.ownedBy,
  });

  factory DescriptionVersion.fromJson(Map<String, dynamic> json) =>
      DescriptionVersion(
        id: (json['id'] ?? '').toString(),
        descriptionHtml: json['description_html'] as String?,
        lastSavedAt:
            DateTime.tryParse(json['last_saved_at']?.toString() ?? '') ??
                DateTime.tryParse(json['created_at']?.toString() ?? '') ??
                DateTime.now(),
        ownedBy: json['owned_by']?.toString(),
      );
}

/// A work item's description history.
///
/// Separate from the activity feed, which records *that* the description
/// changed and never what it said. This is the only way back to a body that
/// was overwritten.
///
/// Note the route says `work-items`, not `issues`: it is one of the few places
/// where Plane's newer naming reached the internal API. The sibling
/// `issues/{id}/versions/` is a different thing — whole-work-item versions,
/// not description ones.
class DescriptionVersionService {
  @visibleForTesting
  static Dio? debugClient;

  static Future<Dio> _client() async =>
      debugClient ?? await ApiClient.getInstance();

  static String _base(String slug, String projectId, String issueId) =>
      '/workspaces/$slug/projects/$projectId/work-items/$issueId/description-versions';

  static Future<List<DescriptionVersion>> getVersions(
    String workspaceSlug,
    String projectId,
    String issueId,
  ) async {
    final dio = await _client();
    final response =
        await dio.get('${_base(workspaceSlug, projectId, issueId)}/');
    final data = response.data;
    final rows = data is Map && data.containsKey('results')
        ? data['results'] as List
        : (data is List ? data : const []);
    return rows
        .whereType<Map>()
        .map((e) => DescriptionVersion.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// One version, with its body — which the listing does not carry.
  static Future<DescriptionVersion> getVersion(
    String workspaceSlug,
    String projectId,
    String issueId,
    String versionId,
  ) async {
    final dio = await _client();
    final response = await dio
        .get('${_base(workspaceSlug, projectId, issueId)}/$versionId/');
    return DescriptionVersion.fromJson(
        Map<String, dynamic>.from(response.data as Map));
  }
}
