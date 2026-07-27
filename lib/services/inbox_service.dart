import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_client.dart';
import '../database/app_database.dart';
import '../models/inbox_entry.dart';
import 'notification_service.dart';

/// The Inbox feed, assembled entirely from Plane's own endpoints.
///
/// This used to be a SQL query inside `plane-mobile-api`, selecting
/// `issue_activities` joined to `project_members` by hand. It read correctly,
/// but the authorisation was ours to get wrong — and the first version of it
/// was wrong, selecting on the workspace slug alone so any token in the
/// instance could read any workspace's activity. Nothing here can have that
/// bug, because nothing here decides who may see what: both sources are
/// Plane's, behind Plane's own permission classes, through the proxy.
///
/// **Two sources, because Plane keeps two feeds.**
///
/// `workspaces/{slug}/users/notifications/` is the real one: a `Notification`
/// row per event, with `read_at` and `archived_at` the server stores, so
/// marking one read is a write every device sees.
///
/// `workspaces/{slug}/user-activity/{user_id}/` is the caller's own activity.
/// It is here because of a fact about Plane that took a while to establish:
/// **Plane never notifies you about what you did**. `notification_task`
/// subtracts the actor from the subscriber set twice over, so on a workspace
/// where one person does the work no `Notification` row is ever written and
/// the first source is correctly, permanently empty. Reading only that one
/// leaves the screen blank on exactly the deployment this app was built for.
/// `WorkspaceUserActivityEndpoint` carries `WorkspaceEntityPermission` and
/// filters `project__project_projectmember__member=request.user`, which is the
/// same scoping the hand-rolled join was reaching for.
///
/// **Read state differs by source, and has to.** A notification's is Plane's.
/// An activity row has no per-user state anywhere on the server — there is no
/// column to write — so this device records it in SQLite. That is a narrower
/// blast radius than what it replaces: the shim kept every user's read and
/// dismissed ids in one JSON file and rewrote the whole file on every request,
/// so two concurrent writes lost one of them outright.
class InboxService {
  /// Injected by tests in place of a real HTTP client, the same seam
  /// [NotificationService] uses.
  @visibleForTesting
  static Dio? debugClient;

  static Future<Dio> _client() async {
    final injected = debugClient;
    if (injected != null) return injected;
    return ApiClient.getInstance();
  }

  /// How far back the feed reaches. Plane paginates both sources; one page of
  /// each is what the screen shows.
  static const int pageSize = 30;

