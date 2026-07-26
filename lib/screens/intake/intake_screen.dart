import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/intake_issue.dart';
import '../../services/intake_service.dart';
import '../../utils/api_error.dart';
import '../../utils/time_ago.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/chip.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/plane_row.dart';
import 'intake_actions.dart';
import 'intake_detail_screen.dart';
import 'intake_status.dart';

/// Which half of the queue is on screen.
///
/// The same two tabs Plane's own intake screen has. Open pairs pending with
/// snoozed; closed collects the three terminal statuses. There is deliberately
/// no "all": the two halves answer different questions — what needs deciding,
/// and what was decided — and merging them buries the first in the second.
enum _IntakeTab { open, closed }

/// A project's Intake queue: work items submitted for triage.
///
/// This is **not** the app's Inbox tab. That is the notification feed, and the
/// two have nothing to do with each other beyond Plane historically calling
/// both of them "inbox". Nothing on this screen says inbox, and nothing in the
/// notification feed says intake.
class IntakeScreen extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;

  /// Project identifier, so rows can read `PLM-42`.
  final String projectIdentifier;

  const IntakeScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.projectIdentifier,
  });

  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends State<IntakeScreen> {
  _IntakeTab _tab = _IntakeTab.open;
  List<IntakeIssue> _entries = [];
  bool _loading = true;
  String? _error;

  /// Guards against a slow response for the tab the user has already left
  /// overwriting the tab they are now looking at.
  _IntakeTab _inFlight = _IntakeTab.open;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tab = _tab;
    setState(() {
      _loading = true;
      _error = null;
      _inFlight = tab;
    });
    try {
      final entries = await IntakeService.getIntakeIssues(
        widget.workspaceSlug,
        widget.projectId,
        statuses:
            tab == _IntakeTab.open ? IntakeStatus.open : IntakeStatus.closed,
      );
      if (!mounted || _inFlight != tab) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || _inFlight != tab) return;
      setState(() {
        // A project whose Intake row does not exist answers 404 with
        // {"error": "Intake not found"}, which describeApiError surfaces
        // verbatim. That is the honest thing to show: the entry point should
        // not have been offered, and saying so beats an empty list.
        _error =
            describeApiError(e, fallback: 'Could not load the intake queue');
        _loading = false;
      });
    }
  }

  void _switchTo(_IntakeTab tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _entries = [];
    });
    _load();
  }

  Future<void> _triage(IntakeIssue entry) async {
    final changed = await showIntakeActionSheet(
      context,
      workspaceSlug: widget.workspaceSlug,
      projectId: widget.projectId,
      projectIdentifier: widget.projectIdentifier,
      entry: entry,
    );
    if (changed && mounted) _load();
  }

  Future<void> _open(IntakeIssue entry) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => IntakeDetailScreen(
          workspaceSlug: widget.workspaceSlug,
          projectId: widget.projectId,
          projectIdentifier: widget.projectIdentifier,
          entry: entry,
        ),
      ),
    );
    if (changed == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: M3EAppBar(
        title: 'Intake',
        subtitle: widget.projectIdentifier.isEmpty
            ? 'Triage queue'
            : '${widget.projectIdentifier} triage queue',
        actions: [
          M3EAppBarAction(
            icon: Icons.refresh,
            tooltip: 'Reload the intake queue',
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: RefreshIndicator(onRefresh: _load, child: _list()),
          ),
        ],
      ),
    );
  }

  /// Count on the left, the two tabs on the right — the same header shape the
  /// cycle, module and page lists use for their archive toggle, so a list
  /// header means the same thing wherever it appears.
  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final count = _entries.length;
    final noun = _tab == _IntakeTab.open ? 'open' : 'closed';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
      child: Row(
        children: [
          Text(
            _loading ? 'Loading' : '$count $noun',
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          _TabChip(
            label: 'Open',
            hint: 'work items still to triage',
            selected: _tab == _IntakeTab.open,
            onTap: () => _switchTo(_IntakeTab.open),
          ),
          const SizedBox(width: 6),
          _TabChip(
            label: 'Closed',
            hint: 'work items already triaged',
            selected: _tab == _IntakeTab.closed,
            onTap: () => _switchTo(_IntakeTab.closed),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    if (_loading) return const LoadingStateWidget();
    if (_error != null) {
      return ErrorStateWidget(message: _error, onRetry: _load);
    }
    if (_entries.isEmpty) {
      // Scrollable so the pull-to-refresh still works on an empty queue.
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: EmptyStateWidget(
              message: _tab == _IntakeTab.open
                  ? 'Nothing waiting to be triaged'
                  : 'Nothing has been triaged yet',
              icon: IntakeStatusLook.icon(IntakeStatus.pending),
              subtitle: _tab == _IntakeTab.open
                  ? 'Submissions to this project land here first'
                  : 'Accepted, declined and duplicate entries collect here',
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: _entries.length,
      itemBuilder: (ctx, i) => _row(_entries[i]),
    );
  }

  Widget _row(IntakeIssue entry) {
    final issue = entry.issue;
    final identifier = widget.projectIdentifier.isEmpty
        ? null
        : '${widget.projectIdentifier}-${issue.sequenceId}';
    final subtitle = intakeSubtitle(entry);
    final label = intakeEntryLabel(entry, widget.projectIdentifier);

    return PlaneRow(
      icon: IntakeStatusLook.icon(entry.status),
      iconColor: IntakeStatusLook.color(context, entry.status),
      identifier: identifier,
      badges: [
        if (issue.priority != 'none')
          Icon(
            PlaneTheme.priorityIcon(issue.priority),
            size: PlaneTheme.iconSmall,
            color: PlaneTheme.priorityColor(context, issue.priority),
          ),
      ],
      title: issue.name,
      subtitle: subtitle,
      // The work item's own created_at, not the intake row's: neither intake
      // serialiser sends timestamps for the row itself.
      subtitleTrailing: timeAgoShort(issue.createdAt),
      semanticLabel: intakeRowSemanticLabel(entry, widget.projectIdentifier),
      // Only open entries have anything to decide, so only they get the
      // shortcut. A closed entry opens instead.
      trailing: entry.isOpen
          ? M3EIconButton(
              icon: Icons.more_horiz,
              tooltip: 'Triage $label',
              size: M3EIconButtonSize.small,
              onPressed: () => _triage(entry),
            )
          : null,
      onTap: () => _open(entry),
    );
  }
}

/// One of the two queue tabs.
///
/// A chip, and in the list header, because that is where this app already puts
/// a control that switches a list between two views of itself — see
/// `ArchiveToggle`. The Semantics wrapper is there for the same reason it is
/// there: M3EChip leaves its visible text as the accessible name, and "Open"
/// on its own says neither what it lists nor that it is a tab.
class _TabChip extends StatelessWidget {
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: selected ? 'Showing $hint' : 'Show $hint',
      button: true,
      selected: selected,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: M3EChip(
        label: label,
        selected: selected,
        dense: true,
        onTap: onTap,
      ),
    );
  }
}
