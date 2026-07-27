import 'package:flutter/material.dart';
import '../../utils/api_error.dart';
import '../../widgets/skeleton_loader.dart';
import '../../utils/say.dart';
import '../../config/theme.dart';
import '../../widgets/bottom_sheet_picker.dart';
import '../../config/m3e/motion.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/icon_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/m3e/typography.dart';
import '../../services/notification_service.dart';
import '../../models/notification.dart';
import '../../utils/time_ago.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/section_header.dart';
import '../issues/issue_detail_screen.dart';
import '../../services/issue_service.dart';
import '../../models/state.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  const NotificationScreen({super.key, required this.workspaceSlug});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  List<PlaneNotification> _notifications = [];
  bool _loading = true;
  String? _error;

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
      final notifications = await NotificationService.getNotifications(
        snoozed: false,
        archived: false,
      );
      setState(() {
        _notifications = notifications;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await NotificationService.markAllAsRead();
      _load();
    } catch (e) {
      if (mounted) {
        sayError(context,
            describeApiError(e, fallback: 'Could not reach notifications'));
      }
    }
  }

  /// Archives a notification, and offers the way back.
  ///
  /// A single swipe took a row out of the feed and reloaded the list, with
  /// nothing to say it had happened and nothing to undo it — and the feed has
  /// no archived view, so a notification archived by accident was gone as far
  /// as this app was concerned. Plane's archive is reversible
  /// ([NotificationService.unarchive]), so the swipe gets a snackbar with the
  /// reverse behind it.
  ///
  /// The row is dropped locally rather than by reloading: `_load()` refetches
  /// the whole feed and flashes the skeleton, which is a heavy answer to one
  /// row leaving and would fight the undo it is offering.
  Future<void> _archive(PlaneNotification notification) async {
    final index = _notifications.indexWhere((n) => n.id == notification.id);
    if (index < 0) return;
    setState(() => _notifications.removeAt(index));
    try {
      await NotificationService.archive(notification.id);
      if (!mounted) return;
      sayUndo(
        context,
        'Notification archived',
        () => _unarchive(notification, index),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _notifications.insert(
          index.clamp(0, _notifications.length), notification));
      sayError(context,
          describeApiError(e, fallback: 'Could not reach notifications'));
    }
  }

  /// Undo: puts an archived notification back where it was in the feed.
  Future<void> _unarchive(PlaneNotification notification, int index) async {
    if (_notifications.any((n) => n.id == notification.id)) return;
    setState(() => _notifications.insert(
        index.clamp(0, _notifications.length), notification));
    try {
      await NotificationService.unarchive(notification.id);
    } catch (e) {
      if (!mounted) return;
      setState(
          () => _notifications.removeWhere((n) => n.id == notification.id));
      sayError(context,
          describeApiError(e, fallback: 'Could not restore the notification'));
    }
  }

  Future<void> _onTap(PlaneNotification notification) async {
    // Mark as read
    if (!notification.isRead) {
      try {
        await NotificationService.markAsRead(notification.id);
      } catch (_) {}
    }

    // Navigate to issue if possible
    final issueId = notification.issueId;
    final projectId = notification.projectId;
    if (issueId != null && projectId != null && mounted) {
      Map<String, IssueState> states = {};
      try {
        final stateList =
            await IssueService.getStates(widget.workspaceSlug, projectId);
        states = {for (var s in stateList) s.id: s};
      } catch (_) {}

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IssueDetailScreen(
              workspaceSlug: widget.workspaceSlug,
              projectId: projectId,
              issueId: issueId,
              states: states,
            ),
          ),
        );
        _load();
      }
    }
  }

  Future<void> _showNotificationSettings() async {
    Map<String, dynamic> prefs;
    try {
      prefs = await NotificationService.getNotificationPreferences();
    } catch (e) {
      if (mounted) {
        sayError(context,
            describeApiError(e, fallback: 'Failed to load preferences'));
      }
      return;
    }
    if (!mounted) return;

    // One sheet, one write. Four `SwitchListTile`s each fired their own PATCH
    // as they were flicked, so turning three off was three round trips and a
    // half-applied state if the second failed.
    const options = [
      (
        'property_change',
        'Property changes',
        'Issue priority, assignee, label changes'
      ),
      ('state_change', 'State changes', 'Issue state transitions'),
      ('comment', 'Comments', 'New comments on your issues'),
      ('mention', 'Mentions', 'When someone mentions you'),
    ];
    final before = {
      for (final o in options)
        if (prefs[o.$1] as bool? ?? true) o.$1,
    };

    final after = await MultiSelectSheet.show<String>(
      context: context,
      title: 'Email notification preferences',
      subtitle: 'Email me about',
      selected: before,
      items: [
        for (final o in options)
          BottomSheetPickerItem(value: o.$1, label: o.$2, subtitle: o.$3),
      ],
    );
    if (after == null) return;

    final changed = {
      for (final o in options)
        if (before.contains(o.$1) != after.contains(o.$1))
          o.$1: after.contains(o.$1),
    };
    if (changed.isEmpty) return;
    try {
      await NotificationService.updateNotificationPreferences(changed);
    } catch (e) {
      if (mounted) {
        sayError(context,
            describeApiError(e, fallback: 'Could not reach notifications'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: M3EAppBar(
        title: 'Notifications',
        actions: [
          if (_notifications.any((n) => !n.isRead))
            M3EAppBarAction(
              icon: Icons.done_all,
              tooltip: 'Mark all read',
              onPressed: _markAllAsRead,
            ),
          M3EAppBarAction(
            icon: Icons.settings_outlined,
            tooltip: 'Notification settings',
            onPressed: _showNotificationSettings,
          ),
        ],
      ),
      body: _loading
          // The same skeleton the home inbox uses for the same feed. This was
          // a spinner while its twin two taps away shimmered rows.
          ? const InboxSkeleton()
          : _error != null
              ? ErrorStateWidget(
                  message: 'Failed to load notifications', onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _notifications.isEmpty
                      // The last spacer-and-ListView empty state in the app.
                      // The 0.3 was never about spacing: it was there to make
                      // the list tall enough to pull, which is what
                      // ScrollableEmptyState says properly.
                      ? const ScrollableEmptyState(
                          message: 'No notifications',
                          icon: Icons.notifications_none,
                          subtitle: 'You\'re all caught up',
                        )
                      : _buildGroupedList(theme),
                ),
    );
  }

  Widget _buildGroupedList(ThemeData theme) {
    final unread = _notifications.where((n) => !n.isRead).toList();
    final read = _notifications.where((n) => n.isRead).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        if (unread.isNotEmpty) ...[
          SectionHeader(
            label: 'UNREAD',
            count: unread.length,
            color: theme.colorScheme.primary,
          ),
          ...unread.map((n) => _buildNotificationTile(n, theme)),
        ],
        if (read.isNotEmpty) ...[
          const SectionHeader(label: 'READ'),
          ...read.map((n) => _buildNotificationTile(n, theme)),
        ],
      ],
    );
  }

  /// Everything the row draws, in one string.
  ///
  /// [M3EPressable] replaces the subtree's semantics with this label, so the
  /// unread dot, the entity and the timestamp exist for a screen reader only
  /// if they are spelled out here — the same contract `PlaneRow` documents.
  String _semanticLabel(PlaneNotification notification) => [
        notification.title,
        if (notification.entityName != null) notification.entityName!,
        timeAgoShort(notification.createdAt),
        if (!notification.isRead) 'unread',
      ].join(', ');

  Widget _buildNotificationTile(
      PlaneNotification notification, ThemeData theme) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.error.withValues(alpha: 0.15),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.archive,
            color: theme.colorScheme.error, size: PlaneTheme.iconLarge),
      ),
      onDismissed: (_) => _archive(notification),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: notification.isRead
              ? null
              : theme.colorScheme.primary.withValues(alpha: 0.04),
          border: Border(
            bottom:
                BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
          ),
        ),
        // The archive button sits outside the pressable rather than inside it,
        // the same split `PlaneRow` makes for its trailing slot: the row's
        // label excludes its subtree, so a button drawn inside would lose its
        // own name and stop being reachable.
        child: Row(
          children: [
            Expanded(
              child: M3EPressable(
                // Required in practice, not decoration: without it the row is
                // an anonymous node and the whole feed is unreachable both to
                // a screen reader and to `tool/adb_drive.py tap`.
                semanticLabel: _semanticLabel(notification),
                onTap: () => _onTap(notification),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 9, 10, 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!notification.isRead)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 8),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      if (notification.isRead) const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              // Read and unread share one role so the two rows
                              // keep identical metrics; unread takes the
                              // emphasized cut.
                              style: notification.isRead
                                  ? theme.textTheme.titleMedium
                                  : M3EType.emphasized(
                                      theme.textTheme.titleMedium!),
                            ),
                            if (notification.entityName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                notification.entityName!,
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              timeAgoShort(notification.createdAt),
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Archiving used to be the swipe and nothing else. A swipe has no
            // node, so it is not merely hard to reach without sight — it
            // cannot even be reported missing by `adb_drive.py check`. The
            // swipe stays as the accelerator.
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: M3EIconButton(
                icon: Icons.archive_outlined,
                tooltip: 'Archive ${notification.title}',
                size: M3EIconButtonSize.small,
                color: theme.colorScheme.onSurfaceVariant,
                onPressed: () => _archive(notification),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
