import 'issue.dart';

/// One work item sitting in a project's Intake (triage) queue.
///
/// Plane called this feature "Inbox" until it was renamed to "Intake"; the
/// server still answers the old `inbox-issues` URLs but the models, serialisers
/// and docs all say intake now. The one place the old name survives on the wire
/// is the `inbox` key in the v1 serialiser, which is an explicit read-only
/// alias for `intake.id` — see `plane/api/serializers/intake.py`.
///
/// Note that [id] and [issueId] are different things and only one of them is
/// usable in a URL. [id] is the IntakeIssue row; every intake detail route on
/// both the v1 and the internal API resolves its path parameter as
/// `issue_id=pk`, so [issueId] is what addresses a single entry.
class IntakeIssue {
  /// Primary key of the IntakeIssue row itself. Not a URL parameter.
  final String id;

  /// Primary key of the underlying work item. This is what the retrieve,
  /// update and delete routes key on.
  final String issueId;

  final Issue issue;

  /// -2=pending, -1=declined, 0=snoozed, 1=accepted, 2=duplicate.
  final int status;

  final DateTime? snoozedTill;
  final String? source;
  final DateTime createdAt;
  final DateTime updatedAt;

  IntakeIssue({
    required this.id,
    required this.issueId,
    required this.issue,
    required this.status,
    this.snoozedTill,
    this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IntakeIssue.fromJson(Map<String, dynamic> json) {
    // `issue_detail` is the expanded work item. `issue_inbox` was its name on
    // the pre-rename serialiser and is kept so a stale cached response still
    // parses. The bare `issue` key is normally just the work item's UUID.
    final raw = json['issue'];
    final detail = json['issue_detail'] ?? json['issue_inbox'] ?? raw;

    final issueJson = detail is Map
        ? _normaliseIssue(Map<String, dynamic>.from(detail))
        : <String, dynamic>{};

    return IntakeIssue(
      id: json['id']?.toString() ?? '',
      // Prefer the flat UUID: it survives a `?fields=` narrowing that would
      // drop the expanded object entirely.
      issueId: (raw is String && raw.isNotEmpty)
          ? raw
          : (issueJson['id']?.toString() ?? ''),
      issue: Issue.fromJson(issueJson),
      status: json['status'] ?? -2,
      snoozedTill: json['snoozed_till'] != null
          ? DateTime.tryParse(json['snoozed_till'])
          : null,
      source: json['source'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  String get statusLabel {
    switch (status) {
      case -2:
        return 'Pending';
      case -1:
        return 'Declined';
      case 0:
        return 'Snoozed';
      case 1:
        return 'Accepted';
      case 2:
        return 'Duplicate';
      default:
        return 'Unknown';
    }
  }

  /// Flattens the parts of the expanded work item that Plane nests but [Issue]
  /// models as an id.
  ///
  /// `IssueExpandSerializer` renders `state` through `StateLiteSerializer`, so
  /// it arrives as an object while `Issue.state` is a `String?`. Handing that
  /// object straight to `Issue.fromJson` throws at parse time, which is why
  /// this collapses it to its id first (and keeps the readable name in
  /// `state_detail`, matching how the rest of the app carries it).
  static Map<String, dynamic> _normaliseIssue(Map<String, dynamic> json) {
    final state = json['state'];
    if (state is Map) {
      json['state'] = state['id']?.toString();
      json['state_detail'] ??= state['name']?.toString();
    }
    return json;
  }
}
