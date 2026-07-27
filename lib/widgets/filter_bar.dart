import 'package:flutter/material.dart';
import '../widgets/label_pill.dart';
import 'm3e/chip.dart';
import 'bottom_sheet_picker.dart';
import '../models/state.dart';
import '../models/label.dart';
import '../models/member.dart';
import '../config/theme.dart';

enum SortField { createdAt, updatedAt, priority }

enum GroupByField { state, priority, assignee, label }

class FilterState {
  final Set<String> selectedStates;
  final Set<String> selectedPriorities;
  final Set<String> selectedAssignees;
  final Set<String> selectedLabels;
  final SortField sortField;
  final bool sortAscending;
  final GroupByField groupBy;

  const FilterState({
    this.selectedStates = const {},
    this.selectedPriorities = const {},
    this.selectedAssignees = const {},
    this.selectedLabels = const {},
    this.sortField = SortField.createdAt,
    this.sortAscending = false,
    this.groupBy = GroupByField.state,
  });

  FilterState copyWith({
    Set<String>? selectedStates,
    Set<String>? selectedPriorities,
    Set<String>? selectedAssignees,
    Set<String>? selectedLabels,
    SortField? sortField,
    bool? sortAscending,
    GroupByField? groupBy,
  }) {
    return FilterState(
      selectedStates: selectedStates ?? this.selectedStates,
      selectedPriorities: selectedPriorities ?? this.selectedPriorities,
      selectedAssignees: selectedAssignees ?? this.selectedAssignees,
      selectedLabels: selectedLabels ?? this.selectedLabels,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      groupBy: groupBy ?? this.groupBy,
    );
  }

  bool get hasActiveFilters =>
      selectedStates.isNotEmpty ||
      selectedPriorities.isNotEmpty ||
      selectedAssignees.isNotEmpty ||
      selectedLabels.isNotEmpty;

  int get activeFilterCount =>
      (selectedStates.isNotEmpty ? 1 : 0) +
      (selectedPriorities.isNotEmpty ? 1 : 0) +
      (selectedAssignees.isNotEmpty ? 1 : 0) +
      (selectedLabels.isNotEmpty ? 1 : 0);
}

class FilterBar extends StatelessWidget {
  final FilterState filterState;
  final Map<String, IssueState> states;
  final List<Label> labels;
  final List<Member> members;
  final ValueChanged<FilterState> onFilterChanged;
  final VoidCallback? onSaveAsView;

