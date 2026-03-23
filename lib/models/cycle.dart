class Cycle {
  final String id;
  final String name;
  final String? description;
  final String? startDate;
  final String? endDate;
  final int totalIssues;
  final int completedIssues;
  final DateTime createdAt;

  Cycle({
    required this.id,
    required this.name,
    this.description,
    this.startDate,
    this.endDate,
    required this.totalIssues,
    required this.completedIssues,
    required this.createdAt,
  });

  factory Cycle.fromJson(Map<String, dynamic> json) => Cycle(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        description: json['description'],
        startDate: json['start_date'],
        endDate: json['end_date'],
        totalIssues: json['total_issues'] ?? 0,
        completedIssues: json['completed_issues'] ?? 0,
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );

  double get progress =>
      totalIssues > 0 ? completedIssues / totalIssues : 0;
}
