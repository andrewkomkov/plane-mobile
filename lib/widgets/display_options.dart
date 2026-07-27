import 'package:flutter/material.dart';
import 'sheet_header.dart';
import 'bottom_sheet_picker.dart';
import '../config/m3e/motion.dart';
import '../config/theme.dart';
import 'filter_bar.dart';
import 'm3e/chip.dart';

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

  GroupByField get groupByField =>
      {
        'state': GroupByField.state,
        'priority': GroupByField.priority,
        'assignee': GroupByField.assignee,
        'label': GroupByField.label,
      }[grouping] ??
      GroupByField.state;

  SortField get sortField =>
      {
        'updated': SortField.updatedAt,
        'priority': SortField.priority,
      }[ordering] ??
      SortField.createdAt;
}

/// Shows the Linear-style Display Options bottom sheet.
/// Returns when sheet closes — caller should setState.
Future<void> showDisplayOptions(
    BuildContext context, DisplayState ds, VoidCallback onChanged) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final theme = Theme.of(ctx);
        final secondary = theme.colorScheme.onSurfaceVariant;

        /// Opens the shared picker and applies what comes back.
        ///
        /// These rows used to cycle: each tap advanced to the next value and
        /// the only way to see the options was to keep tapping past the one
        /// you wanted. Four settings, none of which ever showed its own range.
        Future<void> choose<T>({
          required String title,
          required T current,
          required List<BottomSheetPickerItem<T>> items,
          required void Function(T value) apply,
        }) async {
          final chosen = await BottomSheetPicker.show<T>(
            context: ctx,
            title: title,
            selectedValue: current,
            items: items,
          );
          if (chosen == null || chosen == current) return;
          setSheetState(() => apply(chosen));
          onChanged();
        }

        Widget optionRow(String label, String value, VoidCallback onTap) {
          return M3EPressable(
            pressedScale: 0.98,
            onTap: onTap,
            // The row draws two strings in two roles; the node has to say
            // both, and say which setting it is.
            semanticLabel: '$label, $value',
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Text(label, style: theme.textTheme.bodyLarge),
                  const Spacer(),
                  Text(value, style: theme.textTheme.bodySmall),
                  const SizedBox(width: 4),
                  Icon(Icons.unfold_more,
                      size: PlaneTheme.iconMedium, color: secondary),
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
                // No hand-rolled drag handle: `bottomSheetTheme` draws one.
                // This sheet also had no header at all, which made it the one
                // surface in the app that opened without saying what it was.
                const SheetHeader(title: 'Display options'),

                optionRow('Grouping',
                    ds.grouping[0].toUpperCase() + ds.grouping.substring(1),
                    () {
                  choose<String>(
                    title: 'Grouping',
                    current: ds.grouping,
                    items: const [
                      BottomSheetPickerItem(
                          value: 'state',
                          label: 'State',
                          icon: Icons.circle_outlined),
                      BottomSheetPickerItem(
                          value: 'priority',
                          label: 'Priority',
                          icon: Icons.flag_outlined),
                      BottomSheetPickerItem(
                          value: 'assignee',
                          label: 'Assignee',
                          icon: Icons.person_outline),
                      BottomSheetPickerItem(
                          value: 'label',
                          label: 'Label',
                          icon: Icons.label_outline),
                    ],
                    apply: (v) => ds.grouping = v,
                  );
                }),

                optionRow('Ordering',
                    ds.ordering[0].toUpperCase() + ds.ordering.substring(1),
                    () {
                  choose<String>(
                    title: 'Ordering',
                    current: ds.ordering,
                    items: const [
                      BottomSheetPickerItem(
                          value: 'created',
                          label: 'Created',
                          icon: Icons.calendar_today),
                      BottomSheetPickerItem(
                          value: 'updated',
                          label: 'Updated',
                          icon: Icons.update),
                      BottomSheetPickerItem(
                          value: 'priority',
                          label: 'Priority',
                          icon: Icons.flag_outlined),
                    ],
                    apply: (v) => ds.ordering = v,
                  );
                }),

                optionRow(
                    'Sort', ds.sortNewest ? 'Newest first' : 'Oldest first',
                    () {
                  choose<bool>(
                    title: 'Sort',
                    current: ds.sortNewest,
                    items: const [
                      BottomSheetPickerItem(
                          value: true,
                          label: 'Newest first',
                          icon: Icons.arrow_downward),
                      BottomSheetPickerItem(
                          value: false,
                          label: 'Oldest first',
                          icon: Icons.arrow_upward),
                    ],
                    apply: (v) => ds.sortNewest = v,
                  );
                }),

                const SizedBox(height: 8),

                optionRow(
                    'Completed issues',
                    ds.completedFilter == 'none'
                        ? 'None'
                        : ds.completedFilter == 'week'
                            ? 'Past week'
                            : 'All', () {
                  choose<String>(
                    title: 'Completed issues',
                    current: ds.completedFilter,
                    items: const [
                      BottomSheetPickerItem(
                          value: 'none',
                          label: 'None',
                          subtitle: 'Hide everything already done',
                          icon: Icons.visibility_off_outlined),
                      BottomSheetPickerItem(
                          value: 'week',
                          label: 'Past week',
                          subtitle: 'Completed in the last seven days',
                          icon: Icons.history),
                      BottomSheetPickerItem(
                          value: 'all',
                          label: 'All',
                          icon: Icons.visibility_outlined),
                    ],
                    apply: (v) => ds.completedFilter = v,
                  );
                }),

                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      Text('Show sub-issues', style: theme.textTheme.bodyLarge),
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

                optionRow('Maximum title length',
                    '${ds.maxTitleLines} line${ds.maxTitleLines > 1 ? 's' : ''}',
                    () {
                  choose<int>(
                    title: 'Maximum title length',
                    current: ds.maxTitleLines,
                    items: const [
                      BottomSheetPickerItem(value: 1, label: '1 line'),
                      BottomSheetPickerItem(value: 2, label: '2 lines'),
                    ],
                    apply: (v) => ds.maxTitleLines = v,
                  );
                }),

                const SizedBox(height: 12),

                // Row properties
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text('Row properties',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(color: secondary)),
                      const Spacer(),
                      // A TextButton rather than a tapped Text: it carries the
                      // 48dp target and the label for free, which the bare
                      // GestureDetector here did not.
                      TextButton(
                        onPressed: () {
                          setSheetState(() =>
                              ds.rowProperties = {'status', 'priority', 'id'});
                          onChanged();
                        },
                        child: Text('Reset',
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: secondary)),
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
                        M3EChip(
                          label: prop,
                          selected: ds.rowProperties.contains(
                              prop.toLowerCase().replaceAll(' ', '_')),
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
