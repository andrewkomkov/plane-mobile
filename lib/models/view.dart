class PlaneView {
  final String id;
  final String name;
  final String? description;

  /// The view's filter set — `{'state': [...], 'priority': [...], ...}`.
  ///
  /// Read from `filters`. It used to be read from `query_data`, which is not a
  /// field on Plane's `IssueView` at all: the model holds `filters`, the
  /// compiled `query`, `display_filters` and `rich_filters`. So this map was
  /// empty for every view the server has ever sent, and a saved view listed
  /// the whole project rather than the subset it names — quietly, because an
  /// empty filter set is indistinguishable from "no filters" to the screen
  /// that applies it.
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
        queryData: (json['filters'] as Map<String, dynamic>?) ??
            // Kept as a fallback only because the workspace rollup screens
            // parse the same shape; nothing on this server sends it.
            (json['query_data'] as Map<String, dynamic>?) ??
            {},
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        updatedAt:
            DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      );
}
