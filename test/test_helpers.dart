import 'package:plane_mobile/models/issue.dart';
import 'package:plane_mobile/models/project.dart';
import 'package:plane_mobile/models/page.dart';
import 'package:plane_mobile/models/cycle.dart';
import 'package:plane_mobile/models/module.dart';
import 'package:plane_mobile/models/activity.dart';
import 'package:plane_mobile/models/comment.dart';
import 'package:plane_mobile/models/state.dart';
import 'package:plane_mobile/models/label.dart';
import 'package:plane_mobile/models/member.dart';

Issue makeIssue({
  String id = 'issue-1',
  String name = 'Test Issue',
  String? descriptionHtml,
  String? state = 'state-1',
  String? stateDetail,
  String priority = 'medium',
  int sequenceId = 1,
  String? projectDetail,
  List<String> assignees = const [],
  List<String> labels = const [],
  DateTime? createdAt,
  DateTime? updatedAt,
  String? createdBy,
  String? project,
  String? startDate,
  String? targetDate,
  String? parent,
  int subIssuesCount = 0,
}) =>
    Issue(
      id: id,
      name: name,
      descriptionHtml: descriptionHtml,
      state: state,
      stateDetail: stateDetail,
      priority: priority,
      sequenceId: sequenceId,
      projectDetail: projectDetail,
      assignees: assignees,
      labels: labels,
      createdAt: createdAt ?? DateTime(2025, 1, 1),
      updatedAt: updatedAt ?? DateTime(2025, 1, 1),
      createdBy: createdBy,
      project: project,
      startDate: startDate,
      targetDate: targetDate,
      parent: parent,
      subIssuesCount: subIssuesCount,
    );

IssueState makeState({
  String id = 'state-1',
  String name = 'In Progress',
  String color = '#FFAA00',
  String group = 'started',
  int sequence = 1,
}) =>
    IssueState(
      id: id,
      name: name,
      color: color,
      group: group,
      sequence: sequence,
    );

Label makeLabel({
  String id = 'label-1',
  String name = 'Bug',
  String color = '#FF0000',
}) =>
    Label(id: id, name: name, color: color);

Member makeMember({
  String id = 'member-1',
  String displayName = 'John Doe',
  String email = 'john@example.com',
  String firstName = 'John',
  String lastName = 'Doe',
  String? avatar,
}) =>
    Member(
      id: id,
      displayName: displayName,
      email: email,
      firstName: firstName,
      lastName: lastName,
      avatar: avatar,
    );
