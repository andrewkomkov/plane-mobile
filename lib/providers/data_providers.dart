import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../models/issue.dart';
import '../models/state.dart';
import '../models/label.dart';
import '../models/member.dart';
import '../models/cycle.dart';
import '../models/module.dart';
import '../models/page.dart';
import '../services/project_service.dart';
import '../services/issue_service.dart';
import '../services/label_service.dart';
import '../services/member_service.dart';
import '../services/cycle_service.dart';
import '../services/module_service.dart';
import '../services/page_service.dart';
import '../database/sync_service.dart';
import '../database/app_database.dart';

// ---------------------------------------------------------------------------
//  In-memory data cache (single source of truth for all data).
//  Every screen reads from here; background refresh updates it.
//
//  Local-first flow:
//    1. Read from SQLite (instant, <10ms) → populate in-memory maps
//    2. Return cached data, show UI immediately
//    3. Fetch from API in background
//    4. Write API results to SQLite
//    5. Update in-memory maps, notify UI if data changed
// ---------------------------------------------------------------------------

class DataCache {
  // Projects per workspace
  final Map<String, List<Project>> _projects = {};
  final Map<String, bool> _projectsLoading = {};

  // States per "ws/pid"
  final Map<String, Map<String, IssueState>> _states = {};
  final Map<String, bool> _statesLoading = {};

  // Issues per "ws/pid"
  final Map<String, List<Issue>> _issues = {};
  final Map<String, bool> _issuesLoading = {};

  // Labels per "ws/pid"
  final Map<String, List<Label>> _labels = {};
  final Map<String, bool> _labelsLoading = {};

  // Members per "ws/pid"
  final Map<String, List<Member>> _members = {};
  final Map<String, bool> _membersLoading = {};

  // Cycles per "ws/pid"
  final Map<String, List<Cycle>> _cycles = {};
  final Map<String, bool> _cyclesLoading = {};

  // Modules per "ws/pid"
  final Map<String, List<Module>> _modules = {};
  final Map<String, bool> _modulesLoading = {};

  // Pages per "ws/pid"
  final Map<String, List<PlanePage>> _pages = {};
  final Map<String, bool> _pagesLoading = {};

  // Track in-flight requests to avoid duplicates
  final Map<String, Future<void>> _inflight = {};

  // -------------------------------------------------------------------------
  //  Projects
  // -------------------------------------------------------------------------

  List<Project>? getProjects(String ws) => _projects[ws];
  bool isProjectsLoading(String ws) => _projectsLoading[ws] ?? false;

  Future<void> loadProjects(String ws, {bool force = false}) async {
    if (ws.isEmpty) return;
    final key = 'projects:$ws';
    if (!force && _projects.containsKey(ws)) {
      // Already loaded. Trigger background refresh.
      _refreshProjects(ws);
      return;
    }
    if (_inflight.containsKey(key)) return _inflight[key]!;

    // Try SQLite first (instant)
    if (!_projects.containsKey(ws)) {
      try {
        final cached = await SyncService.readProjects(ws);
        if (cached != null && cached.isNotEmpty) {
          _projects[ws] = cached;
          // data updated — UI can render immediately
        }
      } catch (_) {}
    }

    _projectsLoading[ws] = true;

    _inflight[key] = _fetchProjects(ws);
    await _inflight[key];
    _inflight.remove(key);
  }

  Future<void> _fetchProjects(String ws) async {
    try {
      final projects = await ProjectService.getProjects(ws);
      _projects[ws] = projects;
      _projectsLoading[ws] = false;
      // data updated
      // Write to SQLite in background
      unawaited(SyncService.writeProjects(ws, projects));
    } catch (_) {
      _projectsLoading[ws] = false;
      // data updated
    }
  }

  Future<void> _refreshProjects(String ws) async {
    final key = 'projects_bg:$ws';
    if (_inflight.containsKey(key)) return;
    _inflight[key] = _fetchProjects(ws);
    await _inflight[key];
    _inflight.remove(key);
  }

  // -------------------------------------------------------------------------
  //  States
  // -------------------------------------------------------------------------

  Map<String, IssueState>? getStates(String ws, String pid) => _states['$ws/$pid'];
  bool isStatesLoading(String ws, String pid) => _statesLoading['$ws/$pid'] ?? false;

