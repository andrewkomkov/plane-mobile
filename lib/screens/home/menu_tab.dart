import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/secure_storage.dart';
import '../../config/api_client.dart';
import '../../models/user.dart';
import '../../models/workspace.dart';
import '../../models/member.dart';
import '../../services/workspace_service.dart';
import '../../providers/workspace_provider.dart';
import '../../widgets/loading_state.dart';
import '../notifications/notification_screen.dart';
import '../analytics/analytics_screen.dart';
import '../profile/profile_screen.dart';

class MenuTab extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final User? user;
  final VoidCallback onLogout;
  final VoidCallback? onWorkspaceChanged;
  final int pendingWrites;
  final VoidCallback? onSyncQueue;

  const MenuTab({
    super.key,
    required this.workspaceSlug,
    this.user,
    required this.onLogout,
    this.onWorkspaceChanged,
    this.pendingWrites = 0,
    this.onSyncQueue,
  });

  @override
  ConsumerState<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends ConsumerState<MenuTab> {
  Workspace? _currentWorkspace;
  List<Workspace> _workspaces = [];
  bool _loadingWorkspaces = false;

  @override
  void initState() {
    super.initState();
    _loadWorkspaces();
  }

  Future<void> _loadWorkspaces() async {
    setState(() => _loadingWorkspaces = true);
    try {
      _workspaces = await WorkspaceService.getWorkspaces();
      _currentWorkspace = _workspaces
          .where((w) => w.slug == widget.workspaceSlug)
          .firstOrNull;
    } catch (_) {}
    setState(() => _loadingWorkspaces = false);
  }

  void _showSwitchWorkspace() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Switch Workspace',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            if (_workspaces.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No workspaces found'),
              )
            else
              ..._workspaces.map((ws) => ListTile(
                    leading: ws.logo != null && ws.logo!.isNotEmpty
                        ? CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(ws.logo!),
                          )
                        : CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(ctx)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.2),
                            child: Text(
                              ws.name.isNotEmpty
                                  ? ws.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      Theme.of(ctx).colorScheme.primary),
                            ),
                          ),
                    title:
                        Text(ws.name, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(ws.slug,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurfaceVariant)),
                    trailing: ws.slug == widget.workspaceSlug
                        ? const Icon(Icons.check, size: 18)
                        : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (ws.slug != widget.workspaceSlug) {
                        await SecureStorage.saveWorkspaceSlug(ws.slug);
                        ApiClient.reset();
                        ref
                            .read(workspaceProvider.notifier)
                            .setSlug(ws.slug);
                        widget.onWorkspaceChanged?.call();
                      }
                    },
                  )),
          ],
        ),
      ),
    );
  }

  void _showWorkspaceMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _WorkspaceMembersScreen(workspaceSlug: widget.workspaceSlug),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wsName =
        _currentWorkspace?.name ?? widget.workspaceSlug;

    return SafeArea(
      bottom: false,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar matching mockup: grid icon + Plane + unfold + avatar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _showSwitchWorkspace,
                    child: Row(
                      children: [
                        Icon(Icons.grid_view, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Text(
                          'Plane',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.unfold_more,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.edit_square,
                        size: 20, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                height: 0.5,
                color: theme.colorScheme.outline.withValues(alpha: 0.30),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // User profile section
                  if (widget.user != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.15),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor:
                                theme.colorScheme.primary.withValues(alpha: 0.15),
                            child: Text(
                              widget.user!.displayName[0].toUpperCase(),
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.user!.displayName,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                      color: theme.colorScheme.onSurface)),
                              const SizedBox(height: 2),
                              Text(widget.user!.email,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Menu group 1
                  _MenuGroup(
                    children: [
                      _MenuRow(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NotificationScreen(
                                  workspaceSlug: widget.workspaceSlug),
                            ),
                          );
                        },
                      ),
                      _MenuRow(
                        icon: Icons.analytics_outlined,
                        label: 'Analytics',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AnalyticsScreen(
                                  workspaceSlug: widget.workspaceSlug),
                            ),
                          );
                        },
                      ),
                      _MenuRow(
                        icon: Icons.people_outline,
                        label: 'Workspace Members',
                        onTap: _showWorkspaceMembers,
                      ),
                      _MenuRow(
                        icon: Icons.cloud_upload_outlined,
                        label: 'Sync Queue',
                        subtitle: widget.pendingWrites > 0
                            ? '${widget.pendingWrites} pending'
                            : 'All synced',
                        onTap: () {
                          widget.onSyncQueue?.call();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Syncing queued writes...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Menu group 2
                  _MenuGroup(
                    children: [
                      _MenuRow(
                        icon: Icons.sync_alt,
                        label: 'Switch Workspace',
                        subtitle: 'Current: $wsName',
                        trailing: _loadingWorkspaces
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : null,
                        onTap: _showSwitchWorkspace,
                      ),
                      _MenuRow(
                        icon: Icons.palette_outlined,
                        label: 'Profile & Appearance',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProfileScreen(user: widget.user),
                            ),
                          );
                        },
                      ),
                      _MenuRow(
                        icon: Icons.info_outline,
                        label: 'About Plane',
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'Plane Mobile',
                            applicationVersion: '1.0.0',
                            children: [const Text('Plane.so mobile client')],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Disconnect button
                  GestureDetector(
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Disconnect'),
                          content: const Text('Disconnect from this instance?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Disconnect')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await SecureStorage.clear();
                        ApiClient.reset();
                        widget.onLogout();
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, size: 20, color: theme.colorScheme.error),
                          const SizedBox(width: 10),
                          Text(
                            'Disconnect',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final List<Widget> children;
  const _MenuGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 0.5,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.06),
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  const _MenuRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(Icons.chevron_right,
                  size: 18, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceMembersScreen extends StatefulWidget {
  final String workspaceSlug;
  const _WorkspaceMembersScreen({required this.workspaceSlug});

  @override
  State<_WorkspaceMembersScreen> createState() =>
      _WorkspaceMembersScreenState();
}

class _WorkspaceMembersScreenState
    extends State<_WorkspaceMembersScreen> {
  List<Member> _members = [];
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
      _members =
          await WorkspaceService.getWorkspaceMembers(widget.workspaceSlug);
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Workspace Members')),
      body: _loading
          ? const LoadingStateWidget()
          : _error != null
              ? ErrorStateWidget(
                  message: 'Failed to load members', onRetry: _load)
              : _members.isEmpty
                  ? const EmptyStateWidget(
                      message: 'No members found',
                      icon: Icons.people_outline)
                  : ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (ctx, i) {
                        final m = _members[i];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.2),
                            backgroundImage:
                                m.avatar != null && m.avatar!.isNotEmpty
                                    ? NetworkImage(m.avatar!)
                                    : null,
                            child:
                                m.avatar == null || m.avatar!.isEmpty
                                    ? Text(
                                        (m.displayName.isNotEmpty
                                                ? m.displayName
                                                : '?')[0]
                                            .toUpperCase(),
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: theme
                                                .colorScheme.primary),
                                      )
                                    : null,
                          ),
                          title: Text(m.displayName,
                              style: const TextStyle(fontSize: 14)),
                          subtitle: Text(m.email,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme
                                      .colorScheme.onSurfaceVariant)),
                        );
                      },
                    ),
    );
  }
}
