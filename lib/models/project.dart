class Project {
  final String id;
  final String name;
  final String identifier;
  final String? description;
  final String? coverImageUrl;
  final String? emoji;
  final int network;
  final int totalMembers;
  final int totalIssues;
  final bool isMember;
  final DateTime createdAt;

  /// Whether this project has Intake — Plane's triage queue — switched on.
  ///
  /// The column is `intake_view`. Both `ProjectSerializer` and
  /// `ProjectListSerializer` also publish it under the pre-rename alias
  /// `inbox_view`, and the list queryset annotates that second name directly,
  /// so which spelling arrives depends on which endpoint answered. Both are
  /// read.
  ///
  /// This flag is the only honest signal that Intake is on. The Intake row is
  /// created the first time the feature is enabled and is never deleted when
  /// it is turned off again, so "the intake endpoint answers" does not mean
  /// "intake is available here".
  final bool intakeEnabled;

  /// Work items waiting in Intake — the pending count, and nothing else.
  ///
  /// Only the project *list* endpoint annotates this (`intake_count`); the
  /// detail endpoint does not, and a project built from a search hit has
  /// neither. Null therefore means "not known", which is not the same as zero
  /// — a badge drawn from an invented zero would claim the queue is empty when
  /// in fact nobody has looked.
  final int? pendingIntakeCount;

  Project({
    required this.id,
    required this.name,
    required this.identifier,
    this.description,
    this.coverImageUrl,
    this.emoji,
    required this.network,
    required this.totalMembers,
    this.totalIssues = 0,
    required this.isMember,
    required this.createdAt,
    this.intakeEnabled = false,
    this.pendingIntakeCount,
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
        totalIssues: json['total_issues'] ?? 0,
        isMember: json['is_member'] ?? false,
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        intakeEnabled: json['inbox_view'] ?? json['intake_view'] ?? false,
        pendingIntakeCount:
            json['intake_count'] is int ? json['intake_count'] as int : null,
      );
}