  Future<void> loadStates(String ws, String pid, {bool force = false}) async {
    final k = '$ws/$pid';
    if (ws.isEmpty || pid.isEmpty) return;
    if (!force && _states.containsKey(k)) {
      _refreshStates(ws, pid);
      return;
    }
    final key = 'states:$k';
    if (_inflight.containsKey(key)) return _inflight[key]!;

    // Try SQLite first
    if (!_states.containsKey(k)) {
      try {
        final cached = await SyncService.readStates(ws, pid);
        if (cached != null && cached.isNotEmpty) {
          _states[k] = {for (var s in cached) s.id: s};
          // data updated
        }
      } catch (_) {}
    }

    _statesLoading[k] = true;

    _inflight[key] = _fetchStates(ws, pid);
    await _inflight[key];
    _inflight.remove(key);
  }

  Future<void> _fetchStates(String ws, String pid) async {
    final k = '$ws/$pid';
    try {
      final states = await IssueService.getStates(ws, pid);
      _states[k] = {for (var s in states) s.id: s};
      _statesLoading[k] = false;
      // data updated
      unawaited(SyncService.writeStates(ws, pid, states));
    } catch (_) {
      _statesLoading[k] = false;
      // data updated
    }
  }

  Future<void> _refreshStates(String ws, String pid) async {
    final key = 'states_bg:$ws/$pid';
    if (_inflight.containsKey(key)) return;
    _inflight[key] = _fetchStates(ws, pid);
    await _inflight[key];
    _inflight.remove(key);
  }

  // -------------------------------------------------------------------------
  //  Issues
  // -------------------------------------------------------------------------

  List<Issue>? getIssues(String ws, String pid) => _issues['$ws/$pid'];
  bool isIssuesLoading(String ws, String pid) => _issuesLoading['$ws/$pid'] ?? false;

  Future<void> loadIssues(String ws, String pid, {bool force = false}) async {
    final k = '$ws/$pid';
    if (ws.isEmpty || pid.isEmpty) return;
    if (!force && _issues.containsKey(k)) {
      _refreshIssues(ws, pid);
      return;
    }
    final key = 'issues:$k';
    if (_inflight.containsKey(key)) return _inflight[key]!;

    // Try SQLite first
    if (!_issues.containsKey(k)) {
      try {
        final cached = await SyncService.readIssues(ws, pid);
        if (cached != null && cached.isNotEmpty) {
          _issues[k] = cached;
          // data updated
        }
      } catch (_) {}
    }

    _issuesLoading[k] = true;

    _inflight[key] = _fetchIssues(ws, pid);
    await _inflight[key];
    _inflight.remove(key);
  }

  Future<void> _fetchIssues(String ws, String pid) async {
    final k = '$ws/$pid';
    try {
      final result = await IssueService.getIssues(ws, pid);
      final issues = result['issues'] as List<Issue>;
      _issues[k] = issues;
      _issuesLoading[k] = false;
      // data updated
      unawaited(SyncService.writeIssues(ws, pid, issues));
    } catch (_) {
      _issuesLoading[k] = false;
      // data updated
    }
  }

  Future<void> _refreshIssues(String ws, String pid) async {
    final key = 'issues_bg:$ws/$pid';
    if (_inflight.containsKey(key)) return;
    _inflight[key] = _fetchIssues(ws, pid);
    await _inflight[key];
    _inflight.remove(key);
  }

  void invalidateIssues(String ws, String pid) {
    _issues.remove('$ws/$pid');
  }

  // -------------------------------------------------------------------------
  //  Labels (lazy — only loaded when requested)
  // -------------------------------------------------------------------------

  List<Label>? getLabels(String ws, String pid) => _labels['$ws/$pid'];
  bool isLabelsLoading(String ws, String pid) => _labelsLoading['$ws/$pid'] ?? false;

  Future<void> loadLabels(String ws, String pid) async {
    final k = '$ws/$pid';
    if (ws.isEmpty || pid.isEmpty) return;
    if (_labels.containsKey(k) || _labelsLoading[k] == true) return;
    final key = 'labels:$k';
    if (_inflight.containsKey(key)) return _inflight[key]!;

    // Try SQLite first
    if (!_labels.containsKey(k)) {
      try {
        final cached = await SyncService.readLabels(ws, pid);
        if (cached != null && cached.isNotEmpty) {
          _labels[k] = cached;
          // data updated
        }
      } catch (_) {}
    }

    _labelsLoading[k] = true;
    _inflight[key] = _fetchLabels(ws, pid);
    await _inflight[key];
    _inflight.remove(key);
  }

