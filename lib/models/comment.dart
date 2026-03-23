class Comment {
  final String id;
  final String? commentHtml;
  final String? actorDetail;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Comment({
    required this.id,
    this.commentHtml,
    this.actorDetail,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] ?? '',
        commentHtml: json['comment_html'],
        actorDetail: json['actor_detail']?['display_name'] ??
            json['created_by']?.toString(),
        createdBy: json['created_by'],
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      );
}
