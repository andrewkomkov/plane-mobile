import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_client.dart';
import '../models/estimate_point.dart';

/// An estimate scale: a named set of points a project can size work with.
class Estimate {
  final String id;
  final String name;

  /// `points`, `categories` or `time`. Which one decides what a point's value
  /// is allowed to look like.
  final String type;

  final List<EstimatePoint> points;

  const Estimate({
    required this.id,
    required this.name,
    required this.type,
    this.points = const [],
  });

  factory Estimate.fromJson(Map<String, dynamic> json) {
    final raw = json['points'];
    final points = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => EstimatePoint.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <EstimatePoint>[];
    points.sort((a, b) => a.key.compareTo(b.key));
    return Estimate(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Estimate').toString(),
      type: (json['type'] ?? 'points').toString(),
      points: points,
    );
  }
}

/// Estimate *scales*, as opposed to the point set on one work item.
///
/// The app could already put a point on a work item but not create, edit or
/// retire the scale those points come from, so a project that had never been
/// set up on the web had no estimates at all and no way to gain them.
class EstimateService {
  @visibleForTesting
  static Dio? debugClient;

  static Future<Dio> _client() async =>
      debugClient ?? await ApiClient.getInstance();

  static String _base(String slug, String projectId) =>
      '/workspaces/$slug/projects/$projectId/estimates';

  static Future<List<Estimate>> getEstimates(
    String workspaceSlug,
    String projectId,
  ) async {
    final dio = await _client();
    final response = await dio.get('${_base(workspaceSlug, projectId)}/');
    final data = response.data;
    final rows = data is Map && data.containsKey('results')
        ? data['results'] as List
        : (data is List ? data : const []);
    return rows
        .whereType<Map>()
        .map((e) => Estimate.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Create a scale and its points in one call.
  ///
  /// The whole scale goes in at once — `estimate_points` is part of the create
  /// body — because a scale with no points is not usable and Plane offers no
  /// separate "activate" step.
  static Future<Estimate> createEstimate(
    String workspaceSlug,
    String projectId, {
    required String name,
    required String type,
    required List<String> values,
  }) async {
    final dio = await _client();
    final response = await dio.post(
      '${_base(workspaceSlug, projectId)}/',
      data: {
        'estimate': {'name': name, 'type': type},
        'estimate_points': [
          for (var i = 0; i < values.length; i++)
            {'key': i + 1, 'value': values[i]},
        ],
      },
    );
    return Estimate.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  static Future<void> deleteEstimate(
    String workspaceSlug,
    String projectId,
    String estimateId,
  ) async {
    final dio = await _client();
    await dio.delete('${_base(workspaceSlug, projectId)}/$estimateId/');
  }

  /// Add one point to an existing scale.
  static Future<void> addPoint(
    String workspaceSlug,
    String projectId,
    String estimateId, {
    required int key,
    required String value,
  }) async {
    final dio = await _client();
    await dio.post(
      '${_base(workspaceSlug, projectId)}/$estimateId/estimate-points/',
      data: {'key': key, 'value': value},
    );
  }

  static Future<void> updatePoint(
    String workspaceSlug,
    String projectId,
    String estimateId,
    String pointId, {
    required String value,
  }) async {
    final dio = await _client();
    await dio.patch(
      '${_base(workspaceSlug, projectId)}/$estimateId/estimate-points/$pointId/',
      data: {'value': value},
    );
  }

  /// Remove a point.
  ///
  /// [replacementId] is not optional in practice: work items already sized
  /// with this point have to be moved to another, and the endpoint takes the
  /// replacement in the body rather than orphaning them.
  static Future<void> deletePoint(
    String workspaceSlug,
    String projectId,
    String estimateId,
    String pointId, {
    String? replacementId,
  }) async {
    final dio = await _client();
    await dio.delete(
      '${_base(workspaceSlug, projectId)}/$estimateId/estimate-points/$pointId/',
      data: {if (replacementId != null) 'new_estimate_id': replacementId},
    );
  }
}
