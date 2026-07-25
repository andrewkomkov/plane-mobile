import 'package:flutter/material.dart';
import 'm3e/chip.dart';
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
      height: 40,
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
              child: M3EChip(
                label: 'Clear',
                dense: true,
                selected: true,
                accentColor: theme.colorScheme.error,
                onTap: () => onFilterChanged(const FilterState()),
              ),
            ),
          ],
        ],
      ),
    );
  }

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
    return Semantics(
      label: 'Filter by $label',
      button: true,
      selected: activeCount > 0,
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

  void _showStateFilter(BuildContext context) {
    final selected = Set<String>.from(filterState.selectedStates);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHeader(ctx, 'Filter by State', () {
                Navigator.pop(ctx);
                onFilterChanged(
                    filterState.copyWith(selectedStates: selected));
              }),
              ...states.values.map((s) => CheckboxListTile(
                    value: selected.contains(s.id),
                    onChanged: (v) {
                      setSheetState(() {
                        if (v == true) {
                          selected.add(s.id);
                        } else {
                          selected.remove(s.id);
                        }
                      });
                    },
                    secondary: Icon(PlaneTheme.stateIcon(s.group),
                        color: PlaneTheme.stateGroupColor(s.group), size: 18),
                    title:
                        Text(s.name, style: const TextStyle(fontSize: PlaneTheme.fontBody)),
                    controlAffinity: ListTileControlAffinity.trailing,
                    dense: true,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showPriorityFilter(BuildContext context) {
    final selected = Set<String>.from(filterState.selectedPriorities);
    final priorities = ['urgent', 'high', 'medium', 'low', 'none'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHeader(ctx, 'Filter by Priority', () {
                Navigator.pop(ctx);
                onFilterChanged(
                    filterState.copyWith(selectedPriorities: selected));
              }),
              ...priorities.map((p) => CheckboxListTile(
                    value: selected.contains(p),
                    onChanged: (v) {
                      setSheetState(() {
                        if (v == true) {
                          selected.add(p);
                        } else {
                          selected.remove(p);
                        }
                      });
                    },
                    secondary: Icon(PlaneTheme.priorityIcon(p),
                        color: PlaneTheme.priorityColor(p), size: 18),
                    title: Text(p[0].toUpperCase() + p.substring(1),
                        style: const TextStyle(fontSize: PlaneTheme.fontBody)),
                    controlAffinity: ListTileControlAffinity.trailing,
                    dense: true,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssigneeFilter(BuildContext context) {
    final selected = Set<String>.from(filterState.selectedAssignees);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHeader(ctx, 'Filter by Assignee', () {
                Navigator.pop(ctx);
                onFilterChanged(
                    filterState.copyWith(selectedAssignees: selected));
              }),
              if (members.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No members', style: TextStyle(fontSize: PlaneTheme.fontSection)),
                ),
              ...members.map((m) => CheckboxListTile(
                    value: selected.contains(m.id),
                    onChanged: (v) {
                      setSheetState(() {
                        if (v == true) {
                          selected.add(m.id);
                        } else {
                          selected.remove(m.id);
                        }
                      });
                    },
                    secondary: CircleAvatar(
                      radius: 14,
                      backgroundColor: Theme.of(ctx)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2),
                      child: Text(
                        (m.displayName.isNotEmpty ? m.displayName : '?')[0]
                            .toUpperCase(),
                        style: TextStyle(
                            fontSize: PlaneTheme.fontSmall,
                            color: Theme.of(ctx).colorScheme.primary),
                      ),
                    ),
                    title: Text(m.displayName,
                        style: const TextStyle(fontSize: PlaneTheme.fontBody)),
                    controlAffinity: ListTileControlAffinity.trailing,
                    dense: true,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showLabelFilter(BuildContext context) {
    final selected = Set<String>.from(filterState.selectedLabels);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHeader(ctx, 'Filter by Label', () {
                Navigator.pop(ctx);
                onFilterChanged(
                    filterState.copyWith(selectedLabels: selected));
              }),
              if (labels.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No labels', style: TextStyle(fontSize: PlaneTheme.fontSection)),
                ),
              ...labels.map((l) => CheckboxListTile(
                    value: selected.contains(l.id),
                    onChanged: (v) {
                      setSheetState(() {
                        if (v == true) {
                          selected.add(l.id);
                        } else {
                          selected.remove(l.id);
                        }
                      });
                    },
                    secondary: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _parseColor(l.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title:
                        Text(l.name, style: const TextStyle(fontSize: PlaneTheme.fontBody)),
                    controlAffinity: ListTileControlAffinity.trailing,
                    dense: true,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sort by',
                  style:
                      TextStyle(fontSize: PlaneTheme.fontBody, fontWeight: FontWeight.w500)),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today, size: 20),
              title: const Text('Created at',
                  style: TextStyle(fontSize: PlaneTheme.fontBody)),
              trailing: filterState.sortField == SortField.createdAt
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                final asc = filterState.sortField == SortField.createdAt
                    ? !filterState.sortAscending
                    : false;
                onFilterChanged(filterState.copyWith(
                    sortField: SortField.createdAt, sortAscending: asc));
              },
            ),
            ListTile(
              leading: const Icon(Icons.update, size: 20),
              title: const Text('Updated at',
                  style: TextStyle(fontSize: PlaneTheme.fontBody)),
              trailing: filterState.sortField == SortField.updatedAt
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                final asc = filterState.sortField == SortField.updatedAt
                    ? !filterState.sortAscending
                    : false;
                onFilterChanged(filterState.copyWith(
                    sortField: SortField.updatedAt, sortAscending: asc));
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, size: 20),
              title: const Text('Priority',
                  style: TextStyle(fontSize: PlaneTheme.fontBody)),
              trailing: filterState.sortField == SortField.priority
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                final asc = filterState.sortField == SortField.priority
                    ? !filterState.sortAscending
                    : false;
                onFilterChanged(filterState.copyWith(
                    sortField: SortField.priority, sortAscending: asc));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupByOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Group by',
                  style:
                      TextStyle(fontSize: PlaneTheme.fontBody, fontWeight: FontWeight.w500)),
            ),
            ListTile(
              leading: const Icon(Icons.circle_outlined, size: 20),
              title:
                  const Text('State', style: TextStyle(fontSize: PlaneTheme.fontBody)),
              trailing: filterState.groupBy == GroupByField.state
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                onFilterChanged(
                    filterState.copyWith(groupBy: GroupByField.state));
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, size: 20),
              title:
                  const Text('Priority', style: TextStyle(fontSize: PlaneTheme.fontBody)),
              trailing: filterState.groupBy == GroupByField.priority
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                onFilterChanged(
                    filterState.copyWith(groupBy: GroupByField.priority));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, size: 20),
              title:
                  const Text('Assignee', style: TextStyle(fontSize: PlaneTheme.fontBody)),
              trailing: filterState.groupBy == GroupByField.assignee
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                onFilterChanged(
                    filterState.copyWith(groupBy: GroupByField.assignee));
              },
            ),
            ListTile(
              leading: const Icon(Icons.label_outline, size: 20),
              title:
                  const Text('Label', style: TextStyle(fontSize: PlaneTheme.fontBody)),
              trailing: filterState.groupBy == GroupByField.label
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                onFilterChanged(
                    filterState.copyWith(groupBy: GroupByField.label));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetHeader(BuildContext ctx, String title, VoidCallback onDone) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: PlaneTheme.fontBody, fontWeight: FontWeight.w500)),
          const Spacer(),
          TextButton(onPressed: onDone, child: const Text('Done')),
        ],
      ),
    );
  }

  static Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF999999);
  }
}
