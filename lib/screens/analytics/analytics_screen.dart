import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../services/project_service.dart';
import '../../services/issue_service.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../widgets/loading_state.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  const AnalyticsScreen({super.key, required this.workspaceSlug});

  @override
  ConsumerState<AnalyticsScreen> createState() =>
      _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  bool _loading = true;
  String? _error;

  int _totalAssigned = 0;
  int _completed = 0;
  int _pending = 0;
  int _overdue = 0;

  Map<String, int> _byPriority = {};
  Map<String, int> _byStateGroup = {};
  List<Issue> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final projects =
          await ProjectService.getProjects(widget.workspaceSlug);
      final allIssues = <Issue>[];
      final allStates = <String, IssueState>{};

      for (final p in projects.take(5)) {
        try {
          final states =
              await IssueService.getStates(widget.workspaceSlug, p.id);
          for (final s in states) {
            allStates[s.id] = s;
          }
          final result = await IssueService.getIssues(
            widget.workspaceSlug,
            p.id,
            orderBy: '-updated_at',
          );
          allIssues.addAll(result['issues'] as List<Issue>);
        } catch (_) {}
      }

      // Compute analytics
      int completed = 0;
      int pending = 0;
      int overdue = 0;
      final byPriority = <String, int>{};
      final byStateGroup = <String, int>{};

      for (final issue in allIssues) {
        // Priority
        byPriority[issue.priority] =
            (byPriority[issue.priority] ?? 0) + 1;

        // State group
        final state = allStates[issue.state];
        final group = state?.group ?? 'backlog';
        byStateGroup[group] = (byStateGroup[group] ?? 0) + 1;

        if (group == 'completed') {
          completed++;
        } else if (group == 'cancelled') {
          // don't count as pending
        } else {
          pending++;
        }

        if (issue.isOverdue &&
            group != 'completed' &&
            group != 'cancelled') {
          overdue++;
        }
      }

      allIssues.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      setState(() {
        _totalAssigned = allIssues.length;
        _completed = completed;
        _pending = pending;
        _overdue = overdue;
        _byPriority = byPriority;
        _byStateGroup = byStateGroup;
        _recentActivity = allIssues.take(10).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: _loading
          ? const LoadingStateWidget()
          : _error != null
              ? ErrorStateWidget(
                  message: 'Failed to load analytics', onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildOverviewCards(theme),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Issues by Priority', theme),
                      const SizedBox(height: 12),
                      _buildBarChart(_byPriority, _priorityColor, theme),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Issues by State', theme),
                      const SizedBox(height: 12),
                      _buildBarChart(
                          _byStateGroup, _stateGroupColor, theme),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Recent Activity', theme),
                      const SizedBox(height: 12),
                      ..._recentActivity
                          .map((i) => _buildActivityItem(i, theme)),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildOverviewCards(ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
            label: 'Total Issues',
            value: '$_totalAssigned',
            color: theme.colorScheme.primary),
        _StatCard(
            label: 'Completed',
            value: '$_completed',
            color: PlaneTheme.completed),
        _StatCard(
            label: 'Pending',
            value: '$_pending',
            color: PlaneTheme.started),
        _StatCard(
            label: 'Overdue',
            value: '$_overdue',
            color: PlaneTheme.urgent),
      ],
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(title,
        style: TextStyle(
            fontSize: PlaneTheme.fontBody,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface));
  }

  Widget _buildBarChart(Map<String, int> data,
      Color Function(String) colorFn, ThemeData theme) {
    if (data.isEmpty) {
      return Text('No data',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant));
    }
    final maxValue =
        data.values.fold<int>(0, (a, b) => a > b ? a : b).toDouble();
    if (maxValue == 0) return const SizedBox.shrink();

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sortedEntries.map((entry) {
        final ratio = entry.value / maxValue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  _capitalize(entry.key),
                  style: TextStyle(
                      fontSize: PlaneTheme.fontSection,
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    return Container(
                      height: 24,
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: constraints.maxWidth * ratio,
                        height: 24,
                        decoration: BoxDecoration(
                          color: colorFn(entry.key),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                child: Text('${entry.value}',
                    style: TextStyle(
                        fontSize: PlaneTheme.fontSection,
                        fontWeight: PlaneTheme.fontSectionWeight,
                        color: theme.colorScheme.onSurface)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivityItem(Issue issue, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(
              color: theme.colorScheme.outline, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(PlaneTheme.priorityIcon(issue.priority),
                size: PlaneTheme.iconMedium,
                color: PlaneTheme.priorityColor(issue.priority)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(issue.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: PlaneTheme.fontSection)),
            ),
            const SizedBox(width: 8),
            Text(
              _shortDate(issue.updatedAt),
              style: TextStyle(
                  fontSize: PlaneTheme.fontSmall,
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(String priority) {
    return PlaneTheme.priorityColor(priority);
  }

  Color _stateGroupColor(String group) {
    return PlaneTheme.stateGroupColor(group);
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _shortDate(DateTime dt) {
    return '${dt.day}/${dt.month}';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: PlaneTheme.fontTitle,
                  fontWeight: PlaneTheme.fontTitleWeight,
                  color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: PlaneTheme.fontSection,
                  color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
