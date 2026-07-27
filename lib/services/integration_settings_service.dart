import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_client.dart';

/// A personal access token.
class ApiToken {
  final String id;
  final String label;
  final String? description;

  /// Only ever present in the response to the create call. Plane hashes it
  /// afterwards and `APITokenReadSerializer` never sends it again, so a token
  /// not written down at that moment is gone.
  final String? token;

  final DateTime createdAt;
  final DateTime? expiredAt;
  final DateTime? lastUsed;
  final bool isActive;

  const ApiToken({
    required this.id,
    required this.label,
    required this.createdAt,
    this.description,
    this.token,
    this.expiredAt,
    this.lastUsed,
    this.isActive = true,
  });

  factory ApiToken.fromJson(Map<String, dynamic> json) => ApiToken(
        id: (json['id'] ?? '').toString(),
        label: (json['label'] ?? 'Token').toString(),
        description: json['description'] as String?,
        token: json['token'] as String?,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
        expiredAt: DateTime.tryParse(json['expired_at']?.toString() ?? ''),
        lastUsed: DateTime.tryParse(json['last_used']?.toString() ?? ''),
        isActive: json['is_active'] as bool? ?? true,
      );

  bool get neverExpires => expiredAt == null;
}

/// An outgoing webhook.
class Webhook {
  final String id;
  final String url;
  final bool isActive;
  final bool project;
  final bool issue;
  final bool module;
  final bool cycle;
  final bool issueComment;

  /// The signing secret. Like [ApiToken.token], returned on create and on
  /// regenerate and at no other time.
  final String? secretKey;

  const Webhook({
    required this.id,
    required this.url,
    this.isActive = true,
    this.project = false,
    this.issue = false,
    this.module = false,
    this.cycle = false,
    this.issueComment = false,
    this.secretKey,
  });

  factory Webhook.fromJson(Map<String, dynamic> json) => Webhook(
        id: (json['id'] ?? '').toString(),
        url: (json['url'] ?? '').toString(),
        isActive: json['is_active'] as bool? ?? true,
        project: json['project'] as bool? ?? false,
        issue: json['issue'] as bool? ?? false,
        module: json['module'] as bool? ?? false,
        cycle: json['cycle'] as bool? ?? false,
        issueComment: json['issue_comment'] as bool? ?? false,
        secretKey: json['secret_key'] as String?,
      );

  /// Which events it is subscribed to, for the row's second line.
  List<String> get events => [
        if (project) 'Projects',
        if (issue) 'Work items',
        if (module) 'Modules',
        if (cycle) 'Cycles',
        if (issueComment) 'Comments',
      ];
}

/// Personal access tokens and workspace webhooks.
///
/// Both were unreachable from the app, which was a gap with a sharp edge: the
/// app mints a token for its own sign-in and had no way to show you that it
/// had, let alone revoke it.
class IntegrationSettingsService {
  @visibleForTesting
  static Dio? debugClient;

  static Future<Dio> _client() async =>
      debugClient ?? await ApiClient.getInstance();

  static List _rows(Object? data) {
    if (data is Map && data.containsKey('results')) {
      return data['results'] as List;
    }
    return data is List ? data : const [];
  }

  // --- API tokens ----------------------------------------------------------
  //
  // Not workspace-scoped: the route is `users/api-tokens/`, and a token
  // belongs to the user across the instance.

  static Future<List<ApiToken>> getTokens() async {
    final dio = await _client();
    final response = await dio.get('/users/api-tokens/');
    return _rows(response.data)
        .whereType<Map>()
        .map((e) => ApiToken.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Mint a token.
  ///
  /// The returned [ApiToken.token] is the only time the secret is readable.
  static Future<ApiToken> createToken({
    required String label,
    String? description,
    DateTime? expiresAt,
  }) async {
    final dio = await _client();
    final response = await dio.post('/users/api-tokens/', data: {
      'label': label,
      if (description != null) 'description': description,
      // Omitted entirely rather than sent null: the endpoint reads
      // `expired_at` out of the body and treats absent as "never".
      if (expiresAt != null) 'expired_at': expiresAt.toIso8601String(),
    });
    return ApiToken.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  static Future<void> revokeToken(String tokenId) async {
    final dio = await _client();
    await dio.delete('/users/api-tokens/$tokenId/');
  }

  // --- Webhooks ------------------------------------------------------------

  static Future<List<Webhook>> getWebhooks(String workspaceSlug) async {
    final dio = await _client();
    final response = await dio.get('/workspaces/$workspaceSlug/webhooks/');
    return _rows(response.data)
        .whereType<Map>()
        .map((e) => Webhook.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Register a webhook.
  ///
  /// Plane validates the URL hard on the way in: it resolves the hostname and
  /// refuses any address that is private, loopback, reserved or link-local. A
  /// webhook pointing at something on the same network as the instance is
  /// rejected, not accepted and then silently dropped.
  static Future<Webhook> createWebhook(
    String workspaceSlug, {
    required String url,
    bool project = false,
    bool issue = true,
    bool module = false,
    bool cycle = false,
    bool issueComment = false,
  }) async {
    final dio = await _client();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/webhooks/',
      data: {
        'url': url,
        'project': project,
        'issue': issue,
        'module': module,
        'cycle': cycle,
        'issue_comment': issueComment,
      },
    );
    return Webhook.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  static Future<void> updateWebhook(
    String workspaceSlug,
    String webhookId,
    Map<String, dynamic> data,
  ) async {
    final dio = await _client();
    await dio.patch('/workspaces/$workspaceSlug/webhooks/$webhookId/',
        data: data);
  }

  static Future<void> deleteWebhook(
      String workspaceSlug, String webhookId) async {
    final dio = await _client();
    await dio.delete('/workspaces/$workspaceSlug/webhooks/$webhookId/');
  }

  /// Roll the signing secret.
  ///
  /// The whole webhook comes back with the new `secret_key` on it. `secret_key`
  /// is read-only on the serialiser rather than write-only, so unlike an API
  /// token it is readable on every list too — which is why this screen keeps
  /// it behind a reveal rather than printing it in a row.
  static Future<Webhook> regenerateSecret(
      String workspaceSlug, String webhookId) async {
    final dio = await _client();
    final response = await dio
        .post('/workspaces/$workspaceSlug/webhooks/$webhookId/regenerate/');
    return Webhook.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}
