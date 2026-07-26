import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/m3e/text_field.dart';
import '../../services/archived_issue_service.dart';
import '../../services/draft_issue_service.dart';
import '../../services/issue_service.dart';
import '../../services/view_service.dart';
import '../../models/draft_issue.dart';
import '../../models/issue.dart';
import '../../models/label.dart';
import '../../models/member.dart';
import '../../models/state.dart';
import '../../utils/issue_grouping.dart';
import '../../widgets/archive_toggle.dart';
import '../../widgets/issue_listing_switcher.dart';
import '../../widgets/issue_row.dart';
import '../../widgets/section_header.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/display_options.dart';
import '../../widgets/bottom_sheet_picker.dart';
import 'issue_create_screen.dart';
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

  /// Which of the three listings is on screen.
  IssueListing _listing = IssueListing.live;

  /// Fetched here rather than by the parent tab.
  ///
  /// `IssuesTabScreen` hands the same live list to all four view modes, and
  /// three of them — board, table, calendar — have neither an archive nor
  /// drafts. Loading either up there would cost every project open a request
  /// that only one view can ever use, so this screen asks for them the first
  /// time it is asked to show one.
  List<ArchivedIssue>? _archived;
  bool _archivedLoading = false;
  String? _archivedError;

  List<DraftIssue>? _drafts;
  bool _draftsLoading = false;
  String? _draftsError;

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

  /// The caller's drafts for this project, in the order the server returned
  /// them — newest first, which the view fixes and no parameter changes.
  ///
  /// Not run through [_filteredAndSorted] for the same reason the archive is
  /// not: those controls belong to the live list, and the display sheet is not
  /// offered while a draft or the archive is showing.
  List<DraftIssue> get _draftIssues => _drafts ?? const [];

  Future<void> _loadDrafts() async {
    setState(() {
      _draftsLoading = true;
      _draftsError = null;
    });
    try {
      final drafts = await DraftIssueService.getDrafts(
        widget.workspaceSlug,
        projectId: widget.projectId,
      );
      if (mounted) {
        setState(() {
          _drafts = drafts;
          _draftsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _draftsError = e.toString();
          _draftsLoading = false;
        });
      }
    }
  }

  void _selectListing(IssueListing value) {
    setState(() => _listing = value);
    // Refetched on every entry rather than cached: a work item archived from
    // its detail screen, or a draft saved from the create screen, a moment ago
    // has to be here.
    switch (value) {
      case IssueListing.live:
        break;
      case IssueListing.drafts:
        _loadDrafts();
      case IssueListing.archived:
        _loadArchived();
    }
  }

  /// Opens a draft in the editor, which can save it, promote it or discard it.
  Future<void> _openDraft(DraftIssue draft) async {
    final outcome = await Navigator.push<IssueCreateOutcome>(
      context,
      MaterialPageRoute(
        builder: (_) => IssueCreateScreen(
          workspaceSlug: widget.workspaceSlug,
          projectId: widget.projectId,
          states: _states,
          draft: draft,
        ),
      ),
    );
    if (outcome == null || !mounted) return;
    await _loadDrafts();
    // Promotion creates a work item and destroys the draft, so the live list
    // the parent tab holds is stale too.
    if (outcome == IssueCreateOutcome.issueCreated) {
      await widget.onRefresh();
    }
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
    return Scaffold(
      body: Column(
        children: [
          // Minimal header: which listing, and the display sheet for the one
          // listing that has anything to display-option.
          //
          // The per-listing count used to live here as a leading label. It now
          // sits on the section header of whichever list is showing, where the
          // live list's group counts already were — so nothing was lost and the
          // switcher gets the width it needs at large font scales.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: IssueListingSwitcher(
                    value: _listing,
                    onChanged: _selectListing,
                  ),
                ),
                const SizedBox(width: 8),
                // A fixed slot rather than a conditional child: the button is
                // only offered on the live list, and without reserving its
                // width the switcher would resize every time the listing
                // changed, under the finger that changed it.
                SizedBox(
                  width: M3EIconButtonSize.small.container,
                  child: _listing == IssueListing.live
                      // The display sheet drives grouping and sorting, neither
                      // of which the drafts or archive listings use.
                      ? M3EIconButton(
                          icon: Icons.tune,
                          tooltip: 'Display options',
                          size: M3EIconButtonSize.small,
                          color: secondary,
                          onPressed: () => showDisplayOptions(
                              context, _display, () => setState(() {})),
                        )
                      : null,
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (_listing) {
              IssueListing.live => _liveList(),
              IssueListing.drafts => RefreshIndicator(
                  onRefresh: _loadDrafts,
                  child: _draftsList(),
                ),
              IssueListing.archived => RefreshIndicator(
                  onRefresh: _loadArchived,
                  child: _archivedList(),
                ),
            },
          ),
        ],
      ),
    );
  }

  Widget _draftsList() {
    if (_draftsError != null) {
      return ErrorStateWidget(
        message: 'Failed to load drafts',
        onRetry: _loadDrafts,
      );
    }
    if (_drafts == null && _draftsLoading) {
      return const LoadingStateWidget();
    }
    final drafts = _draftIssues;
    if (drafts.isEmpty) {
      return ListView(children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Center(
          child: EmptyStateWidget(
            message: 'No drafts',
            icon: Icons.edit_note,
            // Both halves are worth saying: the endpoint only ever returns the
            // caller's own drafts, and it is the same set the web client
            // writes to.
            subtitle: 'Your unfinished work items, saved here or on the web',
          ),
        ),
      ]);
    }
    return ListView.builder(
      itemCount: drafts.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          // "Your", because the server means it: the list filters on
          // created_by, so a teammate's drafts are not missing from this
          // count — they were never in scope.
          return SectionHeader(label: 'Your drafts', count: drafts.length);
        }
        final draft = drafts[i - 1];
        // The same IssueRow as every other list. The identifier is suppressed
        // because a draft has none: `DraftIssueSerializer` omits sequence_id,
        // so the row would render "PLM-0" for every draft in the project.
        return IssueRow(
          issue: draft.rowIssue,
          state: _states[draft.issue.state],
          showId: false,
          subtitle: draftSavedLabel(draft.issue.updatedAt),
          showPriority: true,
          showState: true,
          showLabels: true,
          showAssignee: true,
          allLabels: _labels,
          allMembers: _members,
          semanticExtras: const ['draft'],
          onTap: () => _openDraft(draft),
        );
      },
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
      itemCount: archived.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return SectionHeader(label: 'Archive', count: archived.length);
        }
        final entry = archived[i - 1];
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
