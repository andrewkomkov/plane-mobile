class Project {
  final String id;
  final String name;
  final String identifier;
  final String? description;
  final String? coverImageUrl;
  final String? emoji;
  final int network;
  final int totalMembers;
  final bool isMember;
  final DateTime createdAt;

  Project({
    required this.id,
    required this.name,
    required this.identifier,
    this.description,
    this.coverImageUrl,
    this.emoji,
    required this.network,
    required this.totalMembers,
    required this.isMember,
    required this.createdAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        identifier: json['identifier'] ?? '',
        description: json['description'],
        coverImageUrl: json['cover_image_url'],
        emoji: json['emoji'],
        network: json['network'] ?? 0,
        totalMembers: json['total_members'] ?? 0,
        isMember: json['is_member'] ?? false,
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}
