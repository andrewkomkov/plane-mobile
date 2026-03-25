class Cycle {
  final String id;
  final String name;
  final String? description;
  final String? startDate;
  final String? endDate;
  final String? ownedBy;
  final String? status;
  final int totalIssues;
  final int completedIssues;
  final DateTime createdAt;

  Cycle({
    required this.id,
    required this.name,
    this.description,
    this.startDate,
    this.endDate,
    this.ownedBy,
    this.status,
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
        ownedBy: json['owned_by'],
        status: json['status'],
        totalIssues: json['total_issues'] ?? 0,
        completedIssues: json['completed_issues'] ?? 0,
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );

  double get progress =>
      totalIssues > 0 ? completedIssues / totalIssues : 0;

  String get computedStatus {
    if (status != null && status!.isNotEmpty) return status!;
    final now = DateTime.now();
    final start = startDate != null ? DateTime.tryParse(startDate!) : null;
    final end = endDate != null ? DateTime.tryParse(endDate!) : null;
    if (start == null || end == null) return 'draft';
    if (now.isBefore(start)) return 'upcoming';
    if (now.isAfter(end)) return 'completed';
    return 'current';
  }
}
