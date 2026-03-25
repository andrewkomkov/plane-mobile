class PlaneView {
  final String id;
  final String name;
  final String? description;
  final Map<String, dynamic> queryData;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlaneView({
    required this.id,
    required this.name,
    this.description,
    required this.queryData,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlaneView.fromJson(Map<String, dynamic> json) => PlaneView(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        description: json['description'],
        queryData: (json['query_data'] as Map<String, dynamic>?) ?? {},
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        updatedAt:
            DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      );
}
