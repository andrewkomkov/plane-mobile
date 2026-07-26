import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/m3e/shapes.dart';
import '../../config/m3e/typography.dart';
import '../../config/theme.dart';
import '../../models/analytics.dart';
import '../../services/analytics_service.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/app_bar.dart';

/// Workspace analytics.
///
/// The screen used to fetch one page of work items from the first five
/// projects and count those, which made every figure a function of how much the
/// app happened to have loaded — right on a toy workspace, quietly wrong on a
/// real one. It now sweeps every project to the last page (see
/// `AnalyticsService`) and says out loud where each number comes from.
///
/// It does *not* call Plane's analytics API, and not for want of trying: those
/// endpoints are session-authenticated internal routes, and this app holds an
/// API token for `/api/v1/`, which has no analytics module. `models/analytics.dart`
/// carries the full trace. The one figure the server does compute is the work
/// item total, which the paginated list reports as `total_count`; the rest is
/// counted here, over everything fetched, with the coverage on screen.
///
/// The old "recent activity" list went with the rewrite. It was the same
/// partial fetch sorted by update time — not the workspace's recent activity,
/// only five projects' first pages — and it is not an analytic. Per-project
/// state breakdowns took its place.
class AnalyticsScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  const AnalyticsScreen({super.key, required this.workspaceSlug});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  bool _loading = true;
  String? _error;
  WorkspaceAnalytics? _data;

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
      final data =
          await AnalyticsService.getWorkspaceAnalytics(widget.workspaceSlug);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const M3EAppBar(title: 'Analytics'),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const LoadingStateWidget();

    if (_error != null) {
      return ErrorStateWidget(
        message: 'Failed to load analytics',
        onRetry: _load,
      );
    }

    final data = _data;
    if (data == null || data.isEmpty) {
      // Pull-to-refresh has to work with nothing on screen too, so the empty
      // state sits inside a scrollable that is always drag-able.
      return RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: const EmptyStateWidget(
                message: 'No work items yet',
                icon: Icons.insights_outlined,
                subtitle: 'Analytics appear once this workspace has issues',
              ),
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final projects = data.projects.where((p) => p.items.isNotEmpty).toList()
      ..sort((a, b) => b.items.length.compareTo(a.items.length));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ProvenanceNote(data: data),
          const SizedBox(height: 16),
          _buildOverviewCards(data, theme),
          const SizedBox(height: 24),
          _buildSectionTitle('Work items by priority', theme),
          const SizedBox(height: 12),
          _ChartBars(
            counts: data.byPriority,
            order: kPriorities,
            colorOf: (key) => PlaneTheme.priorityColor(context, key),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Work items by state', theme),
          const SizedBox(height: 12),
          _ChartBars(
            counts: data.byStateGroup,
            order: kStateGroups,
            colorOf: (key) => PlaneTheme.stateGroupColor(context, key),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Work items by project', theme),
          const SizedBox(height: 12),
          if (projects.isEmpty)
            Text('No data',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
          else
            ...projects.map((p) => _ProjectRow(scan: p)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildOverviewCards(WorkspaceAnalytics data, ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
          label: 'Total work items',
          value: data.total,
          color: theme.colorScheme.primary,
          // The only card the server produced, so the only one that stays
          // right even when the sweep did not finish.
          source: 'from server',
        ),
        _StatCard(
          label: 'Completed',
          value: data.completed,
          // The state-group palette resolves against the current brightness;
          // the raw constants underneath it were tuned for dark only.
          color: PlaneTheme.stateGroupColor(context, 'completed'),
          source: 'counted here',
        ),
        _StatCard(
          label: 'Pending',
          value: data.pending,
          color: PlaneTheme.stateGroupColor(context, 'started'),
          source: 'counted here',
        ),
        _StatCard(
          label: 'Overdue',
          value: data.overdue,
          color: PlaneTheme.priorityColor(context, 'urgent'),
          source: 'counted here',
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(title, style: theme.textTheme.titleMedium);
  }
}

/// Says where the numbers came from, and how much of the workspace they cover.
///
/// This is not decoration. The screen mixes one server-side count with several
/// device-side ones, and a partial sweep is possible on a large workspace; both
/// facts change how the figures should be read, so both are stated rather than
/// left for the user to discover by disagreeing with the web UI.
class _ProvenanceNote extends StatelessWidget {
  final WorkspaceAnalytics data;

  const _ProvenanceNote({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final complete = data.isComplete;

    // A partial scan is a warning, not an error — the numbers are real, they
    // just do not cover everything. The app's pending amber is its warning
    // role and is already resolved per brightness.
    final accent = complete
        ? theme.colorScheme.onSurfaceVariant
        : PlaneTheme.pendingColor(context);

    // Two ways the sweep can fall short, and they need different wording. If a
    // project was read only partly, the server's total is known and the
    // shortfall can be quoted as a fraction. If a project could not be read at
    // all, its size is unknown — the total is short too — so quoting a fraction
    // would understate the gap, and the note names the projects instead.
    final unread = data.incompleteProjects;
    final String message;
    if (complete) {
      message = 'Counted on this device from all ${data.scanned} work items. '
          'The total comes from the server; this Plane instance serves its '
          'analytics API only to browser sessions, and the app signs in with '
          'an API token.';
    } else if (data.total > data.scanned) {
      message = 'Counted on this device from ${data.scanned} of ${data.total} '
          'work items — the sweep stopped short, so every figure except the '
          'total covers part of the workspace.';
    } else {
      message = 'Counted on this device from ${data.scanned} work items. '
          '$unread ${unread == 1 ? 'project' : 'projects'} could not be read, '
          'so these figures — the total included — cover part of the '
          'workspace.';
    }

    return Semantics(
      container: true,
      label: message,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(M3EShape.medium),
          border: Border.all(
            color: complete
                ? theme.colorScheme.outlineVariant
                : accent.withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              complete ? Icons.info_outline : Icons.warning_amber_outlined,
              size: PlaneTheme.iconMedium,
              color: accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(color: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal bar per category, in a fixed order with empty rows dropped.
///
/// The order is Plane's own (urgency, then workflow) rather than by size: these
/// two axes have a meaning that a sort by count would scramble.
class _ChartBars extends StatelessWidget {
  final Map<String, int> counts;
  final List<String> order;
  final Color Function(String key) colorOf;

  const _ChartBars({
    required this.counts,
    required this.order,
    required this.colorOf,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Fixed order first, then anything the server invented that this build does
    // not know about, so a new state group shows up rather than disappearing.
    final keys = <String>[
      ...order.where((k) => (counts[k] ?? 0) > 0),
      ...counts.keys.where((k) => !order.contains(k) && counts[k]! > 0),
    ];

    if (keys.isEmpty) {
      return Text('No data',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }

    final maxValue =
        keys.map((k) => counts[k]!).reduce((a, b) => a > b ? a : b);

    return Column(
      children: keys.map((key) {
        final value = counts[key]!;
        final ratio = value / maxValue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Semantics(
            container: true,
            label: '${_titleCase(key)}: $value',
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    _titleCase(key),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (ctx, constraints) => Container(
                      height: 24,
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: constraints.maxWidth * ratio,
                        height: 24,
                        decoration: BoxDecoration(
                          color: colorOf(key),
                          borderRadius: BorderRadius.circular(M3EShape.small),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  // The count is the one thing that must read louder than the
                  // category beside it, so it takes the emphasized cut.
                  child: Text('$value',
                      style: M3EType.emphasized(theme.textTheme.titleSmall!)),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// One project, with its work items stacked by state group.
///
/// A stacked bar rather than another length-versus-max bar: what is interesting
/// about a project is the shape of its backlog-to-done split, and that only
/// shows if the segments share one bar.
class _ProjectRow extends StatelessWidget {
  final ProjectScan scan;

  const _ProjectRow({required this.scan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = scan.byStateGroup;
    final segments = kStateGroups
        .where((g) => (counts[g] ?? 0) > 0)
        .map((g) => MapEntry(g, counts[g]!))
        .toList();

    final scanned = scan.items.length;
    // A project whose sweep fell short shows both numbers rather than a single
    // figure that would read as the project's size.
    final countLabel =
        scan.isComplete ? '$scanned' : '$scanned / ${scan.serverTotal}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        container: true,
        label: '${scan.projectName}: $countLabel work items, '
            '${counts['completed'] ?? 0} completed',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    scan.projectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                Text(countLabel,
                    style: M3EType.emphasized(theme.textTheme.titleSmall!)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(M3EShape.extraSmall),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: segments
                      .map((e) => Expanded(
                            flex: e.value,
                            child: ColoredBox(
                              color: PlaneTheme.stateGroupColor(context, e.key),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _titleCase(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  /// Where the figure came from — spelled out per card because two of these
  /// four are database counts and two are not, and they look identical.
  final String source;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '$label: $value, $source',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(M3EShape.large),
          border:
              Border.all(color: theme.colorScheme.outlineVariant, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$value',
                style: theme.textTheme.headlineMedium?.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text(source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}
