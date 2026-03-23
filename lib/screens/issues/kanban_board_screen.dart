import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import 'issue_detail_screen.dart';

class KanbanBoardScreen extends StatelessWidget {
  final String workspaceSlug;
  final String projectId;
  final String projectIdentifier;
  final List<Issue> issues;
  final Map<String, IssueState> states;
  final VoidCallback onRefresh;

  const KanbanBoardScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.projectIdentifier,
    required this.issues,
    required this.states,
    required this.onRefresh,
  });

  Map<String, List<Issue>> get _columns {
    final cols = <String, List<Issue>>{};
    // Group by state
    for (final state in states.values.toList()..sort((a, b) => a.sequence.compareTo(b.sequence))) {
      cols[state.id] = [];
    }
    for (final issue in issues) {
      final stateId = issue.state ?? '';
      cols.putIfAbsent(stateId, () => []);
      cols[stateId]!.add(issue);
    }
    cols.removeWhere((_, v) => v.isEmpty && !states.containsKey(_));
    return cols;
  }

  @override
  Widget build(BuildContext context) {
    final columns = _columns;
    final theme = Theme.of(context);

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: columns.length,
      itemBuilder: (ctx, i) {
        final stateId = columns.keys.elementAt(i);
        final state = states[stateId];
        final columnIssues = columns[stateId]!;

        return Container(
          width: 280,
          margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      PlaneTheme.stateIcon(state?.group ?? 'backlog'),
                      size: 14,
                      color: PlaneTheme.stateGroupColor(state?.group ?? 'backlog'),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state?.name ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${columnIssues.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Cards
              Expanded(
                child: ListView.builder(
                  itemCount: columnIssues.length,
                  itemBuilder: (ctx, j) {
                    final issue = columnIssues[j];
                    return _KanbanCard(
                      issue: issue,
                      identifier: projectIdentifier,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(
                          builder: (_) => IssueDetailScreen(
                            workspaceSlug: workspaceSlug,
                            projectId: projectId,
                            issueId: issue.id,
                            states: states,
                          ),
                        ));
                        onRefresh();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KanbanCard extends StatelessWidget {
  final Issue issue;
  final String identifier;
  final VoidCallback onTap;

  const _KanbanCard({required this.issue, required this.identifier, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outline, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$identifier-${issue.sequenceId}',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              issue.name,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  PlaneTheme.priorityIcon(issue.priority),
                  size: 14,
                  color: PlaneTheme.priorityColor(issue.priority),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
