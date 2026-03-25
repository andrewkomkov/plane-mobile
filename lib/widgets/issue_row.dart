import 'package:flutter/material.dart';
import '../models/issue.dart';
import '../models/label.dart';
import '../models/member.dart';
import '../models/state.dart';
import 'issue_tile.dart';

/// Backward-compatible wrapper around [IssueTile].
/// All new code should use [IssueTile] directly.
class IssueRow extends StatelessWidget {
  final Issue issue;
  final IssueState? state;
  final String? identifier;
  final VoidCallback onTap;
  final List<Label> allLabels;
  final List<Member> allMembers;

  const IssueRow({
    super.key,
    required this.issue,
    this.state,
    this.identifier,
    required this.onTap,
    this.allLabels = const [],
    this.allMembers = const [],
  });

  @override
  Widget build(BuildContext context) {
    return IssueTile(
      issue: issue,
      state: state,
      projectIdentifier: identifier,
      showId: identifier != null,
      showPriority: true,
      showState: true,
      showLabels: true,
      showSubIssues: true,
      showAssignee: true,
      showDueDate: true,
      allLabels: allLabels,
      allMembers: allMembers,
      onTap: onTap,
    );
  }
}
