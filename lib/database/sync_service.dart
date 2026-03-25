import 'dart:convert';
import '../database/app_database.dart';
import '../models/project.dart';
import '../models/issue.dart';
import '../models/state.dart';
import '../models/label.dart';
import '../models/member.dart';
import '../models/cycle.dart';
import '../models/module.dart';
import '../models/page.dart';

/// Reads model objects from SQLite.
/// Converts between SQLite row maps and domain model objects.
class SyncService {
  // ---------------------------------------------------------------------------
  //  Projects
  // ---------------------------------------------------------------------------

  static Future<List<Project>?> readProjects(String ws) async {
    final rows = await AppDatabase.getProjects(ws);
    if (rows.isEmpty) return null;
    return rows.map((r) => Project.fromJson({
      'id': r['id'],
      'name': r['name'],
      'identifier': r['identifier'],
      'description': r['description'],
      'cover_image_url': r['cover_image_url'],
      'emoji': r['emoji'],
      'network': r['network'],
      'total_members': r['total_members'],
      'is_member': (r['is_member'] as int) == 1,
      'created_at': r['created_at'],
    })).toList();
  }

  static Future<void> writeProjects(String ws, List<Project> projects) async {
    final rows = projects.map((p) => <String, dynamic>{
      'id': p.id,
      'name': p.name,
      'identifier': p.identifier,
      'description': p.description,
      'cover_image_url': p.coverImageUrl,
      'emoji': p.emoji,
      'network': p.network,
      'total_members': p.totalMembers,
      'is_member': p.isMember ? 1 : 0,
      'created_at': p.createdAt.toIso8601String(),
    }).toList();
    await AppDatabase.saveProjects(ws, rows);
  }

  // ---------------------------------------------------------------------------
  //  Issues
  // ---------------------------------------------------------------------------

  static Future<List<Issue>?> readIssues(String ws, String pid) async {
    final rows = await AppDatabase.getIssues(ws, pid);
    if (rows.isEmpty) return null;
    return rows.map((r) {
      // Deserialize JSON-encoded list fields
      List<String> parseList(dynamic val) {
        if (val == null) return [];
        if (val is String) {
          try {
            final decoded = jsonDecode(val);
            if (decoded is List) return decoded.map((e) => e.toString()).toList();
          } catch (_) {}
          return [];
        }
        if (val is List) return val.map((e) => e.toString()).toList();
        return [];
      }

      return Issue.fromJson({
        'id': r['id'],
        'name': r['name'],
        'description_html': r['description_html'],
        'state': r['state'],
        'state_detail': r['state_detail'],
        'priority': r['priority'],
        'sequence_id': r['sequence_id'],
        'project': r['project'],
        'project_detail': r['project_detail'],
        'assignees': parseList(r['assignees']),
        'labels': parseList(r['labels']),
        'start_date': r['start_date'],
        'target_date': r['target_date'],
        'parent': r['parent'],
        'sub_issues_count': r['sub_issues_count'],
        'created_by': r['created_by'],
        'created_at': r['created_at'],
        'updated_at': r['updated_at'],
      });
    }).toList();
  }

  static Future<void> writeIssues(
      String ws, String pid, List<Issue> issues) async {
    final rows = issues.map((i) => <String, dynamic>{
      'id': i.id,
      'name': i.name,
      'description_html': i.descriptionHtml,
      'state': i.state,
      'state_detail': i.stateDetail,
      'priority': i.priority,
      'sequence_id': i.sequenceId,
      'project': i.project,
      'project_detail': i.projectDetail,
      'assignees': jsonEncode(i.assignees),
      'labels': jsonEncode(i.labels),
      'start_date': i.startDate,
      'target_date': i.targetDate,
      'parent': i.parent,
      'sub_issues_count': i.subIssuesCount,
      'created_by': i.createdBy,
      'created_at': i.createdAt.toIso8601String(),
      'updated_at': i.updatedAt.toIso8601String(),
    }).toList();
    await AppDatabase.saveIssues(ws, pid, rows);
  }

