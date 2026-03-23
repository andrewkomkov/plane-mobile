class PlanePage {
  final String id;
  final String name;
  final String? descriptionHtml;
  final String? ownedBy;
  final int access;
  final bool isLocked;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlanePage({
    required this.id,
    required this.name,
    this.descriptionHtml,
    this.ownedBy,
    required this.access,
    required this.isLocked,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlanePage.fromJson(Map<String, dynamic> json) => PlanePage(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        descriptionHtml: json['description_html'],
        ownedBy: json['owned_by'],
        access: json['access'] ?? 0,
        isLocked: json['is_locked'] ?? false,
        archivedAt: json['archived_at'] != null
            ? DateTime.tryParse(json['archived_at'])
            : null,
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        updatedAt:
            DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      );
}
