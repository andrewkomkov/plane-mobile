import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/issue_service.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import 'issue_list_screen.dart';
import 'kanban_board_screen.dart';
import 'issue_create_screen.dart';

class IssuesTabScreen extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final String projectIdentifier;

  const IssuesTabScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.projectIdentifier,
  });

  @override
  State<IssuesTabScreen> createState() => _IssuesTabScreenState();
}

class _IssuesTabScreenState extends State<IssuesTabScreen>
    with AutomaticKeepAliveClientMixin {
  List<Issue> _issues = [];
  Map<String, IssueState> _states = {};
  bool _loading = true;
  bool _kanbanView = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final states = await IssueService.getStates(widget.workspaceSlug, widget.projectId);
      final result = await IssueService.getIssues(widget.workspaceSlug, widget.projectId);
      setState(() {
        _states = {for (var s in states) s.id: s};
        _issues = result['issues'] as List<Issue>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: Column(
        children: [
          // View toggle bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Text('${_issues.length} issues',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.colorScheme.outline, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ViewToggle(
                        icon: Icons.view_list,
                        selected: !_kanbanView,
                        onTap: () => setState(() => _kanbanView = false),
                      ),
                      _ViewToggle(
                        icon: Icons.view_kanban,
                        selected: _kanbanView,
                        onTap: () => setState(() => _kanbanView = true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _kanbanView
                ? KanbanBoardScreen(
                    workspaceSlug: widget.workspaceSlug,
                    projectId: widget.projectId,
                    projectIdentifier: widget.projectIdentifier,
                    issues: _issues,
                    states: _states,
                    onRefresh: _load,
                  )
                : IssueListScreen(
                    workspaceSlug: widget.workspaceSlug,
                    projectId: widget.projectId,
                    projectIdentifier: widget.projectIdentifier,
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'create_issue_tab',
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

class _ViewToggle extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ViewToggle({required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(icon, size: 16,
            color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
