import 'package:flutter/material.dart';
import '../../config/m3e/shapes.dart';
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
            // The column is a drop target, and a drop target has to be findable
            // by name before anything can be dragged onto it.
            return Semantics(
              label: 'Column ${state?.name ?? 'Unknown'}, '
                  '${columnIssues.length} issues',
              container: true,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 280,
                margin:
                    const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                decoration: isTarget
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(M3EShape.large),
                        // Drop targets read through the tint, not through a
                        // thicker outline — one border width across the board.
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 0.8,
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
                            color: PlaneTheme.stateGroupColor(context, state?.group ?? 'backlog'),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            state?.name ?? 'Unknown',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${columnIssues.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
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
                            stateName: state?.name ?? 'Unknown',
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

  /// Name of the column the card currently sits in, so the card announces
  /// where it is — a drag is only meaningful relative to that.
  final String stateName;
  final VoidCallback onTap;

  const _DraggableKanbanCard({
    required this.issue,
    required this.identifier,
    required this.stateName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<_DragData>(
      data: _DragData(issue: issue),
      feedback: Material(
        // The card under this carries the lift tonally; this only needs to be
        // a surface for the dragged copy to live on.
        elevation: 0,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(M3EShape.large),
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
      child: Semantics(
        label: 'Issue $identifier-${issue.sequenceId} in $stateName',
        hint: 'Long press and drag to move to another column',
        button: true,
        container: true,
        child: GestureDetector(
          onTap: onTap,
          child: _KanbanCardContent(
            issue: issue,
            identifier: identifier,
          ),
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
        // A card being dragged is lifted, and M3 says so with a tonal step
        // rather than a shadow. It used to say it twice with a shadow: the
        // Material wrapping this already carries elevation, and this added a
        // second black one under it — in an app whose theme sets elevation 0
        // on every other surface it defines.
        color: isDragging
            ? theme.colorScheme.surfaceContainerHighest
            : theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(M3EShape.large),
        border: Border.all(
          color: isDragging
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$identifier-${issue.sequenceId}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            issue.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                PlaneTheme.priorityIcon(issue.priority),
                size: PlaneTheme.iconSmall,
                color: PlaneTheme.priorityColor(context, issue.priority),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
