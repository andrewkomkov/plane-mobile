class PlaneNotification {
  final String id;
  final String title;
  final Map<String, dynamic> data;
  final String? entityName;
  final DateTime? readAt;
  final DateTime? snoozedTill;
  final DateTime? archivedAt;
  final DateTime createdAt;

  PlaneNotification({
    required this.id,
    required this.title,
    required this.data,
    this.entityName,
    this.readAt,
    this.snoozedTill,
    this.archivedAt,
    required this.createdAt,
  });

  factory PlaneNotification.fromJson(Map<String, dynamic> json) =>
      PlaneNotification(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        data: (json['data'] as Map<String, dynamic>?) ?? {},
        entityName: json['entity_name'],
        readAt:
            json['read_at'] != null ? DateTime.tryParse(json['read_at']) : null,
        snoozedTill: json['snoozed_till'] != null
            ? DateTime.tryParse(json['snoozed_till'])
            : null,
        archivedAt: json['archived_at'] != null
            ? DateTime.tryParse(json['archived_at'])
            : null,
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );

  bool get isRead => readAt != null;
  bool get isArchived => archivedAt != null;

  String? get issueId {
    if (data.containsKey('issue')) {
      final issue = data['issue'];
      if (issue is Map) return issue['id']?.toString();
      if (issue is String) return issue;
    }
    return data['issue_id']?.toString();
  }

  String? get projectId {
    if (data.containsKey('issue')) {
      final issue = data['issue'];
      if (issue is Map) return issue['project']?.toString();
    }
    return data['project_id']?.toString() ?? data['project']?.toString();
  }

  String? get workspaceSlug {
    return data['workspace_slug']?.toString() ?? data['workspace']?.toString();
  }
}
