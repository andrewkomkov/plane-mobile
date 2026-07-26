import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/m3e/text_field.dart';
import '../../services/archived_issue_service.dart';
import '../../services/issue_service.dart';
import '../../services/view_service.dart';
import '../../models/issue.dart';
import '../../models/label.dart';
import '../../models/member.dart';
import '../../models/state.dart';
import '../../utils/issue_grouping.dart';
import '../../widgets/archive_toggle.dart';
import '../../widgets/issue_row.dart';
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
  ConsumerState<IssueListScreen> createState() => _IssueListScreenState();
}

class _IssueListScreenState extends ConsumerState<IssueListScreen>
    with AutomaticKeepAliveClientMixin {
  final DisplayState _display = DisplayState();
  FilterState _filterState = const FilterState();

  /// Whether the list is showing the archive instead of the live work items.
  bool _showArchived = false;

  /// Fetched here rather than by the parent tab.
  ///
  /// `IssuesTabScreen` hands the same live list to all four view modes, and
  /// three of them — board, table, calendar — have no archive. Loading the
  /// archive up there would cost every project open a request that only one
  /// view can ever use, so this screen asks for it the first time it is asked
  /// to show one.
  List<ArchivedIssue>? _archived;
  bool _archivedLoading = false;
  String? _archivedError;

  @override
  bool get wantKeepAlive => true;

  List<Issue> get _issues => widget.issues;
  Map<String, IssueState> get _states => widget.states;
  List<Label> get _labels => widget.labels;
  List<Member> get _members => widget.members;

  /// The archived work items, in the order the server returned them.
  ///
  /// Deliberately not run through [_filteredAndSorted]: the display sheet's
  /// completed filter defaults to hiding completed and cancelled work, and
  /// nearly everything in an archive is one of those — applying it here would
  /// show an empty archive to a user looking straight at a full one.
  List<ArchivedIssue> get _archivedIssues => _archived ?? const [];

  Future<void> _loadArchived() async {
    setState(() {
      _archivedLoading = true;
      _archivedError = null;
    });
    try {
      final archived = await ArchivedIssueService.getArchivedIssues(
          widget.workspaceSlug, widget.projectId);
      if (mounted) {
        setState(() {
          _archived = archived;
          _archivedLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _archivedError = e.toString();
          _archivedLoading = false;
        });
      }
    }
  }

  void _toggleArchived(bool value) {
    setState(() => _showArchived = value);
    // Refetched on every entry: a work item archived from its detail screen a
    // moment ago has to be here.
    if (value) _loadArchived();
  }

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
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
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
        queryData['priority'] = _filterState.selectedPriorities.toList();
      }
      if (_filterState.selectedAssignees.isNotEmpty) {
        queryData['assignees'] = _filterState.selectedAssignees.toList();
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
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('View saved')));
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

    final secondary = theme.colorScheme.onSurfaceVariant;
    final count =
        _showArchived ? _archivedIssues.length : _filteredAndSorted.length;
    return Scaffold(
      body: Column(
        children: [
          // Minimal header: issue count + archive toggle + display options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text('$count ${_showArchived ? 'archived' : 'issues'}',
                    style: theme.textTheme.bodySmall),
                const Spacer(),
                ArchiveToggle(
                  showArchived: _showArchived,
                  entityPlural: 'work items',
                  onChanged: _toggleArchived,
                ),
                const SizedBox(width: 4),
                // The display sheet drives grouping and sorting, neither of
                // which the archive uses, so it is not offered there.
                if (!_showArchived)
                  M3EIconButton(
                    icon: Icons.tune,
                    tooltip: 'Display options',
                    size: M3EIconButtonSize.small,
                    color: secondary,
                    onPressed: () => showDisplayOptions(
                        context, _display, () => setState(() {})),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _showArchived
                ? RefreshIndicator(
                    onRefresh: _loadArchived,
                    child: _archivedList(),
                  )
                : _liveList(),
          ),
        ],
      ),
    );
  }

  Widget _archivedList() {
    if (_archivedError != null) {
      return ErrorStateWidget(
        message: 'Failed to load archived work items',
        onRetry: _loadArchived,
      );
    }
    if (_archived == null && _archivedLoading) {
      return const LoadingStateWidget();
    }
    final archived = _archivedIssues;
    if (archived.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Center(
          child: EmptyStateWidget(
            message: 'No archived work items',
            icon: Icons.inventory_2_outlined,
            subtitle: 'Work items archived here or on the web appear here',
          ),
        ),
      ]);
    }
    return ListView.builder(
      itemCount: archived.length,
      itemBuilder: (ctx, i) {
        final entry = archived[i];
        final issue = entry.issue;
        // The same IssueRow every other list uses. Archived reads through the
        // subtitle slot and through the label — the row is not a variant, it
        // just has one more thing to say about itself.
        return IssueRow(
          issue: issue,
          state: _states[issue.state],
          identifier: widget.projectIdentifier,
          subtitle: archivedOnLabel(entry.archivedAt),
          showId: true,
          showPriority: true,
          showState: true,
          semanticExtras: const ['archived'],
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => IssueDetailScreen(
                  workspaceSlug: widget.workspaceSlug,
                  projectId: widget.projectId,
                  issueId: issue.id,
                  projectIdentifier: widget.projectIdentifier,
                  states: _states,
                ),
              ),
            );
            // Restoring happens on the detail screen, so what was open may no
            // longer belong in this list.
            _loadArchived();
          },
        );
      },
    );
  }

  Widget _liveList() {
    final grouped = _grouped;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: _filteredAndSorted.isEmpty
          ? ListView(children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
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
              itemCount: grouped.entries
                  .fold<int>(0, (sum, e) => sum + 1 + e.value.length),
              itemBuilder: (ctx, index) {
                int current = 0;
                for (final entry in grouped.entries) {
                  if (index == current) {
                    final label =
                        groupByLabel(_display.groupByField, entry.key);
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
                    return IssueRow(
                      issue: issue,
                      state: state,
                      identifier: widget.projectIdentifier,
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
                              builder: (_) => IssueDetailScreen(
                                workspaceSlug: widget.workspaceSlug,
                                projectId: widget.projectId,
                                issueId: issue.id,
                                projectIdentifier: widget.projectIdentifier,
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
    );
  }
}
