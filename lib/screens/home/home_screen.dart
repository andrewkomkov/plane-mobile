import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/secure_storage.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../../database/write_queue.dart';
import '../../widgets/app_navbar.dart';
import '../search/search_screen.dart';
import '../command_palette/command_palette.dart';
import 'inbox_tab.dart';
import 'my_issues_tab.dart';
import 'projects_tab.dart';
import 'menu_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentTab = 0;
  String _workspaceSlug = '';
  User? _user;
  int _rebuildKey = 0;
  bool _searchAutoFocus = false;
  int _pendingWrites = 0;

  static const _navItems = [
    NavItem(icon: Icons.inbox_outlined, activeIcon: Icons.inbox, label: 'Inbox'),
    NavItem(icon: Icons.task_alt_outlined, activeIcon: Icons.task_alt, label: 'My Tasks'),
    NavItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view, label: 'Projects'),
    NavItem(icon: Icons.menu, activeIcon: Icons.menu, label: 'More'),
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _workspaceSlug = await SecureStorage.getWorkspaceSlug() ?? '';
    try {
      _user = await AuthService.getCurrentUser();
    } catch (_) {}
    setState(() {});
    _drainWriteQueue();
  }

  Future<void> _drainWriteQueue() async {
    await _refreshPendingCount();
    if (_pendingWrites > 0) {
      await WriteQueue.syncAll();
      await _refreshPendingCount();
    }
  }

  Future<void> _refreshPendingCount() async {
    final count = await WriteQueue.pendingCount();
    if (mounted && count != _pendingWrites) {
      setState(() => _pendingWrites = count);
    }
  }

  void _onWorkspaceChanged() async {
    _workspaceSlug = await SecureStorage.getWorkspaceSlug() ?? '';
    setState(() => _rebuildKey++);
  }

  void _openCommandPalette() {
    CommandPalette.show(context, _workspaceSlug);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        key: ValueKey(_rebuildKey),
        index: _currentTab,
        children: [
          InboxTab(workspaceSlug: _workspaceSlug),
          MyIssuesTab(workspaceSlug: _workspaceSlug, currentUserId: _user?.id),
          ProjectsTab(workspaceSlug: _workspaceSlug),
          MenuTab(
              workspaceSlug: _workspaceSlug,
              user: _user,
              onLogout: widget.onLogout,
              onWorkspaceChanged: _onWorkspaceChanged,
              pendingWrites: _pendingWrites,
              onSyncQueue: _drainWriteQueue),
          SearchScreen(workspaceSlug: _workspaceSlug, autoFocus: _searchAutoFocus),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: AppNavBar(
        items: _navItems,
        currentIndex: _currentTab < 4 ? _currentTab : -1,
        pendingWrites: _pendingWrites,
        onTap: (i) => setState(() {
          _currentTab = i;
          _searchAutoFocus = false;
        }),
        showSearch: true,
        onSearchTap: () => setState(() {
          _currentTab = 4;
          _searchAutoFocus = false;
        }),
        onSearchLongPress: _openCommandPalette,
        onSearchDoubleTap: () {
          setState(() {
            _searchAutoFocus = true;
            _currentTab = 4;
            _rebuildKey++;
          });
        },
      ),
    );
  }
}
