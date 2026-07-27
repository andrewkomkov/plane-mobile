class Workspace {
  final String id;
  final String name;
  final String slug;
  final String? logo;
  final int totalMembers;
  final DateTime createdAt;

  Workspace({
    required this.id,
    required this.name,
    required this.slug,
    this.logo,
    required this.totalMembers,
    required this.createdAt,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        slug: json['slug'] ?? '',
        // `logo` is the stored key; `logo_url` is the resolved one the
        // serializer adds. Prefer the resolved form when it is there.
        logo: (json['logo_url'] ?? json['logo']) as String?,
        totalMembers: json['total_members'] ?? 0,
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}
