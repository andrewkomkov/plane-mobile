import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_client.dart';
import '../models/module.dart';
import '../models/issue.dart';

class ModuleService {
  /// Injected by tests in place of a real HTTP client, the same seam
  /// [AnalyticsService] and [FavoriteService] already carry.
  @visibleForTesting
  static Dio? debugClient;

  static Future<Dio> _client() async {
    final injected = debugClient;
    if (injected != null) return injected;
    return ApiClient.getInstance();
  }

  static Future<List<Module>> getModules(
      String workspaceSlug, String projectId) async {
    final dio = await _client();
    final response = await dio
        .get('/workspaces/$workspaceSlug/projects/$projectId/modules/');
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => Module.fromJson(e)).toList();
  }

  /// Archived modules only.
  ///
  /// `ModuleArchiveUnarchiveEndpoint.get` filters on
  /// `archived_at__isnull=False` itself, and answers with a bare `.values()`
  /// list rather than a paginated envelope.
  static Future<List<Module>> getArchivedModules(
      String workspaceSlug, String projectId) async {
    final dio = await _client();
    final response = await dio.get(
        '/workspaces/$workspaceSlug/projects/$projectId/archived-modules/');
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => Module.fromJson(e)).toList();
  }

  /// Archives a module.
  ///
  /// Same shape as cycles: POST and DELETE on `modules/{id}/archive/` are the
  /// two directions, and `archived-modules/{id}/` is read-only regardless of
  /// what its name suggests — its handler expects `module_id` where the URL
  /// gives `pk`.
  ///
  /// Rejected with 400 unless the module's status is completed or cancelled.
  /// See [Module.canArchive].
  static Future<void> archiveModule(
    String workspaceSlug,
    String projectId,
    String moduleId,
  ) async {
    final dio = await _client();
    await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/modules/$moduleId/archive/',
    );
  }

  static Future<void> unarchiveModule(
    String workspaceSlug,
    String projectId,
    String moduleId,
  ) async {
    final dio = await _client();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/modules/$moduleId/archive/',
    );
  }

  static Future<Module> createModule(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final dio = await _client();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/modules/',
      data: data,
    );
    return Module.fromJson(response.data);
  }

  static Future<Module> updateModule(
    String workspaceSlug,
    String projectId,
    String moduleId,
    Map<String, dynamic> data,
  ) async {
    final dio = await _client();
    final response = await dio.patch(
      '/workspaces/$workspaceSlug/projects/$projectId/modules/$moduleId/',
      data: data,
    );
    return Module.fromJson(response.data);
  }

  static Future<void> deleteModule(
    String workspaceSlug,
    String projectId,
    String moduleId,
  ) async {
    final dio = await _client();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/modules/$moduleId/',
    );
  }

  static Future<List<Issue>> getModuleIssues(
      String workspaceSlug, String projectId, String moduleId) async {
    final dio = await _client();
    final response = await dio.get(
        '/workspaces/$workspaceSlug/projects/$projectId/modules/$moduleId/issues/');
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => Issue.fromJson(e)).toList();
  }

  static Future<void> addIssuesToModule(
    String workspaceSlug,
    String projectId,
    String moduleId,
    List<String> issueIds,
  ) async {
    final dio = await _client();
    await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/modules/$moduleId/issues/',
      data: {'issues': issueIds},
    );
  }

  static Future<void> removeIssueFromModule(
    String workspaceSlug,
    String projectId,
    String moduleId,
    String issueId,
  ) async {
    final dio = await _client();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/modules/$moduleId/issues/$issueId/',
    );
  }
}