  Future<void> _fetchLabels(String ws, String pid) async {
    final k = '$ws/$pid';
    try {
      final labels = await LabelService.getLabels(ws, pid);
      _labels[k] = labels;
      _labelsLoading[k] = false;
      // data updated
      unawaited(SyncService.writeLabels(ws, pid, labels));
    } catch (_) {
      _labelsLoading[k] = false;
    }
  }

  // -------------------------------------------------------------------------
  //  Members (lazy)
  // -------------------------------------------------------------------------

  List<Member>? getMembers(String ws, String pid) => _members['$ws/$pid'];
  bool isMembersLoading(String ws, String pid) => _membersLoading['$ws/$pid'] ?? false;

  Future<void> loadMembers(String ws, String pid) async {
    final k = '$ws/$pid';
    if (ws.isEmpty || pid.isEmpty) return;
    if (_members.containsKey(k) || _membersLoading[k] == true) return;
    final key = 'members:$k';
    if (_inflight.containsKey(key)) return _inflight[key]!;

    // Try SQLite first
    if (!_members.containsKey(k)) {
      try {
        final cached = await SyncService.readMembers(ws, pid);
        if (cached != null && cached.isNotEmpty) {
          _members[k] = cached;
          // data updated
        }
      } catch (_) {}
    }

    _membersLoading[k] = true;
    _inflight[key] = _fetchMembers(ws, pid);
    await _inflight[key];
    _inflight.remove(key);
  }

  Future<void> _fetchMembers(String ws, String pid) async {
    final k = '$ws/$pid';
    try {
      final members = await MemberService.getMembers(ws, pid);
      _members[k] = members;
      _membersLoading[k] = false;
      // data updated
      unawaited(SyncService.writeMembers(ws, pid, members));
    } catch (_) {
      _membersLoading[k] = false;
    }
  }

  // -------------------------------------------------------------------------
  //  Cycles
  // -------------------------------------------------------------------------

  List<Cycle>? getCycles(String ws, String pid) => _cycles['$ws/$pid'];
  bool isCyclesLoading(String ws, String pid) => _cyclesLoading['$ws/$pid'] ?? false;

  Future<void> loadCycles(String ws, String pid, {bool force = false}) async {
    final k = '$ws/$pid';
    if (ws.isEmpty || pid.isEmpty) return;
    if (!force && _cycles.containsKey(k)) return;
    final key = 'cycles:$k';
    if (_inflight.containsKey(key)) return _inflight[key]!;

    // Try SQLite first
    if (!_cycles.containsKey(k)) {
      try {
        final cached = await SyncService.readCycles(ws, pid);
        if (cached != null && cached.isNotEmpty) {
          _cycles[k] = cached;
          // data updated
        }
      } catch (_) {}
    }

    _cyclesLoading[k] = true;

    _inflight[key] = _fetchCycles(ws, pid);
    await _inflight[key];
    _inflight.remove(key);
  }

  Future<void> _fetchCycles(String ws, String pid) async {
    final k = '$ws/$pid';
    try {
      final cycles = await CycleService.getCycles(ws, pid);
      _cycles[k] = cycles;
      _cyclesLoading[k] = false;
      // data updated
      unawaited(SyncService.writeCycles(ws, pid, cycles));
    } catch (_) {
      _cyclesLoading[k] = false;
      // data updated
    }
  }

  void invalidateCycles(String ws, String pid) {
    _cycles.remove('$ws/$pid');
  }

  // -------------------------------------------------------------------------
  //  Modules
  // -------------------------------------------------------------------------

  List<Module>? getModules(String ws, String pid) => _modules['$ws/$pid'];
  bool isModulesLoading(String ws, String pid) => _modulesLoading['$ws/$pid'] ?? false;

