import 'package:flutter/material.dart';
import '../../config/m3e/shapes.dart';
import '../../config/theme.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../services/issue_service.dart';
import '../../widgets/issue_row.dart';
import '../../widgets/plane_row.dart';
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
    cols.removeWhere((key, v) => v.isEmpty && !widget.states.containsKey(key));
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
              // Not `excludeSemantics` — the column contains the cards, and
              // excluding would erase every one of them. `explicitChildNodes`
              // is the container form of the same rule: the header's own text
              // is forced into a node of its own instead of being merged into
              // this label, so the drop target reports its name once and the
              // cards below keep theirs.
              explicitChildNodes: true,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 280,
                margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                decoration: isTarget
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(M3EShape.large),
                        // Drop targets read through the tint, not through a
                        // thicker outline — one border width across the board.
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 0.8,
                        ),
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.05),
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
                            PlaneTheme.stateIcon(state?.group ?? 'backlog'),
                            size: PlaneTheme.iconSmall,
                            color: PlaneTheme.stateGroupColor(
                                context, state?.group ?? 'backlog'),
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
                              color: theme.colorScheme.onSurfaceVariant
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
                                    builder: (_) => IssueDetailScreen(
                                      workspaceSlug: widget.workspaceSlug,
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

  /// The board card is the same row as everywhere else, stacked instead of
  /// laid out across, because a 280dp column has no width for a side cluster.
  Widget _card({VoidCallback? onTap, bool dragging = false}) => IssueRow(
        issue: issue,
        identifier: identifier,
        density: PlaneRowDensity.card,
        // The column header already names the state, and a card is only ever
        // read inside its column.
        showState: false,
        maxTitleLines: 3,
        highlighted: dragging,
        // Neither clause is drawn on the card: the column it sits in is
        // structure, and the drag affordance has no visible affordance at all.
        // `M3EPressable` takes a label rather than a hint, so both ride in it.
        semanticExtras: [
          'in $stateName',
          'long press and drag to move to another column',
        ],
        onTap: onTap,
      );

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
        // The copy under the finger is a picture of the card, not a second
        // control — two nodes with the same label would confuse a screen
        // reader and `adb_drive.py tap` alike.
        child: SizedBox(
          width: 260,
          child: ExcludeSemantics(child: _card(dragging: true)),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: ExcludeSemantics(child: _card()),
      ),
      child: _card(onTap: onTap),
    );
  }
}