  /// The merged feed, newest first.
  ///
  /// Either source failing leaves the other's rows in place rather than
  /// failing the whole screen — on a single-operator instance the
  /// notifications half is legitimately empty, and a workspace where the
  /// caller is a guest can 403 the activity half.
  static Future<List<InboxEntry>> feed({
    required String workspaceSlug,
    required String userId,
  }) async {
    final results = await Future.wait([
      _notifications(),
      _activity(workspaceSlug, userId),
    ]);

    final notifications = results[0];
    final activity = results[1];

    // An event that raised a notification also has an activity row. Plane
    // names the triggering activity in the notification's `data`, so the
    // duplicate can be dropped rather than shown twice.
    final covered = <String>{};
    for (final entry in notifications) {
      final activityId = _activityIdIndex[entry.id];
      if (activityId != null) covered.add(activityId);
    }

    final merged = <InboxEntry>[
      ...notifications,
      ...activity.where((a) => !covered.contains(a.id)),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return merged;
  }

  /// notification id -> the activity id it was raised for, filled by
  /// [_notifications] so [feed] can dedupe without re-parsing.
  static final Map<String, String> _activityIdIndex = {};

  static Future<List<InboxEntry>> _notifications() async {
    try {
      final rows = await NotificationService.getNotifications(archived: false);
      _activityIdIndex.clear();
      final entries = <InboxEntry>[];
      for (final n in rows) {
        final activityId = InboxEntry.activityIdOf(n);
        if (activityId != null) _activityIdIndex[n.id] = activityId;
        entries.add(InboxEntry.fromNotification(n));
      }
      return entries;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<InboxEntry>> _activity(String slug, String userId) async {
    if (slug.isEmpty || userId.isEmpty) return const [];
    try {
      final dio = await _client();
      final response = await dio.get(
        '/workspaces/$slug/user-activity/$userId/',
        queryParameters: {'per_page': pageSize},
      );
      final data = response.data;
      final list = data is Map && data.containsKey('results')
          ? data['results'] as List
          : (data is List ? data : const []);

      final localState = await AppDatabase.getInboxLocalState(slug);
      final entries = <InboxEntry>[];
      for (final raw in list) {
        if (raw is! Map) continue;
        final json = Map<String, dynamic>.from(raw);
        final id = (json['id'] ?? '').toString();
        if (localState.dismissed.contains(id)) continue;
        entries.add(InboxEntry.fromActivity(
          json,
          isRead: localState.read.contains(id),
        ));
      }
      return entries;
    } catch (_) {
      return const [];
    }
  }

  /// Mark one row read, wherever its read state lives.
  static Future<void> markRead(String slug, InboxEntry entry) async {
    if (entry.kind == InboxEntryKind.notification) {
      await NotificationService.markAsRead(entry.id);
    } else {
      await AppDatabase.setInboxRead(slug, entry.id, true);
    }
  }

  static Future<void> markUnread(String slug, InboxEntry entry) async {
    if (entry.kind == InboxEntryKind.notification) {
      await NotificationService.markAsUnread(entry.id);
    } else {
      await AppDatabase.setInboxRead(slug, entry.id, false);
    }
  }

  /// Take one row off the feed.
  ///
  /// A notification is archived, which Plane can undo. An activity row is
  /// dismissed on this device only — there is nothing to archive server-side —
  /// and [undismiss] puts it back.
  static Future<void> dismiss(String slug, InboxEntry entry) async {
    if (entry.kind == InboxEntryKind.notification) {
      await NotificationService.archive(entry.id);
    } else {
      await AppDatabase.setInboxDismissed(slug, entry.id, true);
    }
  }

  static Future<void> undismiss(String slug, InboxEntry entry) async {
    if (entry.kind == InboxEntryKind.notification) {
      await NotificationService.unarchive(entry.id);
    } else {
      await AppDatabase.setInboxDismissed(slug, entry.id, false);
    }
  }

  /// Mark everything in [entries] read.
  ///
  /// Notifications go through Plane's `mark-all-read/`, one request rather
  /// than one per row; the activity half is a single SQLite transaction. Both
  /// halves are driven from the list the caller can see, so "all" is never
  /// wider than the screen.
  static Future<void> markAllRead(String slug, List<InboxEntry> entries) async {
    final hasNotifications =
        entries.any((e) => e.kind == InboxEntryKind.notification && !e.isRead);
    final activityIds = [
      for (final e in entries)
        if (e.kind == InboxEntryKind.activity && !e.isRead) e.id,
    ];

    await Future.wait([
      if (hasNotifications) NotificationService.markAllAsRead(),
      if (activityIds.isNotEmpty)
        AppDatabase.setInboxReadBulk(slug, activityIds, true),
    ]);
  }

  /// Dismiss everything in [entries].
  static Future<void> dismissAll(String slug, List<InboxEntry> entries) async {
    final notifications = [
      for (final e in entries)
        if (e.kind == InboxEntryKind.notification) e.id,
    ];
    final activityIds = [
      for (final e in entries)
        if (e.kind == InboxEntryKind.activity) e.id,
    ];

    await Future.wait([
      // Plane has no bulk archive for notifications, so this is one request
      // per row — but only for rows that actually are notifications, which on
      // a single-operator instance is none of them.
      for (final id in notifications) NotificationService.archive(id),
      if (activityIds.isNotEmpty)
        AppDatabase.setInboxDismissedBulk(slug, activityIds, true),
    ]);
  }
}
