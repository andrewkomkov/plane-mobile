import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_client.dart';
import '../models/cycle.dart';
import '../models/issue.dart';

class CycleService {
  /// Injected by tests in place of a real HTTP client, the same seam
  /// [AnalyticsService] and [FavoriteService] already carry. The cycle detail
  /// screen's accessibility can only be checked with issues listed on it.
  @visibleForTesting
  static Dio? debugClient;

  static Future<Dio> _client() async {
    final injected = debugClient;
    if (injected != null) return injected;
    return ApiClient.getInstance();
  }

  static Future<List<Cycle>> getCycles(
      String workspaceSlug, String projectId) async {
    final dio = await _client();
    final response =
        await dio.get('/workspaces/$workspaceSlug/projects/$projectId/cycles/');
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => Cycle.fromJson(e)).toList();
  }

  /// Archived cycles only.
  ///
  /// `CycleArchiveUnarchiveEndpoint.get` already filters on
  /// `archived_at__isnull=False`, so nothing live can come back through here
  /// and the caller does not have to filter again. It answers with a bare
  /// `.values()` list rather than a paginated envelope, and — unlike `cycles/`
  /// — that list omits `created_at`.
  static Future<List<Cycle>> getArchivedCycles(
      String workspaceSlug, String projectId) async {
    final dio = await _client();
    final response = await dio
        .get('/workspaces/$workspaceSlug/projects/$projectId/archived-cycles/');
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => Cycle.fromJson(e)).toList();
  }

  /// Archives a cycle.
  ///
  /// Both directions live on `cycles/{id}/archive/` and are told apart by the
  /// verb — POST archives, DELETE restores. The `archived-cycles/{id}/` route
  /// shares the same view class but only serves GET: its handler signatures
  /// take `cycle_id`, which that URL supplies as `pk`, so a write there fails
  /// before it reaches any of Plane's own logic.
  ///
  /// Rejected with 400 unless the cycle's end date has already passed. See
  /// [Cycle.canArchive] for why the app checks that itself first.
  static Future<void> archiveCycle(
    String workspaceSlug,
    String projectId,
    String cycleId,
  ) async {
    final dio = await _client();
    await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/cycles/$cycleId/archive/',
    );
  }

  static Future<void> unarchiveCycle(
    String workspaceSlug,
    String projectId,
    String cycleId,
  ) async {
    final dio = await _client();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/cycles/$cycleId/archive/',
    );
  }

  static Future<Cycle> createCycle(
    String workspaceSlug,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final dio = await _client();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/cycles/',
      data: data,
    );
    return Cycle.fromJson(response.data);
  }

  static Future<Cycle> updateCycle(
    String workspaceSlug,
    String projectId,
    String cycleId,
    Map<String, dynamic> data,
  ) async {
    final dio = await _client();
    final response = await dio.patch(
      '/workspaces/$workspaceSlug/projects/$projectId/cycles/$cycleId/',
      data: data,
    );
    return Cycle.fromJson(response.data);
  }

  static Future<void> deleteCycle(
    String workspaceSlug,
    String projectId,
    String cycleId,
  ) async {
    final dio = await _client();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/cycles/$cycleId/',
    );
  }

  static Future<List<Issue>> getCycleIssues(
      String workspaceSlug, String projectId, String cycleId) async {
    final dio = await _client();
    final response = await dio.get(
        '/workspaces/$workspaceSlug/projects/$projectId/cycles/$cycleId/cycle-issues/');
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data;
    return (list as List).map((e) => Issue.fromJson(e)).toList();
  }

  static Future<void> addIssuesToCycle(
    String workspaceSlug,
    String projectId,
    String cycleId,
    List<String> issueIds,
  ) async {
    final dio = await _client();
    await dio.post(
      '/workspaces/$workspaceSlug/projects/$projectId/cycles/$cycleId/cycle-issues/',
      data: {'issues': issueIds},
    );
  }

  static Future<void> removeIssueFromCycle(
    String workspaceSlug,
    String projectId,
    String cycleId,
    String issueId,
  ) async {
    final dio = await _client();
    await dio.delete(
      '/workspaces/$workspaceSlug/projects/$projectId/cycles/$cycleId/cycle-issues/$issueId/',
    );
  }
}