  Future<void> loadModules(String ws, String pid, {bool force = false}) async {
    final k = '$ws/$pid';
    if (ws.isEmpty || pid.isEmpty) return;
    if (!force && _modules.containsKey(k)) return;
    final key = 'modules:$k';
    if (_inflight.containsKey(key)) return _inflight[key]!;

    // Try SQLite first
    if (!_modules.containsKey(k)) {
      try {
        final cached = await SyncService.readModules(ws, pid);
        if (cached != null && cached.isNotEmpty) {
          _modules[k] = cached;
          // data updated
        }
      } catch (_) {}
    }

    _modulesLoading[k] = true;

    _inflight[key] = _fetchModules(ws, pid);
    await _inflight[key];
    _inflight.remove(key);
  }

  Future<void> _fetchModules(String ws, String pid) async {
    final k = '$ws/$pid';
    try {
      final modules = await ModuleService.getModules(ws, pid);
      _modules[k] = modules;
      _modulesLoading[k] = false;
      // data updated
      unawaited(SyncService.writeModules(ws, pid, modules));
    } catch (_) {
      _modulesLoading[k] = false;
      // data updated
    }
  }

  void invalidateModules(String ws, String pid) {
    _modules.remove('$ws/$pid');
  }

  // -------------------------------------------------------------------------
  //  Pages
  // -------------------------------------------------------------------------

  List<PlanePage>? getPages(String ws, String pid) => _pages['$ws/$pid'];
  bool isPagesLoading(String ws, String pid) => _pagesLoading['$ws/$pid'] ?? false;

  Future<void> loadPages(String ws, String pid, {bool force = false}) async {
    final k = '$ws/$pid';
    if (ws.isEmpty || pid.isEmpty) return;
    if (!force && _pages.containsKey(k)) return;
    final key = 'pages:$k';
    if (_inflight.containsKey(key)) return _inflight[key]!;

    // Try SQLite first
    if (!_pages.containsKey(k)) {
      try {
        final cached = await SyncService.readPages(ws, pid);
        if (cached != null && cached.isNotEmpty) {
          _pages[k] = cached;
          // data updated
        }
      } catch (_) {}
    }

    _pagesLoading[k] = true;

    _inflight[key] = _fetchPages(ws, pid);
    await _inflight[key];
    _inflight.remove(key);
  }

  Future<void> _fetchPages(String ws, String pid) async {
    final k = '$ws/$pid';
    try {
      final pages = await PageService.getPages(ws, pid);
      _pages[k] = pages;
      _pagesLoading[k] = false;
      // data updated
      unawaited(SyncService.writePages(ws, pid, pages));
    } catch (_) {
      _pagesLoading[k] = false;
      // data updated
    }
  }

  void invalidatePages(String ws, String pid) {
    _pages.remove('$ws/$pid');
  }

  // -------------------------------------------------------------------------
  //  Bulk: load core project data in parallel
  // -------------------------------------------------------------------------

  /// Load states + issues for a project in parallel. Used by IssuesTabScreen.
  Future<void> loadProjectCoreData(String ws, String pid) async {
    await Future.wait([
      loadStates(ws, pid),
      loadIssues(ws, pid),
    ]);
  }

  /// Load labels + members in background (non-blocking).
  Future<void> loadProjectExtras(String ws, String pid) async {
    await Future.wait([
      loadLabels(ws, pid),
      loadMembers(ws, pid),
    ]);
  }

  /// Force refresh states + issues.
  Future<void> refreshProjectCoreData(String ws, String pid) async {
    invalidateIssues(ws, pid);
    _states.remove('$ws/$pid');
    await loadProjectCoreData(ws, pid);
  }

  // -------------------------------------------------------------------------
  //  Clear all
  // -------------------------------------------------------------------------

  void clearProjects(String workspaceSlug) {
    _projects.remove(workspaceSlug);
  }

  void clearProjectData(String projectId) {
    _states.remove(projectId);
    _issues.remove(projectId);
    _labels.remove(projectId);
    _members.remove(projectId);
    _cycles.remove(projectId);
    _modules.remove(projectId);
    _pages.remove(projectId);
  }

  void clearAll() {
    _projects.clear();
    _states.clear();
    _issues.clear();
    _labels.clear();
    _members.clear();
    _cycles.clear();
    _modules.clear();
    _pages.clear();
    _inflight.clear();
    // Also clear SQLite
    unawaited(AppDatabase.clearAll());
    // data updated
  }
}

// ---------------------------------------------------------------------------
//  Single global Riverpod provider for the cache
// ---------------------------------------------------------------------------

final dataCacheProvider = Provider<DataCache>((ref) {
  return DataCache();
});
