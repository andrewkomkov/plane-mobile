class Activity {
  final String id;
  final String? field;
  final String? oldValue;
  final String? newValue;
  final String? verb;
  final String? actorDetail;
  final String? actorId;
  final DateTime createdAt;
  final String? oldIdentifier;
  final String? newIdentifier;
  final String? comment;

  Activity({
    required this.id,
    this.field,
    this.oldValue,
    this.newValue,
    this.verb,
    this.actorDetail,
    this.actorId,
    required this.createdAt,
    this.oldIdentifier,
    this.newIdentifier,
    this.comment,
  });

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        id: json['id'] ?? '',
        field: json['field'],
        oldValue: json['old_value'],
        newValue: json['new_value'],
        verb: json['verb'],
        actorDetail: _parseActorName(json),
        actorId: json['actor']?.toString(),
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        oldIdentifier: json['old_identifier'],
        newIdentifier: json['new_identifier'],
        comment: json['comment'],
      );

  String get formattedDescription {
    final actor = actorDetail ?? 'Someone';
    if (field == null || field!.isEmpty) {
      if (verb == 'created') return '$actor created the issue';
      return '$actor updated the issue';
    }
    final fieldName = formatFieldName(field!);
    if (verb == 'created') {
      if (newValue != null && newValue!.isNotEmpty) {
        return '$actor set $fieldName to $newValue';
      }
      return '$actor created the issue';
    }
    if (verb == 'updated') {
      if (oldValue != null &&
          oldValue!.isNotEmpty &&
          newValue != null &&
          newValue!.isNotEmpty) {
        return '$actor changed $fieldName from $oldValue to $newValue';
      }
      if (newValue != null && newValue!.isNotEmpty) {
        return '$actor set $fieldName to $newValue';
      }
      if (oldValue != null && oldValue!.isNotEmpty) {
        return '$actor removed $fieldName $oldValue';
      }
      return '$actor updated $fieldName';
    }
    if (verb == 'deleted') {
      return '$actor removed $fieldName${oldValue != null ? ' $oldValue' : ''}';
    }
    return '$actor $verb $fieldName';
  }

  static String? _parseActorName(Map<String, dynamic> json) {
    final detail = json['actor_detail'];
    if (detail is Map) {
      return detail['display_name'] as String? ??
          detail['first_name'] as String? ??
          detail['email'] as String?;
    }
    // actor_detail might be a string (name or ID)
    if (detail is String && !RegExp(r'^[0-9a-f-]{36}$').hasMatch(detail)) {
      return detail;
    }
    // Try actor field
    final actor = json['actor'];
    if (actor is Map) {
      return actor['display_name'] as String? ??
          actor['first_name'] as String? ??
          actor['email'] as String?;
    }
    return null;
  }

  static String formatFieldName(String field) {
    switch (field) {
      case 'state':
        return 'status';
      case 'priority':
        return 'priority';
      case 'assignees':
        return 'assignee';
      case 'labels':
        return 'label';
      case 'name':
        return 'title';
      case 'description':
        return 'description';
      case 'target_date':
        return 'due date';
      case 'start_date':
        return 'start date';
      case 'parent':
        return 'parent issue';
      case 'blocks':
        return 'blocking';
      case 'blocked_by':
        return 'blocked by';
      default:
        return field.replaceAll('_', ' ');
    }
  }
}
