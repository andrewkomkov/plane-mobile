import 'issue.dart';

/// The five values Plane's `intake_issues.status` column takes.
///
/// The numbers are the column's own `IntegerChoices`, declared in
/// `plane/db/models/intake.py` as `IntakeIssueStatus`. They are not sequential
/// and the ordering means nothing — -2 is the default a submission arrives
/// with, not a rank below -1.
class IntakeStatus {
  const IntakeStatus._();

  /// Waiting on a maintainer. The value the server assumes when a list request
  /// asks for no status at all.
  static const int pending = -2;

  static const int declined = -1;
  static const int snoozed = 0;
  static const int accepted = 1;
  static const int duplicate = 2;

  /// Still someone's problem. Matches the "Open" tab of Plane's own intake
  /// screen (`project-inbox.store.ts`), which pairs pending with snoozed.
  static const List<int> open = [pending, snoozed];

  /// Triaged, one way or another. Plane's "Closed" tab.
  static const List<int> closed = [accepted, declined, duplicate];

  /// Whether an entry at [status] can still be acted on.
  ///
  /// Plane's own header enables accept / decline / snooze / duplicate only for
  /// pending and snoozed entries, and offers nothing but "open the work item"
  /// once an entry is accepted, declined or marked duplicate. There is no
  /// route back: the server will take a status change on a closed entry, but
  /// accepting something already declined leaves the work item in whatever
  /// state the decline left it, so the app does not offer it either.
  static bool isOpen(int status) => open.contains(status);
}

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

  /// One of the [IntakeStatus] values.
  final int status;

  final DateTime? snoozedTill;
  final String? source;

  /// The work item this entry was marked a duplicate of. Set together with
  /// [status] `duplicate`, and null for every other status.
  final String? duplicateTo;

  /// Name of the work item [duplicateTo] points at, when the server expanded
  /// it. Only the retrieve and update responses carry it — the list serialiser
  /// sends the bare id — so a list row can know it is a duplicate without
  /// being able to say of what.
  final String? duplicateName;

  /// Who submitted the entry. Present on the list response, absent from the
  /// detail one, which is the opposite of what you would expect.
  final String? createdBy;

  /// When the *intake row* was created — which the server does not send.
  ///
  /// Neither `IntakeIssueSerializer` nor `IntakeIssueDetailSerializer` lists
  /// `created_at` or `updated_at` among its fields, so these are null on every
  /// response this app receives. They are kept nullable rather than defaulted
  /// to now() precisely so that nothing renders a fabricated timestamp: the
  /// submission time a user wants is `issue.createdAt`, which the nested work
  /// item does carry.
  final DateTime? createdAt;
  final DateTime? updatedAt;

  IntakeIssue({
    required this.id,
    required this.issueId,
    required this.issue,
    required this.status,
    this.snoozedTill,
    this.source,
    this.duplicateTo,
    this.duplicateName,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory IntakeIssue.fromJson(Map<String, dynamic> json) {
    // `issue_detail` is the expanded work item. `issue_inbox` was its name on
    // the pre-rename serialiser and is kept so a stale cached response still
    // parses. The bare `issue` key is the work item's UUID on the v1
    // serialiser and the whole nested object on the internal one — both
    // internal serialisers declare `issue` as a nested serialiser, so the
    // internal API never sends the flat id at all.
    final raw = json['issue'];
    final detail = json['issue_detail'] ?? json['issue_inbox'] ?? raw;

    final issueJson = detail is Map
        ? _normaliseIssue(Map<String, dynamic>.from(detail))
        : <String, dynamic>{};

    final duplicate = json['duplicate_issue_detail'];

    return IntakeIssue(
      id: json['id']?.toString() ?? '',
      // Prefer the flat UUID: it survives a `?fields=` narrowing that would
      // drop the expanded object entirely.
      issueId: (raw is String && raw.isNotEmpty)
          ? raw
          : (issueJson['id']?.toString() ?? ''),
      issue: Issue.fromJson(issueJson),
      status: json['status'] ?? IntakeStatus.pending,
      snoozedTill: json['snoozed_till'] != null
          ? DateTime.tryParse(json['snoozed_till'])
          : null,
      source: json['source'],
      duplicateTo: json['duplicate_to']?.toString(),
      duplicateName: duplicate is Map ? duplicate['name']?.toString() : null,
      createdBy: json['created_by']?.toString(),
      createdAt: DateTime.tryParse(json['created_at'] ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? ''),
    );
  }

  String get statusLabel {
    switch (status) {
      case IntakeStatus.pending:
        return 'Pending';
      case IntakeStatus.declined:
        return 'Declined';
      case IntakeStatus.snoozed:
        return 'Snoozed';
      case IntakeStatus.accepted:
        return 'Accepted';
      case IntakeStatus.duplicate:
        return 'Duplicate';
      default:
        return 'Unknown';
    }
  }

  /// Whether this entry still awaits a decision.
  bool get isOpen => IntakeStatus.isOpen(status);

  /// Whether a snooze has run out.
  ///
  /// The server does not sweep expired snoozes back to pending — the row keeps
  /// status 0 forever — so anything that treats "snoozed" as "hidden" quietly
  /// loses the entry on the day it was meant to resurface. The Open tab shows
  /// snoozed entries for exactly that reason, and this is what distinguishes
  /// the ones that are due.
  bool get snoozeExpired {
    final till = snoozedTill;
    if (status != IntakeStatus.snoozed || till == null) return false;
    return till.isBefore(DateTime.now());
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
