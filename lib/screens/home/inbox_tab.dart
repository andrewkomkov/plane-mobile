import 'package:flutter/material.dart';
import '../../utils/say.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../config/secure_storage.dart';
import '../../config/theme.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
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

/// The actions the overflow sheet offers for one notification.
enum _RowAction { toggleRead, dismiss }

class InboxTab extends ConsumerStatefulWidget {
  final String workspaceSlug;
  const InboxTab({super.key, required this.workspaceSlug});

  @override
  ConsumerState<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends ConsumerState<InboxTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _notifications = [];
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
    if (old.workspaceSlug != widget.workspaceSlug) {
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
          _notifications = cached;
          _loading = false;
        });
      }
    } catch (_) {}

    // Then fetch from API in background.
    //
    // This stays on the mobile service's derived feed rather than Plane's
    // workspaces/{slug}/users/notifications/, which the Notifications screen
    // uses. Plane never notifies the actor of their own activity, so on a
    // deployment where one person does all the work its notifications table is
    // empty and that endpoint returns []. Reading it here would leave the
    // Inbox permanently blank.
    if (!_loaded && _notifications.isEmpty) {
      if (mounted) setState(() => _loading = true);
    }
    try {
      final baseUrl = await SecureStorage.getBaseUrl() ?? '';
      final apiKey = await SecureStorage.getApiKey() ?? '';
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {'X-Api-Key': apiKey, 'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final response = await dio.get(
        '/auth/mobile/${widget.workspaceSlug}/notifications/',
      );
      final results = (response.data['results'] as List?) ?? [];
      final items = results.cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _notifications = items;
          _loading = false;
          _loaded = true;
          _error = null;
        });
      }
      // Write to SQLite in background
      SyncService.writeInboxItems(widget.workspaceSlug, items);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loaded = true;
          // Only when nothing arrived at all. A refresh that fails over rows
          // already on screen keeps the rows — stale is better than empty, and
          // the cached read above is exactly that case.
          if (_notifications.isEmpty) {
            _error = 'Could not reach the server';
          }
        });
      }
    }
  }

  Future<void> _markRead(String notificationId) async {
    try {
      final baseUrl = await SecureStorage.getBaseUrl() ?? '';
      final apiKey = await SecureStorage.getApiKey() ?? '';
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {'X-Api-Key': apiKey, 'Content-Type': 'application/json'},
      ));
      await dio.post('/auth/mobile/notifications/$notificationId/read/');
      // Update local state
      if (mounted) {
        setState(() {
          final idx =
              _notifications.indexWhere((n) => n['id'] == notificationId);
          if (idx >= 0) _notifications[idx]['read_at'] = 'stored';
        });
      }
    } catch (_) {}
  }

  Future<void> _markUnread(String notificationId) async {
    try {
      final baseUrl = await SecureStorage.getBaseUrl() ?? '';
      final apiKey = await SecureStorage.getApiKey() ?? '';
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {'X-Api-Key': apiKey, 'Content-Type': 'application/json'},
      ));
      await dio.delete('/auth/mobile/notifications/$notificationId/read/');
      if (mounted) {
        setState(() {
          final idx =
              _notifications.indexWhere((n) => n['id'] == notificationId);
          if (idx >= 0) _notifications[idx]['read_at'] = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _dismiss(String notificationId) async {
    // Optimistically remove from list
    final removed = _notifications.firstWhere((n) => n['id'] == notificationId,
        orElse: () => {});
    setState(() {
      _notifications.removeWhere((n) => n['id'] == notificationId);
    });
    try {
      final baseUrl = await SecureStorage.getBaseUrl() ?? '';
      final apiKey = await SecureStorage.getApiKey() ?? '';
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {'X-Api-Key': apiKey, 'Content-Type': 'application/json'},
      ));
      await dio.delete('/auth/mobile/notifications/$notificationId/');
    } catch (_) {
      // Restore on failure
      if (mounted && removed.isNotEmpty) {
        setState(() => _notifications.add(removed));
      }
    }
  }

  /// Mark everything currently listed as read.
  ///
  /// One request, not one per row: the shim keeps read state in a JSON file
  /// and rewrites the whole thing on every write, so looping the per-item
  /// route would rewrite it once per notification. The server derives "all"
  /// from the same membership-scoped feed this screen shows, so a bulk action
  /// can never touch a row the caller cannot see.
  Future<void> _markAllRead() async {
    final before = [
      for (final n in _notifications) Map<String, dynamic>.from(n),
    ];
    setState(() {
      for (final n in _notifications) {
        n['read_at'] ??= 'stored';
      }
    });
    try {
      final dio = await _dio();
      await dio
          .post('/auth/mobile/${widget.workspaceSlug}/notifications/read-all/');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notifications
          ..clear()
          ..addAll(before);
      });
      _complain('Could not mark them read');
    }
  }

  /// Dismiss everything currently listed.
  ///
  /// Kept behind a confirmation because it clears the whole screen and the
  /// only way back is per-notification on the web.
  Future<void> _dismissAll() async {
    final removed = [
      for (final n in _notifications) Map<String, dynamic>.from(n),
    ];
    setState(_notifications.clear);
    try {
      final dio = await _dio();
      await dio.delete('/auth/mobile/${widget.workspaceSlug}/notifications/');
    } catch (_) {
      if (!mounted) return;
      setState(() => _notifications.addAll(removed));
      _complain('Could not dismiss them');
    }
  }

  Future<Dio> _dio() async {
    final baseUrl = await SecureStorage.getBaseUrl() ?? '';
    final apiKey = await SecureStorage.getApiKey() ?? '';
    return Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {'X-Api-Key': apiKey, 'Content-Type': 'application/json'},
    ));
  }

  void _complain(String message) {
    say(context, message);
  }

  Future<void> _refresh() async {
    _loaded = false;
    await _load();
  }

  /// Actions for the whole list.
  ///
  /// Both this and the per-row menu are [BottomSheetPicker] now. What they
  /// replace was a hand-rolled sheet that overrode the background to
  /// transparent, rebuilt the surface itself, painted a *second* drag handle
  /// under the one `bottomSheetTheme` already draws, and filled itself with
  /// `ListTile` ink — the last interaction surface on this screen that
  /// answered a press with a ripple instead of the app's spring.
  Future<void> _showBulkOptions() async {
    final unread = _notifications.where((n) => n['read_at'] == null).length;
    final picked = await BottomSheetPicker.show<_BulkAction>(
      context: context,
      title: 'All notifications',
      subtitle: '${_notifications.length} in the list',
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
          subtitle: 'Only the web app can bring them back',
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
          message: 'This clears the whole list. Individual notifications can '
              'only be brought back from the web app.',
          confirmLabel: 'Dismiss all',
        );
        if (ok) await _dismissAll();
    }
  }

  Future<void> _showNotificationOptions(Map<String, dynamic> n) async {
    final notificationId = n['id'] as String? ?? '';
    final isRead = n['read_at'] != null;
    final title = (n['title'] ?? '') as String;

    final picked = await BottomSheetPicker.show<_RowAction>(
      context: context,
      // Named, because the sheet can be opened from any of a screenful of
      // identical-looking rows.
      title: title.isEmpty ? 'Notification' : title,
      items: [
        BottomSheetPickerItem(
          value: _RowAction.toggleRead,
          label: isRead ? 'Mark as unread' : 'Mark as read',
          icon: isRead
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
        if (isRead) {
          await _markUnread(notificationId);
        } else {
          await _markRead(notificationId);
        }
      case _RowAction.dismiss:
        await _dismiss(notificationId);
    }
  }

  String _buildActivityText(Map<String, dynamic> n) {
    final actor = n['actor_name'] ?? '';
    final field = n['activity_field'] ?? '';
    final verb = n['activity_verb'] ?? '';
    final newVal = n['activity_new_value'] ?? '';

    if (field.isEmpty) {
      if (verb == 'created') return '$actor created the issue';
      return '$actor updated the issue';
    }
    if (field == 'comment') return '$actor commented';
    if (field == 'assignees') return '$actor changed assignee';
    if (field == 'state') return '$actor changed status to $newVal';
    if (field == 'priority') return '$actor set priority to $newVal';
    if (newVal.isNotEmpty) return '$actor set $field to $newVal';
    return '$actor updated $field';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return M3EFlexibleHeaderScaffold(
      title: 'Inbox',
      overline: 'PENDING NOTIFICATIONS',
      actions: [
        if (_notifications.isNotEmpty)
          M3EIconButton(
            icon: Icons.more_horiz,
            tooltip: 'Bulk actions for all notifications',
            onPressed: _showBulkOptions,
          ),
      ],
      body: _loading && _notifications.isEmpty
          ? const InboxSkeleton()
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _notifications.isEmpty
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
                          subtitle: 'Activity on your issues will appear here',
                          padding: EdgeInsets.only(
                              bottom: appNavBarClearance(context)),
                        ))
                  // Rows are separated by the gap between their cards now, the
                  // same as every other list; a divider on top of that drew a
                  // line through the middle of the gap.
                  : ListView.builder(
                      padding:
                          EdgeInsets.only(bottom: appNavBarClearance(context)),
                      itemCount: _notifications.length,
                      itemBuilder: (ctx, i) {
                        final n = _notifications[i];
                        final isRead = n['read_at'] != null;
                        final notificationId = (n['id'] ?? '') as String;
                        final stateGroup =
                            (n['state_group'] ?? 'backlog') as String;
                        final projectId =
                            (n['project'] ?? n['project_id'] ?? '') as String;
                        final issueId = (n['issue_id'] ?? '') as String;
                        final identifier = n['project_identifier'] ?? '';
                        final title = (n['title'] ?? '') as String;
                        final activityText = _buildActivityText(n);
                        final createdAt =
                            DateTime.tryParse(n['created_at'] ?? '');
                        final priority = (n['priority'] ?? 'none') as String;
                        final seqId = n['sequence_id'] ?? 0;

                        // Build a lightweight Issue for IssueRow
                        final issue = Issue(
                          id: issueId,
                          name: title,
                          priority: priority,
                          sequenceId: seqId is int
                              ? seqId
                              : int.tryParse(seqId.toString()) ?? 0,
                          assignees: const [],
                          labels: const [],
                          createdAt: createdAt ?? DateTime.now(),
                          updatedAt: createdAt ?? DateTime.now(),
                          project: projectId,
                          state: null,
                        );

                        final fakeState = IssueState(
                          id: '',
                          name: stateGroup,
                          group: stateGroup,
                          color: '',
                          sequence: 0,
                        );

                        return Dismissible(
                          key: ValueKey(notificationId),
                          direction: DismissDirection.endToStart,
                          // Shaped and inset to match the card it is revealed
                          // behind. A square, full-bleed block extended past
                          // the row's 16dp margins and its large corner, so
                          // the red rectangle stuck out on all three sides.
                          // `errorContainer` with `onErrorContainer` on it is
                          // the paired role; a hand-mixed 20% `error` with
                          // full-strength `error` drawn on top is not.
                          background: Container(
                            alignment: Alignment.centerRight,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).colorScheme.errorContainer,
                              borderRadius:
                                  BorderRadius.circular(M3EShape.large),
                            ),
                            child: Icon(Icons.delete_outline,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                                size: PlaneTheme.iconLarge),
                          ),
                          onDismissed: (_) => _dismiss(notificationId),
                          // Dismissing and marking read were reachable only by
                          // the swipe and by a long-press declared on this
                          // GestureDetector — which sits *above* IssueRow,
                          // whose own node excludes its subtree and swallows
                          // the focus, so the long-press was never associated
                          // with the row. Neither route leaves a node behind,
                          // so the gap could not even be reported. The button
                          // in the row's trailing slot is the reachable copy —
                          // that slot sits outside the row's semantics node,
                          // which is what lets it keep its own label; both
                          // gestures stay as accelerators.
                          child: IssueRow(
                            onLongPress: () => _showNotificationOptions(n),
                            trailing: M3EIconButton(
                              icon: Icons.more_horiz,
                              tooltip: 'Actions for notification $title',
                              size: M3EIconButtonSize.small,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              onPressed: () => _showNotificationOptions(n),
                            ),
                            issue: issue,
                            state: fakeState,
                            identifier:
                                identifier.isNotEmpty ? identifier : null,
                            subtitle: activityText,
                            showId: identifier.isNotEmpty,
                            showPriority: true,
                            unread: !isRead,
                            timeAgo: createdAt != null
                                ? timeAgoShort(createdAt)
                                : null,
                            onTap: () {
                              if (projectId.isEmpty || issueId.isEmpty) {
                                return;
                              }
                              // Mark as read on tap
                              if (!isRead && notificationId.isNotEmpty) {
                                _markRead(notificationId);
                              }
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
                      },
                    ),
            ),
    );
  }
}
