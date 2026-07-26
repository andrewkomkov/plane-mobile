/// Reads a relation that the server may send either as a bare id or as an
/// expanded object.
///
/// Plane's v1 serialisers relate by primary key by default, but every one of
/// them honours an `?expand=` parameter that swaps the id for a nested object
/// (`state` becomes a `StateLiteSerializer`, `parent` an `IssueLiteSerializer`,
/// `created_by` a `UserLiteSerializer`, and so on — see
/// `plane/api/serializers/base.py:to_representation`). The same `Issue` is
/// parsed from several endpoints, and only some of them expand, so a parser
/// that assumes a string throws a `TypeError` the moment one of them does.
/// That failure is indistinguishable from a network error to a caller that
/// only catches, which is exactly how it survives unnoticed.
String? _relationId(dynamic value) {
  if (value == null) return null;
  if (value is Map) return value['id']?.toString();
  return value.toString();
}

/// Pulls a human name out of a relation, when the server expanded it.
///
/// Returns null for a bare id — a UUID is not a name, and rendering one is
/// worse than rendering nothing.
String? _relationName(dynamic value) {
  if (value is Map) {
    final name = value['name'] ?? value['display_name'];
    return name?.toString();
  }
  return null;
}

/// Reads a list of relations that may be ids or expanded objects.
List<String> _relationIds(dynamic value) {
  if (value is! List) return const [];
  return value.map(_relationId).whereType<String>().toList();
}

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
        // Plane's two APIs name the same field differently. The external v1
        // sends `state`; the internal one — which the app reaches through the
        // proxy — sends `state_id`, and the same holds for every relation
        // below. Reading only one spelling is why every work item arrived with
        // a null state, which the UI then rendered as "Unknown" and grouped
        // under Backlog.
        state: _relationId(json['state'] ?? json['state_id']),
        // Prefer an explicit `state_detail` (the internal API's shape), then
        // fall back to a name carried on an expanded `state`. Previously this
        // called toString() on whatever was there, which rendered a Dart map
        // literal into the UI whenever the field was not already a string.
        stateDetail: _relationName(json['state_detail']) ??
            _relationName(json['state']) ??
            (json['state_detail'] is String
                ? json['state_detail'] as String
                : null),
        priority: json['priority']?.toString() ?? 'none',
        sequenceId: json['sequence_id'] is int
            ? json['sequence_id'] as int
            : int.tryParse(json['sequence_id']?.toString() ?? '') ?? 0,
        projectDetail: _relationName(json['project_detail']) ??
            (json['project_detail'] is String
                ? json['project_detail'] as String
                : null),
        // v1 declares `assignees` and `labels` write_only, so they never come
        // back from it at all. The internal API does return them, as id lists
        // under `assignee_ids` / `label_ids`.
        assignees: _relationIds(json['assignees'] ?? json['assignee_ids']),
        labels: _relationIds(json['labels'] ?? json['label_ids']),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
            DateTime.now(),
        createdBy: _relationId(json['created_by']),
        project: _relationId(json['project'] ?? json['project_id']),
        startDate: json['start_date']?.toString(),
        targetDate: json['target_date']?.toString(),
        parent: _relationId(json['parent'] ?? json['parent_id']),
        subIssuesCount: json['sub_issues_count'] is int
            ? json['sub_issues_count'] as int
            : int.tryParse(json['sub_issues_count']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toCreateJson() => {
        'name': name,
        if (descriptionHtml != null) 'description_html': descriptionHtml,
        if (state != null) 'state': state,
        'priority': priority,
        if (assignees.isNotEmpty) 'assignees': assignees,
        if (labels.isNotEmpty) 'labels': labels,
        // Keys stay in the model's own vocabulary; IssueService translates
        // them to the server's write names on the way out.
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
