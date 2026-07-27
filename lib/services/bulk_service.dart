import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_client.dart';

/// The three operations Plane has that act on a set of work items at once.
///
/// Worth having as its own service rather than three more methods on
/// [IssueService]: none of them addresses a work item, all three take a list
/// in the body, and each has a different permission floor. Grouping them makes
/// the last of those visible in one place instead of three.
class BulkService {
  @visibleForTesting
  static Dio? debugClient;

  static Future<Dio> _client() async =>
      debugClient ?? await ApiClient.getInstance();

  static String _base(String slug, String projectId) =>
      '/workspaces/$slug/projects/$projectId';

  /// Archive every work item in [issueIds].
  ///
  /// Plane refuses to archive anything that is not in a completed or cancelled
  /// state — `BulkArchiveIssuesEndpoint` answers 400 naming the first one it
  /// finds rather than archiving the rest — so the caller has to filter first
  /// or be ready to show that message.
  static Future<void> archiveIssues(
    String workspaceSlug,
    String projectId,
    List<String> issueIds,
  ) async {
    if (issueIds.isEmpty) return;
    final dio = await _client();
    await dio.post(
      '${_base(workspaceSlug, projectId)}/bulk-archive-issues/',
      data: {'issue_ids': issueIds},
    );
  }

  /// Delete every work item in [issueIds].
  ///
  /// Admin only, and irreversible: the endpoint also clears the cycle and
  /// module rows that pointed at them.
  static Future<void> deleteIssues(
    String workspaceSlug,
    String projectId,
    List<String> issueIds,
  ) async {
    if (issueIds.isEmpty) return;
    final dio = await _client();
    await dio.delete(
      '${_base(workspaceSlug, projectId)}/bulk-delete-issues/',
      data: {'issue_ids': issueIds},
    );
  }

  /// Create several labels in one request.
  ///
  /// Admin only. `label_data` is a list of `{name, color}` — the endpoint
  /// `bulk_create`s them, so a name that already exists is not reported back
  /// as a conflict; it simply appears twice.
  static Future<void> createLabels(
    String workspaceSlug,
    String projectId,
    List<({String name, String color})> labels,
  ) async {
    if (labels.isEmpty) return;
    final dio = await _client();
    await dio.post(
      '${_base(workspaceSlug, projectId)}/bulk-create-labels/',
      data: {
        'label_data': [
          for (final l in labels) {'name': l.name, 'color': l.color},
        ],
      },
    );
  }
}
