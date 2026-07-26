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

  /// When the cycle was archived, or null while it is live.
  ///
  /// Only `archived-cycles/` ever sends this with a value — `cycles/` filters
  /// archived rows out server-side — so a cycle from the ordinary list always
  /// reads as null rather than as "unknown".
  final DateTime? archivedAt;

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
    this.archivedAt,
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
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        archivedAt: DateTime.tryParse(json['archived_at']?.toString() ?? ''),
      );

  double get progress => totalIssues > 0 ? completedIssues / totalIssues : 0;

  bool get isArchived => archivedAt != null;

  /// Whether Plane will accept an archive request for this cycle.
  ///
  /// `CycleArchiveUnarchiveEndpoint.post` rejects a cycle whose end date has
  /// not passed with a 400, and — because it compares `end_date >= now()`
  /// without a null guard — raises a TypeError, i.e. a 500, on a cycle that has
  /// no end date at all. Offering the action only when it can succeed is what
  /// keeps the app from provoking that.
  bool get canArchive {
    if (isArchived) return false;
    final end = endDate != null ? DateTime.tryParse(endDate!) : null;
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

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
