import 'package:flutter/material.dart';
import '../../config/m3e/motion.dart';
import '../../widgets/m3e/app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
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
  ConsumerState<NotificationScreen> createState() =>
      _NotificationScreenState();
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
        final stateList = await IssueService.getStates(
            widget.workspaceSlug, projectId);
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load preferences: $e')));
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
                      style: TextStyle(
                          fontSize: PlaneTheme.fontBody,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface)),
                ),
                SwitchListTile(
                  title: const Text('Property changes',
                      style: TextStyle(fontSize: PlaneTheme.fontBody)),
                  subtitle: const Text('Issue priority, assignee, label changes',
                      style: TextStyle(fontSize: PlaneTheme.fontCaption)),
                  value: propertyChange,
                  onChanged: (v) {
                    setSheetState(() => propertyChange = v);
                    update('property_change', v);
                  },
                ),
                SwitchListTile(
                  title: const Text('State changes',
                      style: TextStyle(fontSize: PlaneTheme.fontBody)),
                  subtitle: const Text('Issue state transitions',
                      style: TextStyle(fontSize: PlaneTheme.fontCaption)),
                  value: stateChange,
                  onChanged: (v) {
                    setSheetState(() => stateChange = v);
                    update('state_change', v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Comments',
                      style: TextStyle(fontSize: PlaneTheme.fontBody)),
                  subtitle: const Text('New comments on your issues',
                      style: TextStyle(fontSize: PlaneTheme.fontCaption)),
                  value: comment,
                  onChanged: (v) {
                    setSheetState(() => comment = v);
                    update('comment', v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Mentions',
                      style: TextStyle(fontSize: PlaneTheme.fontBody)),
                  subtitle: const Text('When someone mentions you',
                      style: TextStyle(fontSize: PlaneTheme.fontCaption)),
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
                  message: 'Failed to load notifications',
                  onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _notifications.isEmpty
                      ? ListView(children: [
                          SizedBox(
                              height:
                                  MediaQuery.of(context).size.height *
                                      0.3),
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
    final unread =
        _notifications.where((n) => !n.isRead).toList();
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

  Widget _buildNotificationTile(
      PlaneNotification notification, ThemeData theme) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.error.withValues(alpha: 0.15),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child:
            Icon(Icons.archive, color: theme.colorScheme.error, size: 22),
      ),
      onDismissed: (_) => _archive(notification),
      child: M3EPressable(
        pressedScale: 0.985,
        onTap: () => _onTap(notification),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            color: notification.isRead
                ? null
                : theme.colorScheme.primary.withValues(alpha: 0.04),
            border: Border(
              bottom: BorderSide(
                  color: theme.colorScheme.outline, width: 0.3),
            ),
          ),
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
                      style: TextStyle(
                        fontSize: PlaneTheme.fontBody,
                        fontWeight: notification.isRead
                            ? PlaneTheme.fontBodyWeight
                            : FontWeight.w500,
                      ),
                    ),
                    if (notification.entityName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.entityName!,
                        style: TextStyle(
                            fontSize: PlaneTheme.fontCaption,
                            color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      timeAgoShort(notification.createdAt),
                      style: TextStyle(
                          fontSize: PlaneTheme.fontSmall,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
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
