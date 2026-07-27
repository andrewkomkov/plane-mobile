import 'package:flutter/material.dart';
import '../../utils/say.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/inbox_entry.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../services/inbox_service.dart';
import '../../utils/time_ago.dart';
import '../../database/sync_service.dart';
import '../issues/issue_detail_screen.dart';
import '../../widgets/app_navbar.dart';
import '../../widgets/bottom_sheet_picker.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/skeleton_loader.dart';
import '../../config/m3e/shapes.dart';
import '../../widgets/m3e/flexible_app_bar.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/issue_row.dart';

/// The actions the overflow sheet offers for the whole list.
enum _BulkAction { markAllRead, dismissAll }

/// The actions the overflow sheet offers for one row.
enum _RowAction { toggleRead, dismiss }

class InboxTab extends ConsumerStatefulWidget {
  final String workspaceSlug;

  /// The signed-in user's id.
  ///
  /// Needed because half the feed is `workspaces/{slug}/user-activity/{id}/`.
  /// Null until the profile request lands, which is the same window in which
  /// [MyIssuesTab] cannot filter either.
  final String? userId;

  const InboxTab({super.key, required this.workspaceSlug, this.userId});

  @override
  ConsumerState<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends ConsumerState<InboxTab>
    with AutomaticKeepAliveClientMixin {
  List<InboxEntry> _entries = [];
  bool _loading = true;
  bool _loaded = false;

  /// Set only when the fetch failed *and* there is nothing to show.
  ///
  /// A failed fetch used to fall straight through to "No notifications", so
  /// being offline and being caught up looked identical — the one pair of
  /// states an inbox must never confuse.
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(InboxTab old) {
    super.didUpdateWidget(old);
    if (old.workspaceSlug != widget.workspaceSlug ||
        old.userId != widget.userId) {
      _loaded = false;
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.workspaceSlug.isEmpty) return;

    // Read from SQLite first (instant)
    try {
      final cached = await SyncService.readInboxItems(widget.workspaceSlug);
      if (cached != null && cached.isNotEmpty && mounted) {
        setState(() {
          _entries = cached;
          _loading = false;
        });
      }
    } catch (_) {}

    if (!_loaded && _entries.isEmpty) {
      if (mounted) setState(() => _loading = true);
    }

    try {
      final entries = await InboxService.feed(
        workspaceSlug: widget.workspaceSlug,
        userId: widget.userId ?? '',
      );
      if (mounted) {
        setState(() {
          _entries = entries;
          _loading = false;
          _loaded = true;
          _error = null;
        });
      }
      SyncService.writeInboxItems(widget.workspaceSlug, entries);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loaded = true;
          // Only when nothing arrived at all. A refresh that fails over rows
          // already on screen keeps the rows — stale is better than empty, and
          // the cached read above is exactly that case.
          if (_entries.isEmpty) {
            _error = 'Could not reach the server';
          }
        });
      }
    }
  }

  Future<void> _setRead(InboxEntry entry, bool read) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index < 0) return;
    setState(() => _entries[index] = entry.copyWith(isRead: read));
    try {
      if (read) {
        await InboxService.markRead(widget.workspaceSlug, entry);
      } else {
        await InboxService.markUnread(widget.workspaceSlug, entry);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final i = _entries.indexWhere((e) => e.id == entry.id);
        if (i >= 0) _entries[i] = entry;
      });
      _complain(read ? 'Could not mark it read' : 'Could not mark it unread');
    }
  }

  Future<void> _dismiss(InboxEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index < 0) return;
    setState(() => _entries.removeAt(index));
    try {
      await InboxService.dismiss(widget.workspaceSlug, entry);
    } catch (_) {
      // Restore in place rather than at the end — the feed is time-ordered and
      // a restored row belongs where it was.
      if (!mounted) return;
      setState(() => _entries.insert(index.clamp(0, _entries.length), entry));
      _complain('Could not dismiss it');
    }
  }

  /// Mark everything currently listed as read.
  ///
  /// One request for the notification half — Plane's own `mark-all-read/` —
  /// and one transaction for the activity half. Both are driven from the list
  /// on screen, so a bulk action can never touch a row the caller cannot see.
  Future<void> _markAllRead() async {
    final before = [..._entries];
    setState(() {
      _entries = [for (final e in _entries) e.copyWith(isRead: true)];
    });
    try {
      await InboxService.markAllRead(widget.workspaceSlug, before);
    } catch (_) {
      if (!mounted) return;
      setState(() => _entries = before);
      _complain('Could not mark them read');
    }
  }

  /// Dismiss everything currently listed.
  ///
  /// Kept behind a confirmation because it clears the whole screen.
  Future<void> _dismissAll() async {
    final removed = [..._entries];
    setState(() => _entries = []);
    try {
      await InboxService.dismissAll(widget.workspaceSlug, removed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _entries = removed);
      _complain('Could not dismiss them');
    }
  }

  void _complain(String message) {
    say(context, message);
  }

  Future<void> _refresh() async {
    _loaded = false;
    await _load();
  }

  /// Actions for the whole list.
  Future<void> _showBulkOptions() async {
    final unread = _entries.where((e) => !e.isRead).length;
    final picked = await BottomSheetPicker.show<_BulkAction>(
      context: context,
      title: 'All notifications',
      subtitle: '${_entries.length} in the list',
      items: [
        // Offered only when it would do something. The disabled `ListTile` it
        // replaces still looked like a control and still took a tap.
        if (unread > 0)
          BottomSheetPickerItem(
            value: _BulkAction.markAllRead,
            label: 'Mark all as read',
            // The count is the whole reason to reach for this rather than
            // tapping rows, so it belongs on the control.
            subtitle: '$unread unread',
            icon: Icons.mark_email_read_outlined,
          ),
        const BottomSheetPickerItem(
          value: _BulkAction.dismissAll,
          label: 'Dismiss all',
          icon: Icons.delete_sweep_outlined,
          destructive: true,
        ),
      ],
    );
    if (picked == null || !mounted) return;

    switch (picked) {
      case _BulkAction.markAllRead:
        await _markAllRead();
      case _BulkAction.dismissAll:
        final ok = await confirmDestructive(
          context,
          title: 'Dismiss all notifications?',
          message: 'This clears the whole list.',
          confirmLabel: 'Dismiss all',
        );
        if (ok) await _dismissAll();
    }
  }

  Future<void> _showRowOptions(InboxEntry entry) async {
    final picked = await BottomSheetPicker.show<_RowAction>(
      context: context,
      // Named, because the sheet can be opened from any of a screenful of
      // identical-looking rows.
      title: entry.title.isEmpty ? 'Notification' : entry.title,
      items: [
        BottomSheetPickerItem(
          value: _RowAction.toggleRead,
          label: entry.isRead ? 'Mark as unread' : 'Mark as read',
          icon: entry.isRead
              ? Icons.mark_email_unread_outlined
              : Icons.mark_email_read_outlined,
        ),
        const BottomSheetPickerItem(
          value: _RowAction.dismiss,
          label: 'Dismiss',
          icon: Icons.delete_outline,
          destructive: true,
        ),
      ],
    );
    if (picked == null) return;

    switch (picked) {
      case _RowAction.toggleRead:
        await _setRead(entry, !entry.isRead);
      case _RowAction.dismiss:
        await _dismiss(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return M3EFlexibleHeaderScaffold(
      title: 'Inbox',
      overline: 'PENDING NOTIFICATIONS',
      actions: [
        if (_entries.isNotEmpty)
          M3EIconButton(
            icon: Icons.more_horiz,
            tooltip: 'Bulk actions for all notifications',
            onPressed: _showBulkOptions,
          ),
      ],
      body: _loading && _entries.isEmpty
          ? const InboxSkeleton()
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _entries.isEmpty
                  ? (_error != null
                      // Offline and caught up are different answers and now
                      // look different. Retry is here as well as the pull,
                      // because a failed inbox is the one screen where a user
                      // has no rows to pull against.
                      ? ScrollableCenter(
                          padding: EdgeInsets.only(
                              bottom: appNavBarClearance(context)),
                          child: ErrorStateWidget(
                            message: _error,
                            onRetry: _refresh,
                          ),
                        )
                      : ScrollableEmptyState(
                          message: 'No notifications',
                          icon: Icons.inbox_outlined,
                          subtitle: 'Activity on your work items appears here',
                          padding: EdgeInsets.only(
                              bottom: appNavBarClearance(context)),
                        ))
                  // Rows are separated by the gap between their cards now, the
                  // same as every other list; a divider on top of that drew a
                  // line through the middle of the gap.
                  : ListView.builder(
                      padding:
                          EdgeInsets.only(bottom: appNavBarClearance(context)),
                      itemCount: _entries.length,
                      itemBuilder: (ctx, i) => _row(_entries[i]),
                    ),
            ),
    );
  }

  Widget _row(InboxEntry entry) {
    final identifier = entry.projectIdentifier ?? '';

    // A lightweight work item, so the inbox row is the same widget the lists
    // use rather than a second row that drifts from it.
    final issue = Issue(
      id: entry.issueId ?? '',
      name: entry.title,
      priority: entry.priority,
      sequenceId: entry.sequenceId,
      assignees: const [],
      labels: const [],
      createdAt: entry.createdAt,
      updatedAt: entry.createdAt,
      project: entry.projectId ?? '',
      state: null,
    );

    // Only the notification feed carries the work item's state group. An
    // activity row draws no state chip rather than a guessed one.
    final state = entry.stateGroup == null
        ? null
        : IssueState(
            id: '',
            name: entry.stateGroup!,
            group: entry.stateGroup!,
            color: '',
            sequence: 0,
          );

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      // Shaped and inset to match the card it is revealed behind. A square,
      // full-bleed block extended past the row's 16dp margins and its large
      // corner, so the red rectangle stuck out on all three sides.
      // `errorContainer` with `onErrorContainer` on it is the paired role; a
      // hand-mixed 20% `error` with full-strength `error` drawn on top is not.
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(M3EShape.large),
        ),
        child: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: PlaneTheme.iconLarge),
      ),
      onDismissed: (_) => _dismiss(entry),
      // Dismissing and marking read were reachable only by the swipe and by a
      // long-press declared on a GestureDetector that sat *above* IssueRow,
      // whose own node excludes its subtree and swallows the focus, so the
      // long-press was never associated with the row. Neither route leaves a
      // node behind, so the gap could not even be reported. The button in the
      // row's trailing slot is the reachable copy — that slot sits outside the
      // row's semantics node, which is what lets it keep its own label; both
      // gestures stay as accelerators.
      child: IssueRow(
        onLongPress: () => _showRowOptions(entry),
        trailing: M3EIconButton(
          icon: Icons.more_horiz,
          tooltip: 'Actions for notification ${entry.title}',
          size: M3EIconButtonSize.small,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          onPressed: () => _showRowOptions(entry),
        ),
        issue: issue,
        state: state,
        identifier: identifier.isNotEmpty ? identifier : null,
        subtitle: entry.description,
        showId: identifier.isNotEmpty,
        showPriority: true,
        unread: !entry.isRead,
        timeAgo: timeAgoShort(entry.createdAt),
        onTap: () {
          final projectId = entry.projectId ?? '';
          final issueId = entry.issueId ?? '';
          if (projectId.isEmpty || issueId.isEmpty) return;
          if (!entry.isRead) _setRead(entry, true);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IssueDetailScreen(
                workspaceSlug: widget.workspaceSlug,
                projectId: projectId,
                issueId: issueId,
                projectIdentifier: identifier,
                states: const {},
              ),
            ),
          );
        },
      ),
    );
  }
}
