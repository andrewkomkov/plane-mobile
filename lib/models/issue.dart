class Issue {
  final String id;
  final String name;
  final String? descriptionHtml;
  final String? state;
  final String? stateDetail;
  final String priority;
  final int sequenceId;
  final String? projectDetail;
  final List<String> assignees;
  final List<String> labels;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? project;
  final String? startDate;
  final String? targetDate;
  final String? parent;
  final int subIssuesCount;

  Issue({
    required this.id,
    required this.name,
    this.descriptionHtml,
    this.state,
    this.stateDetail,
    required this.priority,
    required this.sequenceId,
    this.projectDetail,
    required this.assignees,
    required this.labels,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.project,
    this.startDate,
    this.targetDate,
    this.parent,
    this.subIssuesCount = 0,
  });

  factory Issue.fromJson(Map<String, dynamic> json) => Issue(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        descriptionHtml: json['description_html'],
        state: json['state'],
        stateDetail: json['state_detail']?.toString(),
        priority: json['priority'] ?? 'none',
        sequenceId: json['sequence_id'] ?? 0,
        projectDetail: json['project_detail']?.toString(),
        assignees: (json['assignees'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        labels: (json['labels'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        updatedAt:
            DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
        createdBy: json['created_by'],
        project: json['project'],
        startDate: json['start_date'],
        targetDate: json['target_date'],
        parent: json['parent'],
        subIssuesCount: json['sub_issues_count'] ?? 0,
      );

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        if (descriptionHtml != null) 'description_html': descriptionHtml,
        if (state != null) 'state': state,
        'priority': priority,
        if (assignees.isNotEmpty) 'assignees': assignees,
        if (labels.isNotEmpty) 'labels': labels,
        if (startDate != null) 'start_date': startDate,
        if (targetDate != null) 'target_date': targetDate,
        if (parent != null) 'parent': parent,
      };

  bool get isOverdue {
    if (targetDate == null) return false;
    final target = DateTime.tryParse(targetDate!);
    if (target == null) return false;
    return DateTime.now().isAfter(target);
  }
}