  const FilterBar({
    super.key,
    required this.filterState,
    required this.states,
    required this.labels,
    required this.members,
    required this.onFilterChanged,
    this.onSaveAsView,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      // Chips are stretched to the bar's height by the horizontal ListView, so
      // this is also their touch target — hence 48 rather than a tidier 40.
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildFilterChip(
            context: context,
            label: 'State',
            icon: Icons.circle_outlined,
            activeCount: filterState.selectedStates.length,
            onTap: () => _showStateFilter(context),
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            context: context,
            label: 'Priority',
            icon: Icons.signal_cellular_alt,
            activeCount: filterState.selectedPriorities.length,
            onTap: () => _showPriorityFilter(context),
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            context: context,
            label: 'Assignee',
            icon: Icons.person_outline,
            activeCount: filterState.selectedAssignees.length,
            onTap: () => _showAssigneeFilter(context),
          ),
          const SizedBox(width: 6),
          _buildFilterChip(
            context: context,
            label: 'Label',
            icon: Icons.label_outline,
            activeCount: filterState.selectedLabels.length,
            onTap: () => _showLabelFilter(context),
          ),
          const SizedBox(width: 6),
          _buildActionChip(
            context: context,
            label: _sortLabel,
            action: 'Change sort order',
            icon: filterState.sortAscending
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            onTap: () => _showSortOptions(context),
          ),
          const SizedBox(width: 6),
          _buildActionChip(
            context: context,
            label: _groupByLabel,
            action: 'Change grouping',
            icon: Icons.view_agenda_outlined,
            onTap: () => _showGroupByOptions(context),
          ),
          if (filterState.hasActiveFilters) ...[
            const SizedBox(width: 6),
            if (onSaveAsView != null)
              M3EChip(
                label: 'Save as view',
                icon: Icons.save_outlined,
                dense: true,
                selected: true,
                onTap: onSaveAsView,
              ),
            const SizedBox(width: 6),
            Semantics(
              label: 'Clear all filters',
              button: true,
              // See _buildFilterChip: an explicit label only replaces the
              // chip's own text if the subtree is excluded.
              container: true,
              excludeSemantics: true,
              onTap: () => onFilterChanged(_cleared),
              child: M3EChip(
                label: 'Clear',
                dense: true,
                selected: true,
                accentColor: theme.colorScheme.error,
                onTap: () => onFilterChanged(_cleared),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The four filter sets emptied, and nothing else touched.
  ///
  /// Clear used to hand back `const FilterState()`, which also put sorting
  /// back to "Created at, descending" and grouping back to State. The chip
  /// says "Clear" beside four filter chips, appears only when a filter is on,
  /// and is labelled "Clear all filters" — three statements that it clears
  /// filters. Ordering is not a filter.
  FilterState get _cleared => filterState.copyWith(
        selectedStates: const {},
        selectedPriorities: const {},
        selectedAssignees: const {},
        selectedLabels: const {},
      );

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required int activeCount,
    required VoidCallback onTap,
  }) {
    // The active count rides in the chip's badge rather than in the label, so
    // the label stays a stable width as filters are added and removed.
    // The visible text is just the dimension ("State"), which does not say what
    // tapping does, and the active/inactive state is carried by colour alone —
    // both are spelled out here for screen readers and uiautomator.
    //
    // A bare `Semantics(label:)` *appends* — both this label and the chip's own
    // "State" reach the tree, so a screen reader says "Filter by State, State"
    // and `adb_drive.py tap "State"` matches two nodes. Excluding the subtree
    // is what makes the label a replacement, exactly as `M3EPressable` does
    // when it is given one; the tap has to be re-declared here because
    // excluding drops the child's gesture along with its text.
    return Semantics(
      label: 'Filter by $label',
      button: true,
      selected: activeCount > 0,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: M3EChip(
        label: label,
        icon: icon,
        dense: true,
        selected: activeCount > 0,
        count: activeCount,
        onTap: onTap,
      ),
    );
  }

  Widget _buildActionChip({
    required BuildContext context,
    required String label,
    required String action,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    // The chip shows the *current* value ("Created"), so the action it performs
    // has to be named separately.
    return Semantics(
      label: action,
      button: true,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: M3EChip(
        label: label,
        icon: icon,
        dense: true,
        onTap: onTap,
      ),
    );
  }

  String get _sortLabel {
    switch (filterState.sortField) {
      case SortField.createdAt:
        return 'Created';
      case SortField.updatedAt:
        return 'Updated';
      case SortField.priority:
        return 'Priority';
    }
  }

  String get _groupByLabel {
    switch (filterState.groupBy) {
      case GroupByField.state:
        return 'State';
      case GroupByField.priority:
        return 'Priority';
      case GroupByField.assignee:
        return 'Assignee';
      case GroupByField.label:
        return 'Label';
    }
  }

  Future<void> _showStateFilter(BuildContext context) async {
    final chosen = await MultiSelectSheet.show<String>(
      context: context,
      title: 'Filter by State',
      selected: filterState.selectedStates,
      emptyMessage: 'This project has no states',
      items: [
        for (final s in states.values)
          BottomSheetPickerItem(
            value: s.id,
            label: s.name,
            icon: PlaneTheme.stateIcon(s.group),
            iconColor: PlaneTheme.stateGroupColor(context, s.group),
          ),
      ],
    );
    if (chosen != null) {
      onFilterChanged(filterState.copyWith(selectedStates: chosen));
    }
  }

  Future<void> _showPriorityFilter(BuildContext context) async {
    const priorities = ['urgent', 'high', 'medium', 'low', 'none'];
    final chosen = await MultiSelectSheet.show<String>(
      context: context,
      title: 'Filter by Priority',
      selected: filterState.selectedPriorities,
      items: [
        for (final p in priorities)
          BottomSheetPickerItem(
            value: p,
            label: p[0].toUpperCase() + p.substring(1),
            icon: PlaneTheme.priorityIcon(p),
            iconColor: PlaneTheme.priorityColor(context, p),
          ),
      ],
    );
    if (chosen != null) {
      onFilterChanged(filterState.copyWith(selectedPriorities: chosen));
    }
  }

  Future<void> _showAssigneeFilter(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final labelSmall = Theme.of(context).textTheme.labelSmall;
    final chosen = await MultiSelectSheet.show<String>(
      context: context,
      title: 'Filter by Assignee',
      selected: filterState.selectedAssignees,
      emptyMessage: 'No members',
      items: [
        for (final m in members)
          BottomSheetPickerItem(
            value: m.id,
            label: m.displayName,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: scheme.primary.withValues(alpha: 0.2),
              child: Text(
                (m.displayName.isNotEmpty ? m.displayName : '?')[0]
                    .toUpperCase(),
                style: labelSmall?.copyWith(color: scheme.primary),
              ),
            ),
          ),
      ],
    );
    if (chosen != null) {
      onFilterChanged(filterState.copyWith(selectedAssignees: chosen));
    }
  }

  Future<void> _showLabelFilter(BuildContext context) async {
    final chosen = await MultiSelectSheet.show<String>(
      context: context,
      title: 'Filter by Label',
      selected: filterState.selectedLabels,
      emptyMessage: 'No labels',
      items: [
        for (final l in labels)
          BottomSheetPickerItem(
            value: l.id,
            label: l.name,
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: parseHexColor(l.color,
                    fallback: Theme.of(context).colorScheme.outline),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
    if (chosen != null) {
      onFilterChanged(filterState.copyWith(selectedLabels: chosen));
    }
  }

  Future<void> _showSortOptions(BuildContext context) async {
    final chosen = await BottomSheetPicker.show<SortField>(
      context: context,
      title: 'Sort by',
      // The one thing the old sheet never said: choosing the field you are
      // already sorted by reverses it. Three rows with a check and no
      // explanation left that a discovery.
      subtitle: filterState.sortAscending
          ? 'Ascending — choose $_sortLabel again to reverse'
          : 'Descending — choose $_sortLabel again to reverse',
      selectedValue: filterState.sortField,
      items: const [
        BottomSheetPickerItem(
            value: SortField.createdAt,
            label: 'Created at',
            icon: Icons.calendar_today),
        BottomSheetPickerItem(
            value: SortField.updatedAt,
            label: 'Updated at',
            icon: Icons.update),
        BottomSheetPickerItem(
            value: SortField.priority,
            label: 'Priority',
            icon: Icons.flag_outlined),
      ],
    );
    if (chosen == null) return;
    onFilterChanged(filterState.copyWith(
      sortField: chosen,
      sortAscending:
          chosen == filterState.sortField ? !filterState.sortAscending : false,
    ));
  }

  Future<void> _showGroupByOptions(BuildContext context) async {
    final chosen = await BottomSheetPicker.show<GroupByField>(
      context: context,
      title: 'Group by',
      selectedValue: filterState.groupBy,
      items: const [
        BottomSheetPickerItem(
            value: GroupByField.state,
            label: 'State',
            icon: Icons.circle_outlined),
        BottomSheetPickerItem(
            value: GroupByField.priority,
            label: 'Priority',
            icon: Icons.flag_outlined),
        BottomSheetPickerItem(
            value: GroupByField.assignee,
            label: 'Assignee',
            icon: Icons.person_outline),
        BottomSheetPickerItem(
            value: GroupByField.label,
            label: 'Label',
            icon: Icons.label_outline),
      ],
    );
    if (chosen != null) {
      onFilterChanged(filterState.copyWith(groupBy: chosen));
    }
  }
}
