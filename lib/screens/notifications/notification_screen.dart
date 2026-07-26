import 'package:flutter/material.dart';
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _archive(PlaneNotification notification) async {
    try {
      await NotificationService.archive(notification.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
    final theme = Theme.of(context);

    Map<String, dynamic> prefs;
    try {
      prefs = await NotificationService.getNotificationPreferences();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load preferences: $e')));
      }
      return;
    }
    if (!mounted) return;

    bool propertyChange = prefs['property_change'] as bool? ?? true;
    bool stateChange = prefs['state_change'] as bool? ?? true;
    bool comment = prefs['comment'] as bool? ?? true;
    bool mention = prefs['mention'] as bool? ?? true;

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> update(String key, bool value) async {
            try {
              await NotificationService.updateNotificationPreferences(
                  {key: value});
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Email notification preferences',
                      style: theme.textTheme.titleMedium),
                ),
                SwitchListTile(
                  title: Text('Property changes',
                      style: theme.textTheme.bodyLarge),
                  subtitle: Text('Issue priority, assignee, label changes',
                      style: theme.textTheme.bodySmall),
                  value: propertyChange,
                  onChanged: (v) {
                    setSheetState(() => propertyChange = v);
                    update('property_change', v);
                  },
                ),
                SwitchListTile(
                  title:
                      Text('State changes', style: theme.textTheme.bodyLarge),
                  subtitle: Text('Issue state transitions',
                      style: theme.textTheme.bodySmall),
                  value: stateChange,
                  onChanged: (v) {
                    setSheetState(() => stateChange = v);
                    update('state_change', v);
                  },
                ),
                SwitchListTile(
                  title: Text('Comments', style: theme.textTheme.bodyLarge),
                  subtitle: Text('New comments on your issues',
                      style: theme.textTheme.bodySmall),
                  value: comment,
                  onChanged: (v) {
                    setSheetState(() => comment = v);
                    update('comment', v);
                  },
                ),
                SwitchListTile(
                  title: Text('Mentions', style: theme.textTheme.bodyLarge),
                  subtitle: Text('When someone mentions you',
                      style: theme.textTheme.bodySmall),
                  value: mention,
                  onChanged: (v) {
                    setSheetState(() => mention = v);
                    update('mention', v);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
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
          ? const LoadingStateWidget()
          : _error != null
              ? ErrorStateWidget(
                  message: 'Failed to load notifications', onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _notifications.isEmpty
                      ? ListView(children: [
                          SizedBox(
                              height: MediaQuery.of(context).size.height * 0.3),
                          const Center(
                            child: EmptyStateWidget(
                              message: 'No notifications',
                              icon: Icons.notifications_none,
                              subtitle: 'You\'re all caught up',
                            ),
                          ),
                        ])
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
        child: Icon(Icons.archive, color: theme.colorScheme.error, size: 22),
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
