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
import '../../widgets/m3e/flexible_app_bar.dart';
import '../../widgets/issue_tile.dart';

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
      final cached =
          await SyncService.readInboxItems(widget.workspaceSlug);
      if (cached != null && cached.isNotEmpty && mounted) {
        setState(() {
          _notifications = cached;
          _loading = false;
        });
      }
    } catch (_) {}

    // Then fetch from API in background
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
          final idx = _notifications.indexWhere((n) => n['id'] == notificationId);
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
          final idx = _notifications.indexWhere((n) => n['id'] == notificationId);
          if (idx >= 0) _notifications[idx]['read_at'] = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _dismiss(String notificationId) async {
    // Optimistically remove from list
    final removed = _notifications.firstWhere((n) => n['id'] == notificationId, orElse: () => {});
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

  void _showNotificationOptions(Map<String, dynamic> n) {
    final notificationId = n['id'] as String? ?? '';
    final isRead = n['read_at'] != null;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isRead ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined, size: 20),
              title: Text(isRead ? 'Mark as unread' : 'Mark as read',
                  style: const TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                if (isRead) {
                  _markUnread(notificationId);
                } else {
                  _markRead(notificationId);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, size: 20),
              title: const Text('Dismiss', style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                _dismiss(notificationId);
              },
            ),
          ],
        ),
      ),
    );
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
      body: _loading && _notifications.isEmpty
          ? const InboxSkeleton()
          : RefreshIndicator(
              onRefresh: () async {
                _loaded = false;
                await _load();
              },
              child: _notifications.isEmpty
                  ? ListView(children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      const Center(
                        child: EmptyStateWidget(
                          message: 'No notifications',
                          icon: Icons.inbox_outlined,
                          subtitle: 'Activity on your issues will appear here',
                        ),
                      ),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const Divider(
                          indent: 60, endIndent: 20, height: 0.5, thickness: 0.5),
                      itemBuilder: (ctx, i) {
                        final n = _notifications[i];
                        final isRead = n['read_at'] != null;
                        final notificationId = (n['id'] ?? '') as String;
                        final stateGroup = (n['state_group'] ?? 'backlog') as String;
                        final projectId = (n['project'] ?? n['project_id'] ?? '') as String;
                        final issueId = (n['issue_id'] ?? '') as String;
                        final identifier = n['project_identifier'] ?? '';
                        final title = (n['title'] ?? '') as String;
                        final activityText = _buildActivityText(n);
                        final createdAt = DateTime.tryParse(n['created_at'] ?? '');
                        final priority = (n['priority'] ?? 'none') as String;
                        final seqId = n['sequence_id'] ?? 0;

                        // Build a lightweight Issue for IssueTile
                        final issue = Issue(
                          id: issueId,
                          name: title,
                          priority: priority,
                          sequenceId: seqId is int ? seqId : int.tryParse(seqId.toString()) ?? 0,
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
                            child: IssueTile(
                              issue: issue,
                              state: fakeState,
                              projectIdentifier: identifier.isNotEmpty ? identifier : null,
                              subtitle: activityText,
                              showId: identifier.isNotEmpty,
                              showPriority: true,
                              isUnread: !isRead,
                              timeAgo: createdAt != null ? timeAgoShort(createdAt) : null,
                              onTap: () {
                                if (projectId.isEmpty || issueId.isEmpty) return;
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
