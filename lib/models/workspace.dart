class Workspace {
  final String id;
  final String name;
  final String slug;
  final String? logo;
  final int totalMembers;
  final int totalProjects;
  final DateTime createdAt;

  Workspace({
    required this.id,
    required this.name,
    required this.slug,
    this.logo,
    required this.totalMembers,
    required this.totalProjects,
    required this.createdAt,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        slug: json['slug'] ?? '',
        logo: json['logo'] as String?,
        totalMembers: json['total_members'] ?? 0,
        totalProjects: json['total_projects'] ?? 0,
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}
