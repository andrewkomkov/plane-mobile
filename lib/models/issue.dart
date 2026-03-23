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
      );

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        if (descriptionHtml != null) 'description_html': descriptionHtml,
        if (state != null) 'state': state,
        'priority': priority,
        if (assignees.isNotEmpty) 'assignees': assignees,
        if (labels.isNotEmpty) 'labels': labels,
      };
}
