import 'issue.dart';

class InboxIssue {
  final String id;
  final Issue issue;
  final int status; // -2=pending, -1=declined, 0=snoozed, 1=accepted, 2=duplicate
  final DateTime? snoozedTill;
  final String? source;
  final DateTime createdAt;
  final DateTime updatedAt;

  InboxIssue({
    required this.id,
    required this.issue,
    required this.status,
    this.snoozedTill,
    this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InboxIssue.fromJson(Map<String, dynamic> json) => InboxIssue(
        id: json['id'] ?? '',
        issue: Issue.fromJson(
            json['issue_detail'] ?? json['issue_inbox'] ?? json['issue'] ?? {}),
        status: json['status'] ?? -2,
        snoozedTill: json['snoozed_till'] != null
            ? DateTime.tryParse(json['snoozed_till'])
            : null,
        source: json['source'],
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        updatedAt:
            DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      );

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
}
