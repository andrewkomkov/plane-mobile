import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../services/issue_service.dart';
import 'issue_detail_screen.dart';

class KanbanBoardScreen extends StatefulWidget {
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

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  String? _dragTargetStateId;

  Map<String, List<Issue>> get _columns {
    final cols = <String, List<Issue>>{};
    for (final state in widget.states.values.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence))) {
      cols[state.id] = [];
    }
    for (final issue in widget.issues) {
      final stateId = issue.state ?? '';
      cols.putIfAbsent(stateId, () => []);
      cols[stateId]!.add(issue);
    }
    cols.removeWhere(
        (key, v) => v.isEmpty && !widget.states.containsKey(key));
    return cols;
  }

  Future<void> _onDrop(Issue issue, String targetStateId) async {
    if (issue.state == targetStateId) return;
    try {
      await IssueService.updateIssue(
        widget.workspaceSlug,
        widget.projectId,
        issue.id,
        {'state': targetStateId},
      );
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
        final state = widget.states[stateId];
        final columnIssues = columns[stateId]!;
        final isTarget = _dragTargetStateId == stateId;

        return DragTarget<_DragData>(
          onWillAcceptWithDetails: (details) {
            setState(() => _dragTargetStateId = stateId);
            return details.data.issue.state != stateId;
          },
          onLeave: (_) {
            setState(() => _dragTargetStateId = null);
          },
          onAcceptWithDetails: (details) {
            setState(() => _dragTargetStateId = null);
            _onDrop(details.data.issue, stateId);
          },
          builder: (ctx, candidateData, rejectedData) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 280,
              margin:
                  const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              decoration: isTarget
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary
                            .withValues(alpha: 0.5),
                        width: 2,
                      ),
                      color: theme.colorScheme.primary
                          .withValues(alpha: 0.05),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Column header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          PlaneTheme.stateIcon(
                              state?.group ?? 'backlog'),
                          size: PlaneTheme.iconSmall,
                          color: PlaneTheme.stateGroupColor(
                              state?.group ?? 'backlog'),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          state?.name ?? 'Unknown',
                          style: TextStyle(
                            fontSize: PlaneTheme.fontSection,
                            fontWeight: PlaneTheme.fontSectionWeight,
                            color:
                                theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${columnIssues.length}',
                          style: TextStyle(
                            fontSize: PlaneTheme.fontSmall,
                            color: theme
                                .colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
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
                        return _DraggableKanbanCard(
                          issue: issue,
                          identifier: widget.projectIdentifier,
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      IssueDetailScreen(
                                    workspaceSlug:
                                        widget.workspaceSlug,
                                    projectId: widget.projectId,
                                    issueId: issue.id,
                                    projectIdentifier:
                                        widget.projectIdentifier,
                                    states: widget.states,
                                  ),
                                ));
                            widget.onRefresh();
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
      },
    );
  }
}

class _DragData {
  final Issue issue;
  const _DragData({required this.issue});
}

class _DraggableKanbanCard extends StatelessWidget {
  final Issue issue;
  final String identifier;
  final VoidCallback onTap;

  const _DraggableKanbanCard({
    required this.issue,
    required this.identifier,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<_DragData>(
      data: _DragData(issue: issue),
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 260,
          child: _KanbanCardContent(
            issue: issue,
            identifier: identifier,
            isDragging: true,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _KanbanCardContent(
          issue: issue,
          identifier: identifier,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: _KanbanCardContent(
          issue: issue,
          identifier: identifier,
        ),
      ),
    );
  }
}

class _KanbanCardContent extends StatelessWidget {
  final Issue issue;
  final String identifier;
  final bool isDragging;

  const _KanbanCardContent({
    required this.issue,
    required this.identifier,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDragging
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          width: isDragging ? 1.5 : 0.5,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$identifier-${issue.sequenceId}',
            style: TextStyle(
              fontSize: PlaneTheme.fontSmall,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            issue.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: PlaneTheme.fontSection,
                fontWeight: FontWeight.w400,
                height: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                PlaneTheme.priorityIcon(issue.priority),
                size: PlaneTheme.iconSmall,
                color: PlaneTheme.priorityColor(issue.priority),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