  // ---------------------------------------------------------------------------
  //  States
  // ---------------------------------------------------------------------------

  static Future<List<IssueState>?> readStates(String ws, String pid) async {
    final rows = await AppDatabase.getStates(ws, pid);
    if (rows.isEmpty) return null;
    return rows.map((r) => IssueState.fromJson({
      'id': r['id'],
      'name': r['name'],
      'color': r['color'],
      'group': r['grp'], // stored as 'grp' in DB
      'sequence': r['sequence'],
    })).toList();
  }

  static Future<void> writeStates(
      String ws, String pid, List<IssueState> states) async {
    final rows = states.map((s) => <String, dynamic>{
      'id': s.id,
      'name': s.name,
      'color': s.color,
      'group': s.group, // AppDatabase.saveStates renames to 'grp'
      'sequence': s.sequence,
    }).toList();
    await AppDatabase.saveStates(ws, pid, rows);
  }

  // ---------------------------------------------------------------------------
  //  Labels
  // ---------------------------------------------------------------------------

  static Future<List<Label>?> readLabels(String ws, String pid) async {
    final rows = await AppDatabase.getLabels(ws, pid);
    if (rows.isEmpty) return null;
    return rows.map((r) => Label.fromJson({
      'id': r['id'],
      'name': r['name'],
      'color': r['color'],
    })).toList();
  }

  static Future<void> writeLabels(
      String ws, String pid, List<Label> labels) async {
    final rows = labels.map((l) => <String, dynamic>{
      'id': l.id,
      'name': l.name,
      'color': l.color,
    }).toList();
    await AppDatabase.saveLabels(ws, pid, rows);
  }

  // ---------------------------------------------------------------------------
  //  Members
  // ---------------------------------------------------------------------------

  static Future<List<Member>?> readMembers(String ws, String pid) async {
    final rows = await AppDatabase.getMembers(ws, pid);
    if (rows.isEmpty) return null;
    return rows.map((r) => Member.fromJson({
      'id': r['id'],
      'display_name': r['display_name'],
      'email': r['email'],
      'first_name': r['first_name'],
      'last_name': r['last_name'],
      'avatar': r['avatar'],
    })).toList();
  }

  static Future<void> writeMembers(
      String ws, String pid, List<Member> members) async {
    final rows = members.map((m) => <String, dynamic>{
      'id': m.id,
      'display_name': m.displayName,
      'email': m.email,
      'first_name': m.firstName,
      'last_name': m.lastName,
      'avatar': m.avatar,
    }).toList();
    await AppDatabase.saveMembers(ws, pid, rows);
  }

  // ---------------------------------------------------------------------------
  //  Cycles
  // ---------------------------------------------------------------------------

  static Future<List<Cycle>?> readCycles(String ws, String pid) async {
    final rows = await AppDatabase.getCycles(ws, pid);
    if (rows.isEmpty) return null;
    return rows.map((r) => Cycle.fromJson({
      'id': r['id'],
      'name': r['name'],
      'description': r['description'],
      'start_date': r['start_date'],
      'end_date': r['end_date'],
      'owned_by': r['owned_by'],
      'status': r['status'],
      'total_issues': r['total_issues'],
      'completed_issues': r['completed_issues'],
      'created_at': r['created_at'],
    })).toList();
  }

  static Future<void> writeCycles(
      String ws, String pid, List<Cycle> cycles) async {
    final rows = cycles.map((c) => <String, dynamic>{
      'id': c.id,
      'name': c.name,
      'description': c.description,
      'start_date': c.startDate,
      'end_date': c.endDate,
      'owned_by': c.ownedBy,
      'status': c.status,
      'total_issues': c.totalIssues,
      'completed_issues': c.completedIssues,
      'created_at': c.createdAt.toIso8601String(),
    }).toList();
    await AppDatabase.saveCycles(ws, pid, rows);
  }

  // ---------------------------------------------------------------------------
  //  Modules
  // ---------------------------------------------------------------------------

