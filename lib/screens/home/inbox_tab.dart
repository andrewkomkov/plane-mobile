import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../config/secure_storage.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../utils/time_ago.dart';
import '../../database/sync_service.dart';
import '../issues/issue_detail_screen.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/skeleton_loader.dart';
import '../../config/m3e/shapes.dart';
import '../../widgets/m3e/flexible_app_bar.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/issue_row.dart';

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
        });
      }
      // Write to SQLite in background
      SyncService.writeInboxItems(widget.workspaceSlug, items);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loaded = true;
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// The screen's one bottom-sheet treatment.
  ///
  /// M3E shape and a drag handle, matching the More sheet in app_navbar. The
  /// per-item menu and the bulk menu share it so one screen does not grow two
  /// different sheets.
  Future<void> _showSheet(List<Widget> children) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(M3EShape.extraLargeIncreased),
            ),
            border: Border(
              top: BorderSide(color: scheme.outlineVariant, width: 0.5),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(M3EShape.full),
                  ),
                ),
                const SizedBox(height: 12),
                ...children,
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBulkOptions() {
    final unread = _notifications.where((n) => n['read_at'] == null).length;
    _showSheet([
      ListTile(
        leading: const Icon(Icons.mark_email_read_outlined, size: 20),
        title: Text('Mark all as read',
            style: Theme.of(context).textTheme.bodyMedium),
        // The count is the whole reason to reach for this rather than tapping
        // rows, so it belongs on the control.
        subtitle: Text(unread == 0 ? 'Nothing unread' : '$unread unread',
            style: Theme.of(context).textTheme.bodySmall),
        enabled: unread > 0,
        onTap: () {
          Navigator.pop(context);
          _markAllRead();
        },
      ),
      ListTile(
        leading: Icon(Icons.delete_sweep_outlined,
            size: 20, color: Theme.of(context).colorScheme.error),
        title: Text('Dismiss all',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                )),
        subtitle: Text('${_notifications.length} in the list',
            style: Theme.of(context).textTheme.bodySmall),
        onTap: () async {
          Navigator.pop(context);
          if (await _confirmDismissAll()) _dismissAll();
        },
      ),
    ]);
  }

  Future<bool> _confirmDismissAll() async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dismiss all notifications?'),
        content: Text(
          'This clears the whole list. Individual notifications can only be '
          'brought back from the web app.',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('Dismiss all'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  void _showNotificationOptions(Map<String, dynamic> n) {
    final notificationId = n['id'] as String? ?? '';
    final isRead = n['read_at'] != null;
    _showSheet([
      ListTile(
        leading: Icon(
            isRead
                ? Icons.mark_email_unread_outlined
                : Icons.mark_email_read_outlined,
            size: 20),
        title: Text(isRead ? 'Mark as unread' : 'Mark as read',
            style: Theme.of(context).textTheme.bodyMedium),
        onTap: () {
          Navigator.pop(context);
          if (isRead) {
            _markUnread(notificationId);
          } else {
            _markRead(notificationId);
          }
        },
      ),
      ListTile(
        leading: const Icon(Icons.delete_outline, size: 20),
        title: Text('Dismiss', style: Theme.of(context).textTheme.bodyMedium),
        onTap: () {
          Navigator.pop(context);
          _dismiss(notificationId);
        },
      ),
    ]);
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
              onRefresh: () async {
                _loaded = false;
                await _load();
              },
              child: _notifications.isEmpty
                  ? ListView(children: [
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3),
                      const Center(
                        child: EmptyStateWidget(
                          message: 'No notifications',
                          icon: Icons.inbox_outlined,
                          subtitle: 'Activity on your issues will appear here',
                        ),
                      ),
                    ])
                  // Rows are separated by the gap between their cards now, the
                  // same as every other list; a divider on top of that drew a
                  // line through the middle of the gap.
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
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
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.20),
                            child: Icon(Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error,
                                size: 22),
                          ),
                          onDismissed: (_) => _dismiss(notificationId),
                          child: GestureDetector(
                            onLongPress: () => _showNotificationOptions(n),
                            child: IssueRow(
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
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
