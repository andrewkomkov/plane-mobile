import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/m3e/text_field.dart';
import '../../services/issue_service.dart';
import '../../services/view_service.dart';
import '../../models/issue.dart';
import '../../models/label.dart';
import '../../models/member.dart';
import '../../models/state.dart';
import '../../utils/issue_grouping.dart';
import '../../widgets/issue_tile.dart';
import '../../widgets/section_header.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/display_options.dart';
import '../../widgets/bottom_sheet_picker.dart';
import 'issue_detail_screen.dart';


class IssueListScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final String projectIdentifier;
  // Data passed from parent (IssuesTabScreen) — no duplicate API calls
  final List<Issue> issues;
  final Map<String, IssueState> states;
  final List<Label> labels;
  final List<Member> members;
  final Future<void> Function() onRefresh;

  const IssueListScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.projectIdentifier,
    required this.issues,
    required this.states,
    required this.labels,
    required this.members,
    required this.onRefresh,
  });

  @override
  ConsumerState<IssueListScreen> createState() =>
      _IssueListScreenState();
}

class _IssueListScreenState extends ConsumerState<IssueListScreen>
    with AutomaticKeepAliveClientMixin {
  final DisplayState _display = DisplayState();
  FilterState _filterState = const FilterState();

  @override
  bool get wantKeepAlive => true;

  List<Issue> get _issues => widget.issues;
  Map<String, IssueState> get _states => widget.states;
  List<Label> get _labels => widget.labels;
  List<Member> get _members => widget.members;

  Future<void> _saveAsView() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Save as View'),
          content: M3ETextField(
            label: 'View name',
            controller: controller,
            autofocus: true,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Save')),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      final queryData = <String, dynamic>{};
      if (_filterState.selectedStates.isNotEmpty) {
        queryData['state'] = _filterState.selectedStates.toList();
      }
      if (_filterState.selectedPriorities.isNotEmpty) {
        queryData['priority'] =
            _filterState.selectedPriorities.toList();
      }
      if (_filterState.selectedAssignees.isNotEmpty) {
        queryData['assignees'] =
            _filterState.selectedAssignees.toList();
      }
      if (_filterState.selectedLabels.isNotEmpty) {
        queryData['label'] = _filterState.selectedLabels.toList();
      }
      try {
        await ViewService.createView(
          widget.workspaceSlug,
          widget.projectId,
          {'name': name, 'query_data': queryData},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('View saved')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  List<Issue> get _filteredAndSorted {
    var result = _issues.toList();
    // Completed filter
    if (_display.completedFilter == 'none') {
      result = result.where((i) {
        final group = _states[i.state]?.group ?? 'backlog';
        return group != 'completed' && group != 'cancelled';
      }).toList();
    } else if (_display.completedFilter == 'week') {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      result = result.where((i) {
        final group = _states[i.state]?.group ?? 'backlog';
        if (group != 'completed' && group != 'cancelled') return true;
        return i.updatedAt.isAfter(weekAgo);
      }).toList();
    }
    if (!_display.showSubIssues) {
      result = result.where((i) => i.parent == null).toList();
    }
    result = applySorting(result, _display.sortField, !_display.sortNewest);
    return result;
  }

  Map<String, List<Issue>> get _grouped {
    return groupIssuesBy(
      _display.groupByField,
      _filteredAndSorted,
      _states,
      members: _members,
      labels: _labels,
    );
  }

  Color _groupColor(String key) {
    switch (_display.groupByField) {
      case GroupByField.state:
        return PlaneTheme.stateGroupColor(context, key);
      case GroupByField.priority:
        return PlaneTheme.priorityColor(context, key);
      case GroupByField.assignee:
      case GroupByField.label:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    final grouped = _grouped;

    final secondary = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      body: Column(
        children: [
          // Minimal header: issue count + display options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text('${_filteredAndSorted.length} issues',
                    style: theme.textTheme.bodySmall),
                const Spacer(),
                M3EIconButton(
                  icon: Icons.tune,
                  tooltip: 'Display options',
                  size: M3EIconButtonSize.small,
                  color: secondary,
                  onPressed: () =>
                      showDisplayOptions(context, _display, () => setState(() {})),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: _filteredAndSorted.isEmpty
                  ? ListView(children: [
                      SizedBox(
                          height: MediaQuery.of(context).size.height *
                              0.25),
                      Center(
                        child: EmptyStateWidget(
                          message: _filterState.hasActiveFilters
                              ? 'No issues match filters'
                              : 'No issues',
                          icon: Icons.check_circle_outline,
                          subtitle: _filterState.hasActiveFilters
                              ? 'Try adjusting your filters'
                              : null,
                        ),
                      ),
                    ])
                  : ListView.builder(
                      itemCount: grouped.entries.fold<int>(
                          0, (sum, e) => sum + 1 + e.value.length),
                      itemBuilder: (ctx, index) {
                        int current = 0;
                        for (final entry in grouped.entries) {
                          if (index == current) {
                            final label = groupByLabel(
                                _display.groupByField, entry.key);
                            return SectionHeader(
                              label: label,
                              count: entry.value.length,
                              color: _groupColor(entry.key),
                            );
                          }
                          current++;
                          final issueIndex = index - current;
                          if (issueIndex < entry.value.length) {
                            final issue = entry.value[issueIndex];
                            final state = _states[issue.state];
                            return IssueTile(
                              issue: issue,
                              state: state,
                              projectIdentifier:
                                  widget.projectIdentifier,
                              showId: _display.rowProperties.contains('id'),
                              showPriority: _display.rowProperties.contains('priority'),
                              showState: _display.rowProperties.contains('status'),
                              showLabels: _display.rowProperties.contains('labels'),
                              showSubIssues: true,
                              showAssignee: _display.rowProperties.contains('assignee'),
                              showDueDate: _display.rowProperties.contains('due_date'),
                              maxTitleLines: _display.maxTitleLines,
                              allLabels: _labels,
                              allMembers: _members,
                              onTap: () async {
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          IssueDetailScreen(
                                        workspaceSlug:
                                            widget.workspaceSlug,
                                        projectId:
                                            widget.projectId,
                                        issueId: issue.id,
                                        projectIdentifier:
                                            widget.projectIdentifier,
                                        states: _states,
                                      ),
                                    ));
                                widget.onRefresh();
                              },
                            );
                          }
                          current += entry.value.length;
                        }
                        return const SizedBox.shrink();
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