  static Future<List<Module>?> readModules(String ws, String pid) async {
    final rows = await AppDatabase.getModules(ws, pid);
    if (rows.isEmpty) return null;
    return rows.map((r) {
      List<String> parseMembers(dynamic val) {
        if (val == null) return [];
        if (val is String) {
          try {
            final decoded = jsonDecode(val);
            if (decoded is List) return decoded.map((e) => e.toString()).toList();
          } catch (_) {}
          return [];
        }
        if (val is List) return val.map((e) => e.toString()).toList();
        return [];
      }
      return Module.fromJson({
        'id': r['id'],
        'name': r['name'],
        'description': r['description'],
        'status': r['status'],
        'start_date': r['start_date'],
        'target_date': r['target_date'],
        'lead': r['lead'],
        'members': parseMembers(r['members']),
        'total_issues': r['total_issues'],
        'completed_issues': r['completed_issues'],
        'created_at': r['created_at'],
      });
    }).toList();
  }

  static Future<void> writeModules(
      String ws, String pid, List<Module> modules) async {
    final rows = modules.map((m) => <String, dynamic>{
      'id': m.id,
      'name': m.name,
      'description': m.description,
      'status': m.status,
      'start_date': m.startDate,
      'target_date': m.targetDate,
      'lead': m.lead,
      'members': jsonEncode(m.members),
      'total_issues': m.totalIssues,
      'completed_issues': m.completedIssues,
      'created_at': m.createdAt.toIso8601String(),
    }).toList();
    await AppDatabase.saveModules(ws, pid, rows);
  }

  // ---------------------------------------------------------------------------
  //  Pages
  // ---------------------------------------------------------------------------

  static Future<List<PlanePage>?> readPages(String ws, String pid) async {
    final rows = await AppDatabase.getPages(ws, pid);
    if (rows.isEmpty) return null;
    return rows.map((r) => PlanePage.fromJson({
      'id': r['id'],
      'name': r['name'],
      'description_html': r['description_html'],
      'owned_by': r['owned_by'],
      'access': r['access'],
      'is_locked': (r['is_locked'] as int) == 1,
      'archived_at': r['archived_at'],
      'created_at': r['created_at'],
      'updated_at': r['updated_at'],
    })).toList();
  }

  static Future<void> writePages(
      String ws, String pid, List<PlanePage> pages) async {
    final rows = pages.map((p) => <String, dynamic>{
      'id': p.id,
      'name': p.name,
      'description_html': p.descriptionHtml,
      'owned_by': p.ownedBy,
      'access': p.access,
      'is_locked': p.isLocked ? 1 : 0,
      'archived_at': p.archivedAt?.toIso8601String(),
      'created_at': p.createdAt.toIso8601String(),
      'updated_at': p.updatedAt.toIso8601String(),
    }).toList();
    await AppDatabase.savePages(ws, pid, rows);
  }

  // ---------------------------------------------------------------------------
  //  Inbox
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>?> readInboxItems(String ws) async {
    final rows = await AppDatabase.getInboxItems(ws);
    if (rows.isEmpty) return null;
    // Return raw maps — InboxTab consumes raw maps directly.
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  static Future<void> writeInboxItems(
      String ws, List<Map<String, dynamic>> items) async {
    final rows = items.map((n) => <String, dynamic>{
      'id': n['id'] ?? '',
      'title': n['title'],
      'project_id': n['project'],
      'project_identifier': n['project_identifier'],
      'issue_id': n['issue_id'],
      'sequence_id': n['sequence_id'],
      'state_group': n['state_group'],
      'priority': n['priority'],
      'activity_field': n['activity_field'],
      'activity_verb': n['activity_verb'],
      'activity_new_value': n['activity_new_value'],
      'actor_name': n['actor_name'],
      'read_at': n['read_at'],
      'created_at': n['created_at'],
    }).toList();
    await AppDatabase.saveInboxItems(ws, rows);
  }
}
