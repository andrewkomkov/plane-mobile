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
/// Two rewrites deep. The first version fetched one page of work items from the
/// first five projects and counted those, which made every figure a function of
/// how much the app happened to have loaded. The second swept every project to
/// its last page and said out loud which figures the device had counted, because
/// Plane's analytics endpoints were unreachable behind an API token.
///
/// They are reachable now, through the session proxy, and this version asks the
/// server. Nothing on this screen is counted on the device; see
/// `AnalyticsService` for the endpoint per panel.
///
/// What survives from the second version is the habit that made it worth
/// keeping: the screen states where its numbers come from, and where one is
/// missing it says so rather than drawing a zero.
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

    final data = _data;

    // The service swallows a failed panel so the rest of the screen survives
    // it. When every panel failed there is nothing left to show and nothing
    // honest to say about it, so it becomes the error state.
    if (_error != null || data == null || !data.hasAnyFigure) {
      return ErrorStateWidget(
        message: 'Failed to load analytics',
        onRetry: _load,
      );
    }

    if (data.isEmpty) {
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
    final projects = [...?data.projects]
      ..sort((a, b) => b.total.compareTo(a.total));

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
          if (data.projects == null)
            const _Unavailable()
          else if (projects.isEmpty)
            const _NoData()
          else
            ...projects.map((p) => _ProjectRow(project: p)),
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
        ),
        _StatCard(
          label: 'Completed',
          value: data.completed,
          // The state-group palette resolves against the current brightness;
          // the raw constants underneath it were tuned for dark only.
          color: PlaneTheme.stateGroupColor(context, 'completed'),
        ),
        _StatCard(
          label: 'Pending',
          value: data.pending,
          color: PlaneTheme.stateGroupColor(context, 'started'),
        ),
        _StatCard(
          label: 'Overdue',
          value: data.overdue,
          color: PlaneTheme.priorityColor(context, 'urgent'),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(title, style: theme.textTheme.titleMedium);
  }
}

/// Says where the numbers came from, and names anything that did not arrive.
///
/// This is not decoration. The previous version of this screen counted most of
/// these figures on the device from a sweep that could fall short, and said so;
/// replacing that with server-side aggregates is only an improvement if the
/// screen keeps stating which it is. The second sentence exists for the same
/// reason: five endpoints answer this screen and they fail independently, so a
/// panel can be missing while its neighbours are correct.
class _ProvenanceNote extends StatelessWidget {
  final WorkspaceAnalytics data;

  const _ProvenanceNote({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final complete = data.isComplete;

    // A missing panel is a warning, not an error — what is on screen is real,
    // there is just less of it. The app's pending amber is its warning role and
    // is already resolved per brightness.
    final accent = complete
        ? theme.colorScheme.onSurfaceVariant
        : PlaneTheme.pendingColor(context);

    final buffer = StringBuffer(
      'Computed by Plane over the projects you belong to. Nothing on this '
      'screen is counted on the device.',
    );
    if (!complete) {
      buffer.write(' The server did not answer for ');
      buffer.write(_list(data.unavailable));
      buffer.write(', shown as unavailable below.');
    }
    final message = buffer.toString();

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

  /// "a", "a and b", "a, b and c" — the note is a sentence, not a bullet list.
  static String _list(List<String> parts) {
    if (parts.length == 1) return parts.first;
    return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }
}

/// A horizontal bar per category, in a fixed order with empty rows dropped.
///
/// The order is Plane's own (urgency, then workflow) rather than by size: these
/// two axes have a meaning that a sort by count would scramble.
///
/// A null [counts] is the panel's request having failed, which is a different
/// thing from a workspace with nothing in it, and reads differently.
class _ChartBars extends StatelessWidget {
  final Map<String, int>? counts;
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
    final counts = this.counts;
    if (counts == null) return const _Unavailable();

    // Fixed order first, then anything the server invented that this build does
    // not know about, so a new state group shows up rather than disappearing.
    final keys = <String>[
      ...order.where((k) => (counts[k] ?? 0) > 0),
      ...counts.keys.where((k) => !order.contains(k) && counts[k]! > 0),
    ];

    if (keys.isEmpty) return const _NoData();

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

/// The server answered, and the answer was nothing.
class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'No data',
      style: theme.textTheme.bodyMedium
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

/// The server did not answer. Deliberately worded so it cannot be read as a
/// count of zero, and coloured with the warning role so it does not read as a
/// caption either.
class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) => Text(
        'Unavailable — the server did not answer for this',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: PlaneTheme.pendingColor(context)),
      );
}

/// One project, with its work items stacked by state group.
///
/// A stacked bar rather than another length-versus-max bar: what is interesting
/// about a project is the shape of its backlog-to-done split, and that only
/// shows if the segments share one bar.
class _ProjectRow extends StatelessWidget {
  final ProjectAnalytics project;

  const _ProjectRow({required this.project});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = project.byStateGroup;
    final segments = kStateGroups
        .where((g) => (counts[g] ?? 0) > 0)
        .map((g) => MapEntry(g, counts[g]!))
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        container: true,
        label: '${project.projectName}: ${project.total} work items, '
            '${counts['completed'] ?? 0} completed',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.projectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${project.total}',
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

  /// Null when the read behind this card failed. The card shows a dash and
  /// says why, because a zero here is a real and very different answer.
  final int? value;

  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = this.value;

    // Every card that has a figure got it from the database, so the provenance
    // line is the same on all four. It is still printed per card rather than
    // once at the top: the cards are the thing a reader takes a screenshot of,
    // and a card that lost its source is the one that gets misquoted.
    final source = value == null ? 'unavailable' : 'from server';

    return Semantics(
      container: true,
      label: '$label: ${value ?? 'unavailable'}, $source',
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
            Text(value?.toString() ?? '—',
                style: theme.textTheme.headlineMedium?.copyWith(
                    color: value == null ? theme.colorScheme.outline : color)),
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
