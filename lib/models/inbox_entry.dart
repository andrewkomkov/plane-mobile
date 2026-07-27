import 'notification.dart';

/// Where an inbox row came from, which decides what "read" and "dismiss" mean
/// for it.
///
/// Plane splits these two feeds and the split is not cosmetic. A
/// [InboxEntryKind.notification] is a real `Notification` row with server-side
/// `read_at` and `archived_at`, so both actions are writes Plane records and
/// every one of your devices sees. An [InboxEntryKind.activity] is an
/// `IssueActivity` row, which has no per-user state anywhere on the server —
/// its read and dismissed marks are this device's, kept in SQLite.
enum InboxEntryKind { notification, activity }

/// One row in the Inbox, from either of the two feeds Plane offers.
///
/// The two are merged rather than tabbed because they answer the same question
/// — what happened lately — and because on a workspace with one active member
/// only one of them is ever populated. See [InboxService] for why.
class InboxEntry {
  final InboxEntryKind kind;

  /// Notification id, or activity id. Unique within a feed; [InboxService]
  /// drops an activity whose id already arrived as a notification's
  /// `issue_activity`, so the merged list has no duplicate ids either.
  final String id;

  /// The work item's name — what the row is *about*.
  final String title;

  /// What happened to it, already phrased for a human.
  final String description;

  final String? issueId;
  final String? projectId;
  final String? projectIdentifier;
  final int sequenceId;
  final String priority;

  /// The work item's state group, when the feed carries it.
  ///
  /// Null for activity rows: `IssueActivitySerializer` nests the work item
  /// through `IssueFlatSerializer`, which has no state field. The row draws no
  /// state chip rather than a guessed one.
  final String? stateGroup;

  final DateTime createdAt;
  final bool isRead;

  const InboxEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    this.issueId,
    this.projectId,
    this.projectIdentifier,
    this.sequenceId = 0,
    this.priority = 'none',
    this.stateGroup,
    this.isRead = false,
  });

  InboxEntry copyWith({bool? isRead}) => InboxEntry(
        kind: kind,
        id: id,
        title: title,
        description: description,
        createdAt: createdAt,
        issueId: issueId,
        projectId: projectId,
        projectIdentifier: projectIdentifier,
        sequenceId: sequenceId,
        priority: priority,
        stateGroup: stateGroup,
        isRead: isRead ?? this.isRead,
      );

  /// The activity row this notification was raised for, when it names one.
  ///
  /// Plane writes the triggering `IssueActivity` into the notification's
  /// `data`, which is what lets the merge drop the activity copy of an event
  /// that also arrived as a notification.
  static String? activityIdOf(PlaneNotification n) {
    final activity = n.data['issue_activity'];
    if (activity is Map) return activity['id']?.toString();
    return null;
  }

  factory InboxEntry.fromNotification(PlaneNotification n) {
    final issue = n.data['issue'];
    final issueMap = issue is Map ? issue : const {};
    return InboxEntry(
      kind: InboxEntryKind.notification,
      id: n.id,
      title: (issueMap['name'] ?? n.title).toString(),
      description: _describeNotification(n),
      createdAt: n.createdAt,
      issueId: n.issueId,
      projectId: n.projectId,
      projectIdentifier: issueMap['identifier']?.toString(),
      sequenceId: _asInt(issueMap['sequence_id']),
      priority: (issueMap['priority'] ?? 'none').toString(),
      stateGroup: issueMap['state_group']?.toString(),
      isRead: n.isRead,
    );
  }

  /// One row of `workspaces/{slug}/user-activity/{user_id}/`.
  ///
  /// [isRead] is not in the payload — activity carries no per-user state — so
  /// the caller supplies what this device recorded.
  factory InboxEntry.fromActivity(
    Map<String, dynamic> json, {
    bool isRead = false,
  }) {
    final issue = json['issue_detail'];
    final issueMap = issue is Map ? issue : const {};
    final project = json['project_detail'];
    final projectMap = project is Map ? project : const {};
    final actor = json['actor_detail'];
    final actorMap = actor is Map ? actor : const {};

    return InboxEntry(
      kind: InboxEntryKind.activity,
      id: (json['id'] ?? '').toString(),
      title: (issueMap['name'] ?? '').toString(),
      description: describeActivity(
        actor: (actorMap['display_name'] ?? actorMap['email'] ?? 'Someone')
            .toString(),
        field: json['field']?.toString(),
        verb: json['verb']?.toString(),
        newValue: json['new_value']?.toString(),
      ),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      issueId: (json['issue'] ?? issueMap['id'])?.toString(),
      projectId: (json['project'] ?? projectMap['id'])?.toString(),
      projectIdentifier: projectMap['identifier']?.toString(),
      sequenceId: _asInt(issueMap['sequence_id']),
      priority: (issueMap['priority'] ?? 'none').toString(),
      isRead: isRead,
    );
  }

  /// A row read back out of SQLite.
  factory InboxEntry.fromCache(Map<String, dynamic> row) => InboxEntry(
        kind: row['kind'] == 'notification'
            ? InboxEntryKind.notification
            : InboxEntryKind.activity,
        id: (row['id'] ?? '').toString(),
        title: (row['title'] ?? '').toString(),
        description: (row['description'] ?? '').toString(),
        createdAt:
            DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.now(),
        issueId: row['issue_id']?.toString(),
        projectId: row['project_id']?.toString(),
        projectIdentifier: row['project_identifier']?.toString(),
        sequenceId: _asInt(row['sequence_id']),
        priority: (row['priority'] ?? 'none').toString(),
        stateGroup: row['state_group']?.toString(),
        isRead: row['read_at'] != null,
      );

  Map<String, dynamic> toCache() => {
        'id': id,
        'kind': kind == InboxEntryKind.notification ? 'notification' : 'activity',
        'title': title,
        'description': description,
        'project_id': projectId,
        'project_identifier': projectIdentifier,
        'issue_id': issueId,
        'sequence_id': sequenceId,
        'state_group': stateGroup,
        'priority': priority,
        'read_at': isRead ? createdAt.toIso8601String() : null,
        'created_at': createdAt.toIso8601String(),
      };

  static int _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// Phrase an activity row.
  ///
  /// Shared with the cache path so a row reads the same whether it came from
  /// the network or from SQLite.
  static String describeActivity({
    required String actor,
    String? field,
    String? verb,
    String? newValue,
  }) {
    final f = field ?? '';
    final v = verb ?? '';
    final n = newValue ?? '';

    if (f.isEmpty) {
      if (v == 'created') return '$actor created the work item';
      return '$actor updated the work item';
    }
    if (f == 'comment') return '$actor commented';
    if (f == 'assignees') return '$actor changed the assignees';
    if (f == 'state') return n.isEmpty ? '$actor changed the state' : '$actor moved it to $n';
    if (f == 'priority') return n.isEmpty ? '$actor changed the priority' : '$actor set priority to $n';
    if (n.isNotEmpty) return '$actor set $f to $n';
    return '$actor updated $f';
  }

  static String _describeNotification(PlaneNotification n) {
    final activity = n.data['issue_activity'];
    if (activity is Map) {
      final triggered = n.data['triggered_by_details'];
      final triggeredMap = triggered is Map ? triggered : const {};
      return describeActivity(
        actor: (triggeredMap['display_name'] ??
                triggeredMap['email'] ??
                'Someone')
            .toString(),
        field: activity['field']?.toString(),
        verb: activity['verb']?.toString(),
        newValue: activity['new_value']?.toString(),
      );
    }
    return n.title;
  }
}
