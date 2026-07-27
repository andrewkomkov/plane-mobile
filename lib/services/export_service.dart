import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_client.dart';

/// The file formats Plane's exporter accepts. Anything else is rejected by
/// name, so this is an enum rather than a string.
enum ExportFormat { csv, xlsx, json }

extension ExportFormatName on ExportFormat {
  String get provider => switch (this) {
        ExportFormat.csv => 'csv',
        ExportFormat.xlsx => 'xlsx',
        ExportFormat.json => 'json',
      };

  String get label => switch (this) {
        ExportFormat.csv => 'CSV',
        ExportFormat.xlsx => 'Excel',
        ExportFormat.json => 'JSON',
      };
}

/// Server-side exports.
///
/// Nothing is downloaded here. Both endpoints queue a background job and
/// answer immediately; the file arrives by email, or through the web app's own
/// downloads list. That is Plane's design, and it is why the app can only
/// start one and say so.
class ExportService {
  @visibleForTesting
  static Dio? debugClient;

  static Future<Dio> _client() async =>
      debugClient ?? await ApiClient.getInstance();

  /// Queue a work-item export.
  ///
  /// [projectIds] empty exports every project the caller is a member of —
  /// `ExportIssuesEndpoint` fills that in itself rather than treating an empty
  /// list as "nothing".
  ///
  /// Workspace admin or member; a guest is refused.
  static Future<void> exportIssues(
    String workspaceSlug, {
    required ExportFormat format,
    List<String> projectIds = const [],
  }) async {
    final dio = await _client();
    await dio.post(
      '/workspaces/$workspaceSlug/export-issues/',
      data: {
        'provider': format.provider,
        'project': projectIds,
        // The flag the endpoint reads to decide one file or one per project.
        'multiple': projectIds.length > 1,
      },
    );
  }

  /// Queue an analytics export, over the same filters the analytics screen is
  /// showing.
  static Future<void> exportAnalytics(
    String workspaceSlug, {
    Map<String, dynamic> filters = const {},
  }) async {
    final dio = await _client();
    await dio.post(
      '/workspaces/$workspaceSlug/export-analytics/',
      data: {
        'x_axis': 'priority',
        'y_axis': 'issue_count',
        ...filters,
      },
    );
  }
}
