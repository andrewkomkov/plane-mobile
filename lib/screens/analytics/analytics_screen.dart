import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/m3e/motion.dart';
import '../../config/m3e/shapes.dart';
import '../../config/theme.dart';
import '../../models/analytics.dart';
import '../../services/analytics_service.dart';
import '../../services/export_service.dart';
import '../../utils/say.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/plane_row.dart';
import '../../widgets/section_header.dart';

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
      appBar: M3EAppBar(
        title: 'Analytics',
        actions: [
          M3EAppBarAction(
            icon: Icons.download_outlined,
            tooltip: 'Export these figures',
            onPressed: _export,
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  /// Queue an analytics export.
  ///
  /// Nothing is downloaded: Plane queues a background job and sends the file
  /// by email, the same shape the work-item export has. Saying so is the whole
  /// of the feedback, because there is no progress to show.
  Future<void> _export() async {
    try {
      await ExportService.exportAnalytics(widget.workspaceSlug);
      if (mounted) say(context, 'Export queued. It arrives by email.');
    } catch (_) {
      if (mounted) say(context, 'Could not queue the export');
    }
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
      // state sits inside a scrollable that is always drag-able. The shared
      // helper is that scrollable; the screens that hand-rolled it padded a
      // ListView with a fraction of the viewport height instead, and picked
      // three different fractions between them.
      return RefreshIndicator(
        onRefresh: _load,
        child: const ScrollableEmptyState(
          message: 'No work items yet',
          icon: Icons.insights_outlined,
          subtitle: 'Analytics appear once this workspace has issues',
        ),
      );
    }

    final projects = [...?data.projects]
      ..sort((a, b) => b.total.compareTo(a.total));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        // [SectionHeader] and [PlaneRow] both carry their own inset, so the
        // page margin is applied per block rather than to the whole list.
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          _inset(_ProvenanceNote(data: data)),
          const SizedBox(height: 16),
          _inset(_buildOverviewCards(context, data)),
          const SectionHeader(label: 'Work items by priority'),
          _inset(_ChartBars(
            counts: data.byPriority,
            order: kPriorities,
            colorOf: (key) => PlaneTheme.priorityColor(context, key),
          )),
          const SectionHeader(label: 'Work items by state'),
          _inset(_ChartBars(
            counts: data.byStateGroup,
            order: kStateGroups,
            colorOf: (key) => PlaneTheme.stateGroupColor(context, key),
          )),
          SectionHeader(
            label: 'Work items by project',
            // No pill when the panel is missing: a zero there would read as
            // "no projects", which is the one thing this screen must not say
            // about a request that never answered.
            count: data.projects?.length,
          ),
          if (data.projects == null)
            _inset(const _Unavailable())
          else if (projects.isEmpty)
            const EmptyStateWidget(message: 'No projects with work items')
          else
            ...projects.map((p) => _ProjectRow(project: p)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// The page margin, for the blocks that are not full-bleed rows or headers.
  Widget _inset(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20), child: child);

  Widget _buildOverviewCards(BuildContext context, WorkspaceAnalytics data) {
    final theme = Theme.of(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      // A grid cell's height comes from its width and this ratio, so it does
      // not grow with the type inside it. Three stacked lines of text at a
      // large accessibility scale overflow a fixed-height cell; letting the
      // ratio fall as the scale rises gives them the room instead.
      childAspectRatio:
          1.6 / MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
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
      // Without this the note is announced twice: `container: true` forces a
      // node, and the sentence the Text below draws is merged into it beside
      // the identical label. See `motion.dart:243-259` — a label REPLACES the
      // subtree's, but only if the subtree is excluded. Nothing here is
      // tappable, so there is no action to re-declare.
      excludeSemantics: true,
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

    // The two text columns hold the bars in line with each other across rows,
    // so they cannot size to their own text — but at a fixed 80 and 44 they
    // clipped the label and the count from a text scale of about 1.3 upward.
    // Scaling the box by the same factor as the type inside it keeps the
    // alignment and stops the clipping.
    final scaler = MediaQuery.textScalerOf(context);

    // Fixed order first, then anything the server invented that this build does
    // not know about, so a new state group shows up rather than disappearing.
    final keys = <String>[
      ...order.where((k) => (counts[k] ?? 0) > 0),
      ...counts.keys.where((k) => !order.contains(k) && counts[k]! > 0),
    ];

    // The server answered and the answer was nothing, which is the shared
    // empty state and not a failure. The failure is `_Unavailable` above.
    if (keys.isEmpty) return const EmptyStateWidget(message: 'No data');

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
            // The bar draws the same category and the same number the label
            // already says, and both reach the node unless the subtree is
            // excluded — "Urgent: 8, Urgent, 8".
            excludeSemantics: true,
            child: Row(
              children: [
                SizedBox(
                  width: scaler.scale(80),
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
                    builder: (ctx, constraints) => SizedBox(
                      height: 24,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        // Width is a spatial property, so it takes a spatial
                        // spring and is allowed to overshoot. What this
                        // replaces was an AnimatedContainer running on its
                        // default curve, which is `Curves.linear` — a bar that
                        // starts and stops dead.
                        child: M3ESpringBuilder(
                          value: ratio,
                          spring: M3EMotion.defaultSpatial,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorOf(key),
                              borderRadius:
                                  BorderRadius.circular(M3EShape.small),
                            ),
                          ),
                          builder: (context, width, child) => SizedBox(
                            width: constraints.maxWidth * width.clamp(0.0, 1.0),
                            height: 24,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: scaler.scale(44),
                  // Plain rather than emphasized: the category beside it is
                  // already the quieter `onSurfaceVariant`, so the count reads
                  // louder without spending the screen's emphasis on it. The
                  // four figures in the overview cards are what the emphasis is
                  // for, and there is one of those per screen, not one per bar.
                  child: Text('$value', style: theme.textTheme.titleSmall),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// The server did not answer for this panel.
///
/// Not an [EmptyStateWidget], and deliberately so. An empty state says "there
/// is nothing here", which is a statement about the workspace; this says "we do
/// not know", which is a statement about the request. Conflating the two is the
/// class of lie the whole screen is built to avoid, so it keeps the warning
/// glyph and the warning colour that [_ProvenanceNote] uses for the same
/// meaning at the top of the screen.
class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = PlaneTheme.pendingColor(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_outlined,
            size: PlaneTheme.iconMedium, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Unavailable — the server did not answer for this',
            style: theme.textTheme.bodyMedium?.copyWith(color: accent),
          ),
        ),
      ],
    );
  }
}

/// One project, with its work items broken down by state group.
///
/// This was a hand-rolled `Column` — its own title cut, its own emphasized
/// total, its own stacked bar clipped at `extraSmall` where every other
/// progress bar in the app is `full`. It is a thing in a list, so it is a
/// [PlaneRow] now, and the progress bar, the corner and the press physics all
/// come from there.
///
/// The stacked bar it replaces showed the backlog-to-done split as proportions.
/// The same information is in `chips` as one [PlaneRowMeta] per state group,
/// which is exact rather than approximate and — being a `Wrap` — is the one
/// arrangement that survives a large text scale on a narrow phone.
class _ProjectRow extends StatelessWidget {
  final ProjectAnalytics project;

  const _ProjectRow({required this.project});

  @override
  Widget build(BuildContext context) {
    final counts = project.byStateGroup;
    final total = project.total;
    final completed = counts['completed'] ?? 0;
    final groups = kStateGroups.where((g) => (counts[g] ?? 0) > 0).toList();

    return PlaneRow(
      title: project.projectName,
      subtitle: '$total ${total == 1 ? 'work item' : 'work items'}',
      subtitleTrailing: '$completed done',
      progress: total == 0 ? 0 : completed / total,
      progressColor: PlaneTheme.stateGroupColor(context, 'completed'),
      chips: [
        for (final g in groups)
          PlaneRowMeta(
            icon: PlaneTheme.stateIcon(g),
            text: '${counts[g]}',
            color: PlaneTheme.stateGroupColor(context, g),
          ),
      ],
      // The row draws the name, both counts, the bar and one indicator per
      // group, and [PlaneRow] hands this label to [M3EPressable], which
      // replaces the whole subtree — so anything not said here is not said.
      semanticLabel: [
        project.projectName,
        '$total work items',
        '$completed completed',
        for (final g in groups) '${counts[g]} ${_titleCase(g)}',
      ].join(', '),
    );
  }
}

String _titleCase(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

/// One figure, its name and where it came from.
///
/// Kept bespoke, and this is the one place on the screen where that is a
/// decision rather than an oversight. [PlaneRow] with `density: card` draws the
/// same surface and would carry the semantics for free — but its primary slot
/// is a `titleMedium` title, and the whole point of this card is a
/// `headlineMedium` number with its name underneath. Putting the figure in the
/// title slot would shrink the only thing anybody looks at.
///
/// What it does take from [PlaneRowDensity.card] is the surface itself: the
/// same fill, the same hairline and the same corner, so four stat cards and a
/// list of project rows read as one family. A shared card *surface* — the
/// decoration without the row's slots — would retire this and five more
/// hand-rolled copies of the same `BoxDecoration` elsewhere in the app; see the
/// report.
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
      // The card draws the figure, the label and the provenance line, all
      // three of which the label above already carries. Excluded, so the card
      // is one node saying it once rather than four saying it twice.
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // `PlaneRowDensity.card`'s surface, token for token.
          color: theme.colorScheme.surfaceContainerLow,
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
