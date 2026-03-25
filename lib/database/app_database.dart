import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Single SQLite database for all local-first data.
/// Tables: projects, issues, issue_states, labels, members, inbox_items, sync_meta.
class AppDatabase {
  static Database? _db;
  static const _version = 2;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'plane_local.db'),
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        identifier TEXT NOT NULL,
        description TEXT,
        cover_image_url TEXT,
        emoji TEXT,
        network INTEGER NOT NULL DEFAULT 0,
        total_members INTEGER NOT NULL DEFAULT 0,
        is_member INTEGER NOT NULL DEFAULT 0,
        workspace_slug TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS issues (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description_html TEXT,
        state TEXT,
        state_detail TEXT,
        priority TEXT NOT NULL DEFAULT 'none',
        sequence_id INTEGER NOT NULL DEFAULT 0,
        project TEXT,
        project_detail TEXT,
        assignees TEXT,
        labels TEXT,
        start_date TEXT,
        target_date TEXT,
        parent TEXT,
        sub_issues_count INTEGER NOT NULL DEFAULT 0,
        created_by TEXT,
        workspace_slug TEXT NOT NULL,
        project_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS issue_states (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT '#999',
        grp TEXT NOT NULL DEFAULT 'backlog',
        sequence INTEGER NOT NULL DEFAULT 0,
        workspace_slug TEXT NOT NULL,
        project_id TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS labels (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT '#999',
        workspace_slug TEXT NOT NULL,
        project_id TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS members (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        email TEXT NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        avatar TEXT,
        workspace_slug TEXT NOT NULL,
        project_id TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cycles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        start_date TEXT,
        end_date TEXT,
        owned_by TEXT,
        status TEXT,
        total_issues INTEGER NOT NULL DEFAULT 0,
        completed_issues INTEGER NOT NULL DEFAULT 0,
        workspace_slug TEXT NOT NULL,
        project_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS modules (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        status TEXT,
        start_date TEXT,
        target_date TEXT,
        lead TEXT,
        members TEXT,
        total_issues INTEGER NOT NULL DEFAULT 0,
        completed_issues INTEGER NOT NULL DEFAULT 0,
        workspace_slug TEXT NOT NULL,
        project_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pages (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description_html TEXT,
        owned_by TEXT,
        access INTEGER NOT NULL DEFAULT 0,
        is_locked INTEGER NOT NULL DEFAULT 0,
        archived_at TEXT,
        workspace_slug TEXT NOT NULL,
        project_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS inbox_items (
        id TEXT PRIMARY KEY,
        title TEXT,
        project_id TEXT,
        project_identifier TEXT,
        issue_id TEXT,
        sequence_id INTEGER,
        state_group TEXT,
        priority TEXT,
        activity_field TEXT,
        activity_verb TEXT,
        activity_new_value TEXT,
        actor_name TEXT,
        read_at TEXT,
        workspace_slug TEXT NOT NULL,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS write_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        workspace_slug TEXT NOT NULL,
        project_id TEXT NOT NULL,
        issue_id TEXT,
        payload TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        error TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_meta (
        entity_key TEXT PRIMARY KEY,
        last_synced_at TEXT NOT NULL
      )
    ''');

    // Indexes for common queries
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_projects_ws ON projects(workspace_slug)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_issues_ws_pid ON issues(workspace_slug, project_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_states_ws_pid ON issue_states(workspace_slug, project_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_labels_ws_pid ON labels(workspace_slug, project_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_members_ws_pid ON members(workspace_slug, project_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cycles_ws_pid ON cycles(workspace_slug, project_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_modules_ws_pid ON modules(workspace_slug, project_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_pages_ws_pid ON pages(workspace_slug, project_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inbox_ws ON inbox_items(workspace_slug)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wq_status ON write_queue(status)');
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // For now, drop and recreate on schema change.
    // In production you'd run incremental migrations.
    if (oldV < newV) {
      await db.execute('DROP TABLE IF EXISTS projects');
      await db.execute('DROP TABLE IF EXISTS issues');
      await db.execute('DROP TABLE IF EXISTS issue_states');
      await db.execute('DROP TABLE IF EXISTS labels');
      await db.execute('DROP TABLE IF EXISTS members');
      await db.execute('DROP TABLE IF EXISTS cycles');
      await db.execute('DROP TABLE IF EXISTS modules');
      await db.execute('DROP TABLE IF EXISTS pages');
      await db.execute('DROP TABLE IF EXISTS inbox_items');
      await db.execute('DROP TABLE IF EXISTS write_queue');
      await db.execute('DROP TABLE IF EXISTS sync_meta');
      await _onCreate(db, newV);
    }
  }

  /// Delete the entire database (used on logout).
  static Future<void> deleteDatabase() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    final dbPath = await getDatabasesPath();
    await databaseFactory.deleteDatabase(join(dbPath, 'plane_local.db'));
  }

  // ---------------------------------------------------------------------------
  //  Sync metadata helpers
  // ---------------------------------------------------------------------------

  static Future<DateTime?> getLastSyncedAt(String entityKey) async {
    final db = await instance;
    final rows = await db.query('sync_meta',
        where: 'entity_key = ?', whereArgs: [entityKey]);
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['last_synced_at'] as String);
  }

  static Future<void> setLastSyncedAt(String entityKey) async {
    final db = await instance;
    await db.insert(
      'sync_meta',
      {
        'entity_key': entityKey,
        'last_synced_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------------------------------------------------------------------------
  //  Generic upsert helper (replace-based)
  // ---------------------------------------------------------------------------

  static Future<void> upsertAll(
      String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final db = await instance;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Delete rows not in the given ID set, scoped by workspace/project.
  static Future<void> deleteStale(
    String table,
    Set<String> freshIds, {
    required String workspaceSlug,
    String? projectId,
  }) async {
    if (freshIds.isEmpty) return;
    final db = await instance;
    // Build where clause
    final where = StringBuffer('workspace_slug = ?');
    final args = <dynamic>[workspaceSlug];
    if (projectId != null) {
      where.write(' AND project_id = ?');
      args.add(projectId);
    }
    // Get existing IDs
    final existing = await db.query(table,
        columns: ['id'], where: where.toString(), whereArgs: args);
    final existingIds = existing.map((r) => r['id'] as String).toSet();
    final toDelete = existingIds.difference(freshIds);
    if (toDelete.isEmpty) return;
    // Delete in batches of 100
    final batch = db.batch();
    for (final id in toDelete) {
      batch.delete(table, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------------
  //  Projects DAO
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getProjects(String ws) async {
    final db = await instance;
    return db.query('projects',
        where: 'workspace_slug = ?',
        whereArgs: [ws],
        orderBy: 'name ASC');
  }

  static Future<void> saveProjects(
      String ws, List<Map<String, dynamic>> rows) async {
    final enriched = rows.map((r) => {...r, 'workspace_slug': ws}).toList();
    await upsertAll('projects', enriched);
    final freshIds = rows.map((r) => r['id'] as String).toSet();
    await deleteStale('projects', freshIds, workspaceSlug: ws);
    await setLastSyncedAt('projects:$ws');
  }

  // ---------------------------------------------------------------------------
  //  Issues DAO
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getIssues(
      String ws, String pid) async {
    final db = await instance;
    return db.query('issues',
        where: 'workspace_slug = ? AND project_id = ?',
        whereArgs: [ws, pid]);
  }

  static Future<void> saveIssues(
      String ws, String pid, List<Map<String, dynamic>> rows) async {
    final enriched = rows.map((r) {
      final copy = Map<String, dynamic>.from(r);
      copy['workspace_slug'] = ws;
      copy['project_id'] = pid;
      // Serialize list fields to JSON strings
      if (copy['assignees'] is List) {
        copy['assignees'] = jsonEncode(copy['assignees']);
      }
      if (copy['labels'] is List) {
        copy['labels'] = jsonEncode(copy['labels']);
      }
      return copy;
    }).toList();
    await upsertAll('issues', enriched);
    final freshIds = rows.map((r) => r['id'] as String).toSet();
    await deleteStale('issues', freshIds,
        workspaceSlug: ws, projectId: pid);
    await setLastSyncedAt('issues:${ws}_$pid');
  }

  // ---------------------------------------------------------------------------
  //  States DAO
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getStates(
      String ws, String pid) async {
    final db = await instance;
    return db.query('issue_states',
        where: 'workspace_slug = ? AND project_id = ?',
        whereArgs: [ws, pid],
        orderBy: 'sequence ASC');
  }

  static Future<void> saveStates(
      String ws, String pid, List<Map<String, dynamic>> rows) async {
    final enriched = rows.map((r) {
      final copy = Map<String, dynamic>.from(r);
      copy['workspace_slug'] = ws;
      copy['project_id'] = pid;
      // 'group' is a reserved word in SQL, stored as 'grp'
      if (copy.containsKey('group')) {
        copy['grp'] = copy.remove('group');
      }
      return copy;
    }).toList();
    await upsertAll('issue_states', enriched);
    final freshIds = rows.map((r) => r['id'] as String).toSet();
    await deleteStale('issue_states', freshIds,
        workspaceSlug: ws, projectId: pid);
    await setLastSyncedAt('states:${ws}_$pid');
  }

  // ---------------------------------------------------------------------------
  //  Labels DAO
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getLabels(
      String ws, String pid) async {
    final db = await instance;
    return db.query('labels',
        where: 'workspace_slug = ? AND project_id = ?',
        whereArgs: [ws, pid]);
  }

  static Future<void> saveLabels(
      String ws, String pid, List<Map<String, dynamic>> rows) async {
    final enriched =
        rows.map((r) => {...r, 'workspace_slug': ws, 'project_id': pid}).toList();
    await upsertAll('labels', enriched);
    final freshIds = rows.map((r) => r['id'] as String).toSet();
    await deleteStale('labels', freshIds,
        workspaceSlug: ws, projectId: pid);
    await setLastSyncedAt('labels:${ws}_$pid');
  }

  // ---------------------------------------------------------------------------
  //  Members DAO
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getMembers(
      String ws, String pid) async {
    final db = await instance;
    return db.query('members',
        where: 'workspace_slug = ? AND project_id = ?',
        whereArgs: [ws, pid]);
  }

  static Future<void> saveMembers(
      String ws, String pid, List<Map<String, dynamic>> rows) async {
    final enriched =
        rows.map((r) => {...r, 'workspace_slug': ws, 'project_id': pid}).toList();
    await upsertAll('members', enriched);
    final freshIds = rows.map((r) => r['id'] as String).toSet();
    await deleteStale('members', freshIds,
        workspaceSlug: ws, projectId: pid);
    await setLastSyncedAt('members:${ws}_$pid');
  }

  // ---------------------------------------------------------------------------
  //  Cycles DAO
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getCycles(
      String ws, String pid) async {
    final db = await instance;
    return db.query('cycles',
        where: 'workspace_slug = ? AND project_id = ?',
        whereArgs: [ws, pid]);
  }

  static Future<void> saveCycles(
      String ws, String pid, List<Map<String, dynamic>> rows) async {
    final enriched =
        rows.map((r) => {...r, 'workspace_slug': ws, 'project_id': pid}).toList();
    await upsertAll('cycles', enriched);
    final freshIds = rows.map((r) => r['id'] as String).toSet();
    await deleteStale('cycles', freshIds,
        workspaceSlug: ws, projectId: pid);
    await setLastSyncedAt('cycles:${ws}_$pid');
  }

  // ---------------------------------------------------------------------------
  //  Modules DAO
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getModules(
      String ws, String pid) async {
    final db = await instance;
    return db.query('modules',
        where: 'workspace_slug = ? AND project_id = ?',
        whereArgs: [ws, pid]);
  }

  static Future<void> saveModules(
      String ws, String pid, List<Map<String, dynamic>> rows) async {
    final enriched = rows.map((r) {
      final copy = Map<String, dynamic>.from(r);
      copy['workspace_slug'] = ws;
      copy['project_id'] = pid;
      if (copy['members'] is List) {
        copy['members'] = jsonEncode(copy['members']);
      }
      return copy;
    }).toList();
    await upsertAll('modules', enriched);
    final freshIds = rows.map((r) => r['id'] as String).toSet();
    await deleteStale('modules', freshIds,
        workspaceSlug: ws, projectId: pid);
    await setLastSyncedAt('modules:${ws}_$pid');
  }

  // ---------------------------------------------------------------------------
  //  Pages DAO
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getPages(
      String ws, String pid) async {
    final db = await instance;
    return db.query('pages',
        where: 'workspace_slug = ? AND project_id = ?',
        whereArgs: [ws, pid]);
  }

  static Future<void> savePages(
      String ws, String pid, List<Map<String, dynamic>> rows) async {
    final enriched =
        rows.map((r) => {...r, 'workspace_slug': ws, 'project_id': pid}).toList();
    await upsertAll('pages', enriched);
    final freshIds = rows.map((r) => r['id'] as String).toSet();
    await deleteStale('pages', freshIds,
        workspaceSlug: ws, projectId: pid);
    await setLastSyncedAt('pages:${ws}_$pid');
  }

  // ---------------------------------------------------------------------------
  //  Inbox DAO
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getInboxItems(String ws) async {
    final db = await instance;
    return db.query('inbox_items',
        where: 'workspace_slug = ?',
        whereArgs: [ws],
        orderBy: 'created_at DESC');
  }

  static Future<void> saveInboxItems(
      String ws, List<Map<String, dynamic>> rows) async {
    final enriched =
        rows.map((r) => {...r, 'workspace_slug': ws}).toList();
    await upsertAll('inbox_items', enriched);
    await setLastSyncedAt('inbox:$ws');
  }

  // ---------------------------------------------------------------------------
  //  Clear all data (logout)
  // ---------------------------------------------------------------------------

  static Future<void> clearAll() async {
    final db = await instance;
    await db.delete('projects');
    await db.delete('issues');
    await db.delete('issue_states');
    await db.delete('labels');
    await db.delete('members');
    await db.delete('cycles');
    await db.delete('modules');
    await db.delete('pages');
    await db.delete('inbox_items');
    await db.delete('write_queue');
    await db.delete('sync_meta');
  }
}
