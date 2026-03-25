class Module {
  final String id;
  final String name;
  final String? description;
  final String? status;
  final String? startDate;
  final String? targetDate;
  final String? lead;
  final List<String> members;
  final int totalIssues;
  final int completedIssues;
  final DateTime createdAt;

  Module({
    required this.id,
    required this.name,
    this.description,
    this.status,
    this.startDate,
    this.targetDate,
    this.lead,
    this.members = const [],
    required this.totalIssues,
    required this.completedIssues,
    required this.createdAt,
  });

  factory Module.fromJson(Map<String, dynamic> json) => Module(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        description: json['description'],
        status: json['status'],
        startDate: json['start_date'],
        targetDate: json['target_date'],
        lead: json['lead'],
        members: (json['members'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        totalIssues: json['total_issues'] ?? 0,
        completedIssues: json['completed_issues'] ?? 0,
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );

  double get progress =>
      totalIssues > 0 ? completedIssues / totalIssues : 0;
}
