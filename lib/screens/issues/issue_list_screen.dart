import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/issue_service.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import 'issue_detail_screen.dart';
import 'issue_create_screen.dart';

class IssueListScreen extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final String projectIdentifier;

  const IssueListScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.projectIdentifier,
  });

  @override
  State<IssueListScreen> createState() => _IssueListScreenState();
}

class _IssueListScreenState extends State<IssueListScreen>
    with AutomaticKeepAliveClientMixin {
  List<Issue> _issues = [];
  Map<String, IssueState> _states = {};
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final states = await IssueService.getStates(widget.workspaceSlug, widget.projectId);
      final result = await IssueService.getIssues(widget.workspaceSlug, widget.projectId);
      setState(() {
        _states = {for (var s in states) s.id: s};
        _issues = result['issues'] as List<Issue>;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // Group issues by state group (like Linear)
  Map<String, List<Issue>> get _grouped {
    final groups = <String, List<Issue>>{};
    final order = ['started', 'unstarted', 'backlog', 'completed', 'cancelled'];
    for (final g in order) {
      groups[g] = [];
    }
    for (final issue in _issues) {
      final state = _states[issue.state];
      final group = state?.group ?? 'backlog';
      groups.putIfAbsent(group, () => []);
      groups[group]!.add(issue);
    }
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  String _groupLabel(String group) {
    switch (group) {
      case 'started': return 'In Progress';
      case 'unstarted': return 'Todo';
      case 'backlog': return 'Backlog';
      case 'completed': return 'Done';
      case 'cancelled': return 'Cancelled';
      default: return group;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final grouped = _grouped;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: _issues.isEmpty
            ? ListView(children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.35),
                Center(child: Text('No issues',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
              ])
            : ListView.builder(
                itemCount: grouped.entries.fold<int>(0,
                    (sum, e) => sum + 1 + e.value.length), // headers + issues
                itemBuilder: (ctx, index) {
                  int current = 0;
                  for (final entry in grouped.entries) {
                    if (index == current) {
                      // Group header
                      return _GroupHeader(
                        label: _groupLabel(entry.key),
                        count: entry.value.length,
                        color: PlaneTheme.stateGroupColor(entry.key),
                      );
                    }
                    current++;
                    final issueIndex = index - current;
                    if (issueIndex < entry.value.length) {
                      final issue = entry.value[issueIndex];
                      final state = _states[issue.state];
                      return _IssueRow(
                        issue: issue,
                        state: state,
                        identifier: widget.projectIdentifier,
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(
                            builder: (_) => IssueDetailScreen(
                              workspaceSlug: widget.workspaceSlug,
                              projectId: widget.projectId,
                              issueId: issue.id,
                              states: _states,
                            ),
                          ));
                          _load();
                        },
                      );
                    }
                    current += entry.value.length;
                  }
                  return const SizedBox.shrink();
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'create_issue',
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => IssueCreateScreen(
              workspaceSlug: widget.workspaceSlug,
              projectId: widget.projectId,
              states: _states,
            ),
          ));
          _load();
        },
        child: const Icon(Icons.add, size: 20),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _GroupHeader({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              )),
          const SizedBox(width: 6),
          Text('$count',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  final Issue issue;
  final IssueState? state;
  final String identifier;
  final VoidCallback onTap;

  const _IssueRow({
    required this.issue,
    this.state,
    required this.identifier,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Priority icon
            Icon(
              PlaneTheme.priorityIcon(issue.priority),
              size: 16,
              color: PlaneTheme.priorityColor(issue.priority),
            ),
            const SizedBox(width: 10),
            // State icon
            Icon(
              PlaneTheme.stateIcon(state?.group ?? 'backlog'),
              size: 16,
              color: state != null
                  ? PlaneTheme.stateGroupColor(state!.group)
                  : PlaneTheme.backlog,
            ),
            const SizedBox(width: 10),
            // Issue identifier
            Text(
              '$identifier-${issue.sequenceId}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 10),
            // Issue title
            Expanded(
              child: Text(
                issue.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
