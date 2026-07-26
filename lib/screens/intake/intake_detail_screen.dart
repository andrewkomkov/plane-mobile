import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/m3e/motion.dart';
import '../../config/m3e/shapes.dart';
import '../../config/theme.dart';
import '../../models/intake_issue.dart';
import '../../providers/data_providers.dart';
import '../../services/intake_service.dart';
import '../../utils/html_to_markdown.dart';
import '../../widgets/m3e/app_bar.dart';
import '../issues/issue_detail_screen.dart';
import 'intake_actions.dart';
import 'intake_status.dart';

/// One entry in the Intake queue, with the decision it is waiting for.
///
/// The list only ever sees `IntakeIssueSerializer`, which carries the work
/// item's name, priority and labels and nothing else — no description. This
/// screen refetches through the retrieve route, which serialises the work item
/// with `IssueDetailSerializer` and so does carry one. The row's copy is used
/// as the seed so the screen has a title and a status before that lands.
///
/// Pops `true` when the entry was changed, so the queue behind it knows to
/// reload rather than redrawing a decision that has already been made.
class IntakeDetailScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final String projectIdentifier;
  final IntakeIssue entry;

  const IntakeDetailScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.projectIdentifier,
    required this.entry,
  });

  @override
  ConsumerState<IntakeDetailScreen> createState() => _IntakeDetailScreenState();
}

class _IntakeDetailScreenState extends ConsumerState<IntakeDetailScreen> {
  late IntakeIssue _entry = widget.entry;
  bool _loadingDetail = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final full = await IntakeService.getIntakeIssue(
        widget.workspaceSlug,
        widget.projectId,
        widget.entry.issueId,
      );
      if (!mounted) return;
      setState(() {
        _entry = full;
        _loadingDetail = false;
      });
    } catch (_) {
      // The seed from the list is still a usable screen — it just has no
      // description. Failing the whole screen over the part that is only
      // extra detail would be worse than showing what is already in hand.
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  String get _label => intakeEntryLabel(_entry, widget.projectIdentifier);

  Future<void> _run(IntakeAction action) async {
    final changed = await runIntakeAction(
      context,
      workspaceSlug: widget.workspaceSlug,
      projectId: widget.projectId,
      projectIdentifier: widget.projectIdentifier,
      entry: _entry,
      action: action,
    );
    if (!changed || !mounted) return;
    _changed = true;
    await _loadDetail();
  }

  void _openWorkItem() {
    // The states map is what IssueDetailScreen renders its state picker from;
    // an empty one is a degraded screen rather than a broken one, and the
    // project screen has normally already warmed this cache.
    final states = ref
            .read(dataCacheProvider)
            .getStates(widget.workspaceSlug, widget.projectId) ??
        {};
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IssueDetailScreen(
          workspaceSlug: widget.workspaceSlug,
          projectId: widget.projectId,
          issueId: _entry.issueId,
          projectIdentifier: widget.projectIdentifier,
          states: states,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issue = _entry.issue;
    final description = issue.descriptionHtml;

    return PopScope(
      // The result has to survive the system back gesture too, not just the
      // buttons — otherwise triaging and swiping back leaves the queue showing
      // the old status.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: M3EAppBar(title: _label, subtitle: 'Intake'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              children: [
                IntakeStatusPill(entry: _entry),
                const Spacer(),
                if (_entry.source != null)
                  Text(
                    'via ${_entry.source!.toLowerCase().replaceAll('_', ' ')}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(issue.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '${intakeSubtitle(_entry)} · submitted '
              '${intakeDateLabel(issue.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
            if (issue.priority != 'none') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    PlaneTheme.priorityIcon(issue.priority),
                    size: PlaneTheme.iconSmall,
                    color: PlaneTheme.priorityColor(context, issue.priority),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${issue.priority} priority',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: PlaneTheme.priorityColor(context, issue.priority),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (description != null && description.isNotEmpty)
              MarkdownBody(
                data: htmlToMarkdown(description),
                styleSheet: MarkdownStyleSheet(
                  p: theme.textTheme.bodyMedium,
                  h1: theme.textTheme.headlineSmall,
                  h2: theme.textTheme.titleLarge,
                  h3: theme.textTheme.titleMedium,
                ),
              )
            // Nothing at all while the retrieve is still out: the list
            // response has no description field, so "empty" and "not fetched
            // yet" are the same state until it lands, and claiming the
            // submitter wrote nothing would be a guess.
            else if (!_loadingDetail)
              Text(
                'No description was submitted.',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 28),
            ..._decisions(context),
          ],
        ),
      ),
    );
  }

  /// The decision buttons, or the one thing a closed entry still offers.
  List<Widget> _decisions(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!_entry.isOpen) {
      return [
        _Decision(
          icon: Icons.open_in_new,
          label: 'Open work item',
          detail: 'This entry has been triaged. The work item itself lives '
              'in the project now.',
          onTap: _openWorkItem,
        ),
      ];
    }

    final snoozed = _entry.status == IntakeStatus.snoozed;
    return [
      _Decision(
        icon: Icons.check_circle_outline,
        label: 'Accept',
        detail: 'Move it out of Triage into the project’s default state',
        color: PlaneTheme.stateGroupColor(context, 'completed'),
        onTap: () => _run(IntakeAction.accept),
      ),
      if (snoozed)
        _Decision(
          icon: Icons.alarm_on_outlined,
          label: 'Un-snooze',
          detail: 'Put it back in the pending queue now',
          onTap: () => _run(IntakeAction.unsnooze),
        )
      else
        _Decision(
          icon: Icons.snooze,
          label: 'Snooze',
          detail: 'Hide it until a date you pick',
          onTap: () => _run(IntakeAction.snooze),
        ),
      _Decision(
        icon: Icons.copy_all_outlined,
        label: 'Mark duplicate',
        detail: _entry.duplicateName == null
            ? 'Point it at the work item it repeats'
            : 'Currently pointing at ${_entry.duplicateName}',
        onTap: () => _run(IntakeAction.duplicate),
      ),
      _Decision(
        icon: Icons.cancel_outlined,
        label: 'Decline',
        detail: 'Reject it. This cannot be undone',
        color: scheme.error,
        onTap: () => _run(IntakeAction.decline),
      ),
    ];
  }
}

/// One decision, as a full-width tonal card.
///
/// Cards rather than a row of buttons: four actions do not fit across a phone
/// without truncating their labels, and each of these needs a sentence saying
/// what it does to the work item — which is the part that stops someone
/// accepting when they meant to snooze.
class _Decision extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final Color? color;
  final VoidCallback onTap;

  const _Decision({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: M3EPressable(
        onTap: onTap,
        semanticLabel: '$label. $detail',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(M3EShape.large),
            border: Border.all(color: tint.withValues(alpha: 0.3), width: 0.8),
          ),
          child: Row(
            children: [
              Icon(icon, size: PlaneTheme.iconLarge, color: tint),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style:
                            theme.textTheme.titleMedium?.copyWith(color: tint)),
                    const SizedBox(height: 2),
                    Text(detail, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
