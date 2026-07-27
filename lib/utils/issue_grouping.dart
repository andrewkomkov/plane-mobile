import '../models/issue.dart';
import '../models/state.dart';
import '../models/label.dart';
import '../models/member.dart';
import '../widgets/filter_bar.dart';

/// Groups issues by state group, preserving order.
/// Excludes completed/cancelled by default (for "my issues" view).
Map<String, List<Issue>> groupIssuesByStateGroup(
  List<Issue> issues,
  Map<String, IssueState> states, {
  bool excludeDone = false,
}) {
  final order = ['started', 'unstarted', 'backlog', 'completed', 'cancelled'];
  final groups = <String, List<Issue>>{};
  for (final g in order) {
    groups[g] = [];
  }
  for (final issue in issues) {
    final state = states[issue.state];
    final group = state?.group ?? 'backlog';
    if (excludeDone && (group == 'completed' || group == 'cancelled')) continue;
    groups.putIfAbsent(group, () => []);
    groups[group]!.add(issue);
  }
  groups.removeWhere((_, v) => v.isEmpty);
  return groups;
}

/// Groups issues by priority.
Map<String, List<Issue>> groupIssuesByPriority(List<Issue> issues) {
  final order = ['urgent', 'high', 'medium', 'low', 'none'];
  final groups = <String, List<Issue>>{};
  for (final p in order) {
    groups[p] = [];
  }
  for (final issue in issues) {
    final priority = issue.priority;
    groups.putIfAbsent(priority, () => []);
    groups[priority]!.add(issue);
  }
  groups.removeWhere((_, v) => v.isEmpty);
  return groups;
}

/// Groups issues by assignee.
Map<String, List<Issue>> groupIssuesByAssignee(
  List<Issue> issues,
  List<Member> members,
) {
  final memberMap = {for (final m in members) m.id: m.displayName};
  final groups = <String, List<Issue>>{};
  for (final issue in issues) {
    if (issue.assignees.isEmpty) {
      groups.putIfAbsent('Unassigned', () => []);
      groups['Unassigned']!.add(issue);
    } else {
      for (final assigneeId in issue.assignees) {
        final name = memberMap[assigneeId] ?? 'Unknown';
        groups.putIfAbsent(name, () => []);
        groups[name]!.add(issue);
      }
    }
  }
  groups.removeWhere((_, v) => v.isEmpty);
  return groups;
}

/// Groups issues by label.
Map<String, List<Issue>> groupIssuesByLabel(
  List<Issue> issues,
  List<Label> labels,
) {
  final labelMap = {for (final l in labels) l.id: l.name};
  final groups = <String, List<Issue>>{};
  for (final issue in issues) {
    if (issue.labels.isEmpty) {
      groups.putIfAbsent('No label', () => []);
      groups['No label']!.add(issue);
    } else {
      for (final labelId in issue.labels) {
        final name = labelMap[labelId] ?? 'Unknown';
        groups.putIfAbsent(name, () => []);
        groups[name]!.add(issue);
      }
    }
  }
  groups.removeWhere((_, v) => v.isEmpty);
  return groups;
}

/// Groups issues by the specified field.
Map<String, List<Issue>> groupIssuesBy(
  GroupByField groupBy,
  List<Issue> issues,
  Map<String, IssueState> states, {
  List<Member> members = const [],
  List<Label> labels = const [],
  bool excludeDone = false,
}) {
  switch (groupBy) {
    case GroupByField.state:
      return groupIssuesByStateGroup(issues, states, excludeDone: excludeDone);
    case GroupByField.priority:
      return groupIssuesByPriority(issues);
    case GroupByField.assignee:
      return groupIssuesByAssignee(issues, members);
    case GroupByField.label:
      return groupIssuesByLabel(issues, labels);
  }
}

/// Filters issues client-side based on filter state.
List<Issue> applyFilters(List<Issue> issues, FilterState filterState) {
  var filtered = issues;

  if (filterState.selectedStates.isNotEmpty) {
    filtered = filtered
        .where((i) =>
            i.state != null && filterState.selectedStates.contains(i.state))
        .toList();
  }
  if (filterState.selectedPriorities.isNotEmpty) {
    filtered = filtered
        .where((i) => filterState.selectedPriorities.contains(i.priority))
        .toList();
  }
  if (filterState.selectedAssignees.isNotEmpty) {
    filtered = filtered
        .where((i) =>
            i.assignees.any((a) => filterState.selectedAssignees.contains(a)))
        .toList();
  }
  if (filterState.selectedLabels.isNotEmpty) {
    filtered = filtered
        .where(
            (i) => i.labels.any((l) => filterState.selectedLabels.contains(l)))
        .toList();
  }

  return filtered;
}

/// Sorts issues based on sort field and direction.
List<Issue> applySorting(
    List<Issue> issues, SortField sortField, bool ascending) {
  final sorted = List<Issue>.from(issues);
  switch (sortField) {
    case SortField.createdAt:
      sorted.sort((a, b) => ascending
          ? a.createdAt.compareTo(b.createdAt)
          : b.createdAt.compareTo(a.createdAt));
    case SortField.updatedAt:
      sorted.sort((a, b) => ascending
          ? a.updatedAt.compareTo(b.updatedAt)
          : b.updatedAt.compareTo(a.updatedAt));
    case SortField.priority:
      const priorityOrder = {
        'urgent': 0,
        'high': 1,
        'medium': 2,
        'low': 3,
        'none': 4
      };
      sorted.sort((a, b) {
        final pa = priorityOrder[a.priority] ?? 4;
        final pb = priorityOrder[b.priority] ?? 4;
        return ascending ? pa.compareTo(pb) : pb.compareTo(pa);
      });
  }
  return sorted;
}

String groupLabel(String group) {
  switch (group) {
    case 'started':
      return 'In Progress';
    case 'unstarted':
      return 'Todo';
    case 'backlog':
      return 'Backlog';
    case 'completed':
      return 'Done';
    case 'cancelled':
      return 'Cancelled';
    default:
      return group;
  }
}

/// Returns label text for group-by headers.
String groupByLabel(GroupByField groupBy, String key) {
  if (groupBy == GroupByField.state) return groupLabel(key);
  if (groupBy == GroupByField.priority) {
    return key[0].toUpperCase() + key.substring(1);
  }
  return key;
}
