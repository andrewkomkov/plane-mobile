import 'dart:convert';
import 'app_database.dart';
import '../services/issue_service.dart';
import '../services/comment_service.dart';

/// Represents a single queued write operation.
class QueueItem {
  final int id;
  final String action;
  final String workspaceSlug;
  final String projectId;
  final String? issueId;
  final Map<String, dynamic> payload;
  final String status;
  final DateTime createdAt;
  final String? error;

  QueueItem({
    required this.id,
    required this.action,
    required this.workspaceSlug,
    required this.projectId,
    this.issueId,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.error,
  });

  factory QueueItem.fromRow(Map<String, dynamic> row) {
    return QueueItem(
      id: row['id'] as int,
      action: row['action'] as String,
      workspaceSlug: row['workspace_slug'] as String,
      projectId: row['project_id'] as String,
      issueId: row['issue_id'] as String?,
      payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      status: row['status'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      error: row['error'] as String?,
    );
  }
}

/// Offline write queue backed by SQLite.
///
/// Queues create/update/delete operations when the device is offline
/// and replays them when connectivity is restored.
class WriteQueue {
  static bool _syncing = false;

  /// Add an operation to the queue.
  static Future<void> enqueue(
    String action,
    String workspaceSlug,
    String projectId,
    String? issueId,
    Map<String, dynamic> payload,
  ) async {
    final db = await AppDatabase.instance;
    await db.insert('write_queue', {
      'action': action,
      'workspace_slug': workspaceSlug,
      'project_id': projectId,
      'issue_id': issueId,
      'payload': jsonEncode(payload),
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get all pending items ordered by creation time.
  static Future<List<QueueItem>> getPending() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'write_queue',
      where: "status = 'pending'",
      orderBy: 'created_at ASC',
    );
    return rows.map(QueueItem.fromRow).toList();
  }

  /// Mark an item as currently syncing.
  static Future<void> markSyncing(int id) async {
    final db = await AppDatabase.instance;
    await db.update(
      'write_queue',
      {'status': 'syncing'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Remove a successfully synced item.
  static Future<void> markDone(int id) async {
    final db = await AppDatabase.instance;
    await db.delete('write_queue', where: 'id = ?', whereArgs: [id]);
  }

  /// Mark an item as failed with an error message.
  static Future<void> markFailed(int id, String error) async {
    final db = await AppDatabase.instance;
    await db.update(
      'write_queue',
      {'status': 'failed', 'error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Count of pending + failed items (everything not yet synced).
  static Future<int> pendingCount() async {
    final db = await AppDatabase.instance;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM write_queue WHERE status IN ('pending', 'failed')",
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Process all pending and failed items in order.
  ///
  /// Returns the number of successfully synced items.
  /// Skips if a sync is already running.
  static Future<int> syncAll() async {
    if (_syncing) return 0;
    _syncing = true;
    int synced = 0;
    try {
      // Also retry previously failed items.
      final db = await AppDatabase.instance;
      await db.update(
        'write_queue',
        {'status': 'pending'},
        where: "status = 'failed'",
      );

      final items = await getPending();
      for (final item in items) {
        await markSyncing(item.id);
        try {
          await _execute(item);
          await markDone(item.id);
          synced++;
        } catch (e) {
          await markFailed(item.id, e.toString());
          // Continue to next item instead of aborting.
        }
      }
    } finally {
      _syncing = false;
    }
    return synced;
  }

  /// Execute a single queued operation via the appropriate service.
  static Future<void> _execute(QueueItem item) async {
    switch (item.action) {
      case 'create_issue':
        await IssueService.createIssue(
          item.workspaceSlug,
          item.projectId,
          item.payload,
        );
        break;
      case 'update_issue':
        if (item.issueId == null) {
          throw Exception('update_issue requires an issue_id');
        }
        await IssueService.updateIssue(
          item.workspaceSlug,
          item.projectId,
          item.issueId!,
          item.payload,
        );
        break;
      case 'delete_issue':
        if (item.issueId == null) {
          throw Exception('delete_issue requires an issue_id');
        }
        await IssueService.deleteIssue(
          item.workspaceSlug,
          item.projectId,
          item.issueId!,
        );
        break;
      case 'add_comment':
        if (item.issueId == null) {
          throw Exception('add_comment requires an issue_id');
        }
        await CommentService.addComment(
          item.workspaceSlug,
          item.projectId,
          item.issueId!,
          item.payload['comment_html'] as String? ?? '',
        );
        break;
      default:
        throw Exception('Unknown write queue action: ${item.action}');
    }
  }
}
