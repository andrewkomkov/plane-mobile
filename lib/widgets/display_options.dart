import 'package:flutter/material.dart';
import '../config/m3e/shapes.dart';
import '../config/theme.dart';
import '../utils/issue_grouping.dart';
import 'filter_bar.dart';

/// Display options state — shared between My Issues and project issue lists
class DisplayState {
  String grouping;
  String ordering;
  bool sortNewest;
  String completedFilter; // none, week, all
  bool showSubIssues;
  int maxTitleLines;
  Set<String> rowProperties;

  DisplayState({
    this.grouping = 'state',
    this.ordering = 'created',
    this.sortNewest = true,
    this.completedFilter = 'none',
    this.showSubIssues = true,
    this.maxTitleLines = 1,
    Set<String>? rowProperties,
  }) : rowProperties = rowProperties ?? {'status', 'priority', 'id'};

  GroupByField get groupByField => {
        'state': GroupByField.state,
        'priority': GroupByField.priority,
        'assignee': GroupByField.assignee,
        'label': GroupByField.label,
      }[grouping] ??
      GroupByField.state;

  SortField get sortField => {
        'updated': SortField.updatedAt,
        'priority': SortField.priority,
      }[ordering] ??
      SortField.createdAt;
}

/// Shows the Linear-style Display Options bottom sheet.
/// Returns when sheet closes — caller should setState.
Future<void> showDisplayOptions(BuildContext context, DisplayState ds, VoidCallback onChanged) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final theme = Theme.of(ctx);
        final secondary = theme.colorScheme.onSurfaceVariant;

        Widget optionRow(String label, String value, VoidCallback onTap) {
          return InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Text(label, style: const TextStyle(fontSize: PlaneTheme.fontBody)),
                  const Spacer(),
                  Text(value, style: TextStyle(fontSize: PlaneTheme.fontCaption, color: secondary)),
                  const SizedBox(width: 4),
                  Icon(Icons.unfold_more, size: PlaneTheme.iconMedium, color: secondary),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                    child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                            color: secondary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),

                optionRow(
                    'Grouping',
                    ds.grouping[0].toUpperCase() + ds.grouping.substring(1),
                    () {
                  const options = ['state', 'priority', 'assignee', 'label'];
                  final idx = options.indexOf(ds.grouping);
                  setSheetState(() => ds.grouping = options[(idx + 1) % options.length]);
                  onChanged();
                }),

                optionRow(
                    'Ordering',
                    ds.ordering[0].toUpperCase() + ds.ordering.substring(1),
                    () {
                  const options = ['created', 'updated', 'priority'];
                  final idx = options.indexOf(ds.ordering);
                  setSheetState(() => ds.ordering = options[(idx + 1) % options.length]);
                  onChanged();
                }),

                optionRow('Sort', ds.sortNewest ? 'Newest first' : 'Oldest first', () {
                  setSheetState(() => ds.sortNewest = !ds.sortNewest);
                  onChanged();
                }),

                const SizedBox(height: 8),

                optionRow(
                    'Completed issues',
                    ds.completedFilter == 'none'
                        ? 'None'
                        : ds.completedFilter == 'week'
                            ? 'Past week'
                            : 'All', () {
                  const options = ['none', 'week', 'all'];
                  final idx = options.indexOf(ds.completedFilter);
                  setSheetState(
                      () => ds.completedFilter = options[(idx + 1) % options.length]);
                  onChanged();
                }),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      const Text('Show sub-issues',
                          style: TextStyle(fontSize: PlaneTheme.fontBody)),
                      const Spacer(),
                      // The switch sits in a Row next to its caption, so it
                      // would otherwise be an unnamed node for automation.
                      Semantics(
                        label: 'Show sub-issues',
                        child: Switch(
                          value: ds.showSubIssues,
                          onChanged: (v) {
                            setSheetState(() => ds.showSubIssues = v);
                            onChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                optionRow(
                    'Maximum title length',
                    '${ds.maxTitleLines} line${ds.maxTitleLines > 1 ? 's' : ''}',
                    () {
                  setSheetState(() => ds.maxTitleLines = ds.maxTitleLines == 1 ? 2 : 1);
                  onChanged();
                }),

                const SizedBox(height: 12),

                // Row properties
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text('Row properties',
                          style: TextStyle(
                              fontSize: PlaneTheme.fontSection, color: secondary)),
                      const Spacer(),
                      Semantics(
                        label: 'Reset row properties',
                        button: true,
                        child: GestureDetector(
                          onTap: () {
                            setSheetState(
                                () => ds.rowProperties = {'status', 'priority', 'id'});
                            onChanged();
                          },
                          child: Text('Reset',
                              style: TextStyle(
                                  fontSize: PlaneTheme.fontSection, color: secondary)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final prop in [
                        'Status',
                        'Priority',
                        'Assignee',
                        'ID',
                        'Labels',
                        'Project',
                        'Due date',
                        'Cycle',
                        'Estimate'
                      ])
                        _PropChip(
                          label: prop,
                          selected: ds.rowProperties
                              .contains(prop.toLowerCase().replaceAll(' ', '_')),
                          onTap: () {
                            final key = prop.toLowerCase().replaceAll(' ', '_');
                            setSheetState(() {
                              if (ds.rowProperties.contains(key)) {
                                ds.rowProperties.remove(key);
                              } else {
                                ds.rowProperties.add(key);
                              }
                            });
                            onChanged();
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _PropChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PropChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // The chip's own Text is its label; only the on/off state needs exposing,
    // because it is otherwise carried by colour alone.
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.08))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(M3EShape.full),
            border: Border.all(
              color: selected
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.15))
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08)),
            ),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: PlaneTheme.fontSection,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant)),
        ),
      ),
    );
  }
}
