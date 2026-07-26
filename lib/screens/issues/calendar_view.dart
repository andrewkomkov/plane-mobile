import 'package:flutter/material.dart';
import '../../config/m3e/shapes.dart';
import '../../config/m3e/typography.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../widgets/issue_row.dart';
import '../../widgets/plane_row.dart';
import '../../models/label.dart';
import '../../models/member.dart';
import 'issue_detail_screen.dart';

class CalendarView extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final String projectIdentifier;
  final List<Issue> issues;
  final Map<String, IssueState> states;
  final List<Label> allLabels;
  final List<Member> allMembers;
  final VoidCallback onRefresh;

  const CalendarView({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.projectIdentifier,
    required this.issues,
    required this.states,
    required this.onRefresh,
    this.allLabels = const [],
    this.allMembers = const [],
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _currentMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  Map<String, List<Issue>> get _issuesByDate {
    final map = <String, List<Issue>>{};
    for (final issue in widget.issues) {
      final date = issue.targetDate;
      if (date != null && date.isNotEmpty) {
        map.putIfAbsent(date, () => []);
        map[date]!.add(issue);
      }
    }
    return map;
  }

  List<Issue> get _noDateIssues {
    return widget.issues
        .where((i) => i.targetDate == null || i.targetDate!.isEmpty)
        .toList();
  }

  List<Issue> get _selectedDayIssues {
    if (_selectedDay == null) return [];
    final key = _formatDate(_selectedDay!);
    return _issuesByDate[key] ?? [];
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    return Column(
      children: [
        // Month navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              M3EIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Previous month',
                onPressed: () {
                  setState(() {
                    _currentMonth =
                        DateTime(_currentMonth.year, _currentMonth.month - 1);
                    _selectedDay = null;
                  });
                },
              ),
              Text(
                '${_monthName(_currentMonth.month)} ${_currentMonth.year}',
                style: theme.textTheme.titleMedium,
              ),
              M3EIconButton(
                icon: Icons.chevron_right,
                tooltip: 'Next month',
                onPressed: () {
                  setState(() {
                    _currentMonth =
                        DateTime(_currentMonth.year, _currentMonth.month + 1);
                    _selectedDay = null;
                  });
                },
              ),
            ],
          ),
        ),
        // Day of week headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: secondary)),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 4),
        // Calendar grid
        _buildCalendarGrid(theme, secondary),
        const Divider(height: 1),
        // Selected day issues or no-date issues
        Expanded(
          child: _buildIssueList(theme, secondary),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(ThemeData theme, Color secondary) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    // Monday = 1, Sunday = 7
    final startWeekday = firstDay.weekday; // 1 = Monday
    final totalCells = ((startWeekday - 1) + daysInMonth);
    final rows = (totalCells / 7).ceil();
    final issuesByDate = _issuesByDate;
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final dayNum = cellIndex - (startWeekday - 1) + 1;

              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox(height: 48));
              }

              final date =
                  DateTime(_currentMonth.year, _currentMonth.month, dayNum);
              final dateKey = _formatDate(date);
              final issueCount = issuesByDate[dateKey]?.length ?? 0;
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected = _selectedDay != null &&
                  date.year == _selectedDay!.year &&
                  date.month == _selectedDay!.month &&
                  date.day == _selectedDay!.day;

              return Expanded(
                // The cell renders a bare number, which is useless as a name:
                // the label carries the full date and the issue count so a
                // day can be picked out without reading the grid geometry.
                child: Semantics(
                  label: issueCount > 0
                      ? 'Select day $dateKey, $issueCount issues'
                      : 'Select day $dateKey, no issues',
                  button: true,
                  selected: isSelected,
                  container: true,
                  // The cell draws the day number and the count, both of which
                  // the label already carries; without the exclusion the node
                  // reads "Select day 2026-07-14, 3 issues, 14, 3". The tap is
                  // re-declared because excluding drops the child's.
                  excludeSemantics: true,
                  onTap: () => setState(() => _selectedDay = date),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDay = date),
                    child: Container(
                      // A day cell is a tap target, so it holds the 48dp
                      // minimum even though the number inside is small.
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(M3EShape.medium),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: isToday
                                ? BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  )
                                : null,
                            alignment: Alignment.center,
                            child: Text(
                              '$dayNum',
                              // Today is the one day that has to dominate the
                              // grid, which is what the emphasized cut is for.
                              style: (isToday
                                      ? M3EType.emphasized(
                                          theme.textTheme.labelMedium!)
                                      : theme.textTheme.bodySmall!)
                                  .copyWith(
                                color: isToday
                                    // Dark `primary` is a light lavender, so
                                    // white on it is 1.70:1. Roles come in
                                    // pairs for exactly this reason.
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (issueCount > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildIssueList(ThemeData theme, Color secondary) {
    if (_selectedDay != null) {
      final issues = _selectedDayIssues;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '${_formatDate(_selectedDay!)} (${issues.length} issues)',
              style: theme.textTheme.titleSmall?.copyWith(color: secondary),
            ),
          ),
          Expanded(
            child: issues.isEmpty
                ? Center(
                    child: Text('No issues due this day',
                        style: theme.textTheme.bodySmall),
                  )
                : ListView.builder(
                    itemCount: issues.length,
                    itemBuilder: (ctx, i) {
                      final issue = issues[i];
                      return IssueRow(
                        issue: issue,
                        state: widget.states[issue.state],
                        identifier: widget.projectIdentifier,
                        // The month grid already owns most of the screen, so
                        // the day list drops the card fill and tightens up. It
                        // is the same row, one density down.
                        density: PlaneRowDensity.compact,
                        showLabels: true,
                        showSubIssues: true,
                        showAssignee: true,
                        showDueDate: true,
                        allLabels: widget.allLabels,
                        allMembers: widget.allMembers,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => IssueDetailScreen(
                                workspaceSlug: widget.workspaceSlug,
                                projectId: widget.projectId,
                                issueId: issue.id,
                                states: widget.states,
                              ),
                            ),
                          );
                          widget.onRefresh();
                        },
                      );
                    },
                  ),
          ),
        ],
      );
    }

    // Show "No date" issues by default
    final noDate = _noDateIssues;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'No date (${noDate.length} issues)',
            style: theme.textTheme.titleSmall?.copyWith(color: secondary),
          ),
        ),
        Expanded(
          child: noDate.isEmpty
              ? Center(
                  child: Text('All issues have dates',
                      style: theme.textTheme.bodySmall),
                )
              : ListView.builder(
                  itemCount: noDate.length,
                  itemBuilder: (ctx, i) {
                    final issue = noDate[i];
                    return IssueRow(
                      issue: issue,
                      state: widget.states[issue.state],
                      identifier: widget.projectIdentifier,
                      density: PlaneRowDensity.compact,
                      showLabels: true,
                      showSubIssues: true,
                      showAssignee: true,
                      showDueDate: true,
                      allLabels: widget.allLabels,
                      allMembers: widget.allMembers,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => IssueDetailScreen(
                              workspaceSlug: widget.workspaceSlug,
                              projectId: widget.projectId,
                              issueId: issue.id,
                              states: widget.states,
                            ),
                          ),
                        );
                        widget.onRefresh();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _monthName(int month) {
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return names[month];
  }
}
