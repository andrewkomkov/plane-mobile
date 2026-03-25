class IssueLink {
  final String id;
  final String? title;
  final String url;
  final DateTime createdAt;

  IssueLink({
    required this.id,
    this.title,
    required this.url,
    required this.createdAt,
  });

  factory IssueLink.fromJson(Map<String, dynamic> json) => IssueLink(
        id: json['id'] ?? '',
        title: json['title'] as String?,
        url: json['url'] ?? '',
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}
