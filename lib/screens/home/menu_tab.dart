import 'package:flutter/material.dart';
import '../../utils/say.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_client.dart';
import '../../config/secure_storage.dart';
import '../../config/theme.dart';
import '../../models/user.dart';
import '../../models/workspace.dart';
import '../../providers/data_providers.dart';
import '../../providers/workspace_provider.dart';
import '../../services/update_service.dart';
import '../../services/workspace_service.dart';
import '../../utils/new_issue_flow.dart';
import '../../widgets/app_navbar.dart';
import '../../widgets/bottom_sheet_picker.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/m3e/flexible_app_bar.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/m3e/loading_indicator.dart';
import '../../widgets/plane_row.dart';
import '../../widgets/section_header.dart';
import '../analytics/analytics_screen.dart';
import '../notifications/notification_screen.dart';
import '../profile/profile_screen.dart';
import '../workspace/workspace_cycles_screen.dart';
import '../workspace/workspace_issues_screen.dart';
import '../workspace/workspace_members_screen.dart';
import '../workspace/workspace_modules_screen.dart';
import '../workspace/workspace_views_screen.dart';

/// The workspace-scoped tab: who you are, where else you can go, and the way
/// out.
///
/// Everything on this screen used to be built here and nowhere else — its own
/// header, its own row, its own grouped card, its own workspace picker, its own
/// disconnect button. Four of the five now come from the shared widgets the
/// rest of the app already used: [M3EFlexibleHeaderScaffold] like the three
/// sibling home tabs, [PlaneRow] like every other list, [SectionHeader] for the
/// groups and [BottomSheetPicker] for the workspace switch. The grouped card
/// went with them: a run of rows under a heading is how this app draws a group,
/// and the bordered slab was a fifth answer to a question already settled.
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

  /// The installed version, read from the manifest rather than written here.
  /// The about box used to carry a literal "1.0.0" that nothing updated.
  String _version = '';

  /// A newer release, once the quiet check on open has found one.
  AppUpdate? _update;
  bool _checkingUpdate = false;
  UpdateProgress? _updateProgress;

  @override
  void initState() {
    super.initState();
    _loadWorkspaces();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final version = await UpdateService.currentVersion();
    if (!mounted) return;
    setState(() => _version = version);
    // Quiet: a check that finds nothing, or cannot reach GitHub, says nothing.
    final update = await UpdateService.check();
    if (!mounted || update == null) return;
    setState(() => _update = update);
  }

  Future<void> _loadWorkspaces() async {
    setState(() => _loadingWorkspaces = true);
    try {
      _workspaces = await WorkspaceService.getWorkspaces();
      _currentWorkspace =
          _workspaces.where((w) => w.slug == widget.workspaceSlug).firstOrNull;
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loadingWorkspaces = false);
  }

  Future<void> _showSwitchWorkspace() async {
    if (_workspaces.isEmpty) {
      say(context, 'No workspaces found');
      return;
    }

    final picked = await BottomSheetPicker.show<String>(
      context: context,
      title: 'Switch workspace',
      selectedValue: widget.workspaceSlug,
      items: [
        for (final ws in _workspaces)
          BottomSheetPickerItem<String>(
            value: ws.slug,
            label: ws.name,
            // The slug is what every route in the app is keyed on, and two
            // workspaces can share a display name.
            subtitle: ws.slug,
            leading: _WorkspaceMark(workspace: ws),
          ),
      ],
    );
    if (picked == null || picked == widget.workspaceSlug) return;

    await SecureStorage.saveWorkspaceSlug(picked);
    ApiClient.reset();
    if (!mounted) return;
    ref.read(workspaceProvider.notifier).setSlug(picked);
    widget.onWorkspaceChanged?.call();
  }

  Future<void> _disconnect() async {
    final ok = await confirmDestructive(
      context,
      title: 'Disconnect',
      message: 'Disconnect from this instance? Your saved credentials and the '
          'work items cached on this device are removed.',
      confirmLabel: 'Disconnect',
    );
    if (!ok) return;
    await SecureStorage.clear();
    ApiClient.reset();
    widget.onLogout();
  }

  /// The about box.
  ///
  /// Not `showAboutDialog`: that draws Material's own dialog layout and drags
  /// in a stock licence page, in an app where every other dialog is themed.
  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Plane Mobile'),
        content: Text(
          'Version ${_version.isEmpty ? 'unknown' : _version}\n\n'
          'A mobile client for a self-hosted Plane instance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Look for a release now, and say so either way.
  ///
  /// The check on open is deliberately silent; this one is not, because the
  /// user asked.
  Future<void> _checkForUpdate() async {
    final pending = _update;
    if (pending != null) {
      await _offerUpdate(pending);
      return;
    }

    setState(() => _checkingUpdate = true);
    final found = await UpdateService.check();
    if (!mounted) return;
    setState(() {
      _checkingUpdate = false;
      _update = found;
    });
    if (found == null) {
      say(context, 'You are on the latest version');
    } else {
      await _offerUpdate(found);
    }
  }

  Future<void> _offerUpdate(AppUpdate update) async {
    final notes = update.notes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Version ${update.version}'),
        content: SingleChildScrollView(
          child: Text(
            notes ?? 'A newer release is available.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(update.installable ? 'Update' : 'Open release'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    if (!update.installable) {
      say(context, 'That release has no build attached');
      return;
    }

    // Granted once, by hand, on a settings screen Android will not let an app
    // skip. Asking first means the download is not wasted.
    if (!await UpdateService.canInstall()) {
      if (!mounted) return;
      say(context, 'Allow installing apps from Plane, then try again');
      await UpdateService.requestInstallPermission();
      return;
    }

    setState(
        () => _updateProgress = const UpdateProgress(UpdateStage.download));
    final error = await UpdateService.install(
      update,
      onProgress: (p) {
        if (mounted) setState(() => _updateProgress = p);
      },
    );
    if (!mounted) return;
    setState(() => _updateProgress = null);
    if (error != null) say(context, error);
  }

  /// What the update row says, which is the whole of its state.
  String get _updateLabel {
    if (_updateProgress != null) {
      return switch (_updateProgress!.stage) {
        UpdateStage.download => 'Downloading…',
        UpdateStage.verify => 'Checking the download…',
        UpdateStage.install => 'Handing it to the installer…',
      };
    }
    if (_checkingUpdate) return 'Checking…';
    final update = _update;
    if (update != null) return 'Update to ${update.version}';
    return 'Check for updates';
  }

  String? get _updateSubtitle {
    final progress = _updateProgress;
    if (progress != null && progress.stage == UpdateStage.download) {
      final fraction = progress.fraction;
      return fraction == null ? null : '${(fraction * 100).round()}%';
    }
    return _version.isEmpty ? null : 'Version $_version';
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  /// One destination. A thin adapter over [PlaneRow] rather than a row of its
  /// own: it exists only to assemble the semantic label from the two strings
  /// the row already draws, because [PlaneRow] hands that label to
  /// [M3EPressable], which replaces everything underneath it.
  Widget _menuRow({
    required IconData icon,
    required String label,
    String? subtitle,
    List<Widget> metadata = const [],
    required VoidCallback onTap,
  }) =>
      PlaneRow(
        icon: icon,
        title: label,
        subtitle: subtitle,
        metadata: metadata,
        semanticLabel: subtitle == null ? label : '$label, $subtitle',
        onTap: onTap,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.user;
    final wsName = _currentWorkspace?.name ?? widget.workspaceSlug;

    return M3EFlexibleHeaderScaffold(
      title: 'More',
      // No `leading:`, so the header draws the same decorative workspace mark
      // as the three sibling tabs.
      //
      // The switcher lives in the list below rather than up here, and that is
      // deliberate: `M3EFlexibleHeaderScaffold` puts its toolbar row in a
      // `SizedBox(height: 40)`, which tightly constrains anything inside it, so
      // an `M3EIconButton` in the header slot measures 40dp however hard it
      // asks for 48. As a `PlaneRow` the switcher keeps the floor. (The same
      // clamp already applies to every header `actions:` button in the app —
      // see the report.)
      actions: [
        M3EIconButton(
          icon: Icons.edit_square,
          tooltip: 'New issue',
          onPressed: () => startNewIssue(
            context,
            cache: ref.read(dataCacheProvider),
            workspaceSlug: widget.workspaceSlug,
          ),
        ),
      ],
      body: ListView(
        padding: EdgeInsets.only(top: 8, bottom: appNavBarClearance(context)),
        children: [
          if (user != null)
            PlaneRow(
              leading: _UserMark(user: user),
              title: user.displayName,
              subtitle: user.email,
              semanticLabel:
                  '${user.displayName}, ${user.email}, open profile and '
                  'appearance',
              onTap: () => _push(ProfileScreen(user: user)),
            ),
          const SectionHeader(label: 'Workspace'),
          PlaneRow(
            icon: Icons.sync_alt,
            title: 'Switch workspace',
            subtitle: 'Current: $wsName',
            // In `metadata`, not `trailing`: the spinner is an indicator, and
            // `trailing` is the slot reserved for controls that need a
            // semantics node of their own. The box matches the indicator — at
            // 16 it clipped an 18dp shape, the same bug profile_screen fixed.
            metadata: _loadingWorkspaces
                ? const [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: M3ELoadingIndicator(size: 18),
                    ),
                  ]
                : const [],
            // Names the action first and the current value second. The old
            // control was a row of glyphs whose only visible word was the
            // workspace name, which says nothing about what tapping it does.
            semanticLabel: 'Switch workspace, current: $wsName',
            onTap: _showSwitchWorkspace,
          ),
          _menuRow(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            onTap: () =>
                _push(NotificationScreen(workspaceSlug: widget.workspaceSlug)),
          ),
          _menuRow(
            icon: Icons.analytics_outlined,
            label: 'Analytics',
            onTap: () =>
                _push(AnalyticsScreen(workspaceSlug: widget.workspaceSlug)),
          ),
          _menuRow(
            icon: Icons.people_outline,
            label: 'Workspace members',
            onTap: () => _push(
                WorkspaceMembersScreen(workspaceSlug: widget.workspaceSlug)),
          ),
          _menuRow(
            icon: Icons.cloud_upload_outlined,
            label: 'Sync queue',
            subtitle: widget.pendingWrites > 0
                ? '${widget.pendingWrites} pending'
                : 'All synced',
            onTap: () {
              widget.onSyncQueue?.call();
              say(context, 'Syncing queued writes…');
            },
          ),
          // The cross-project rollups: the same entities the project tabs show,
          // listed across the whole workspace. This tab is the app's only
          // workspace-scoped surface — everywhere else you are already inside a
          // project — so it is where a list that spans projects belongs.
          const SectionHeader(label: 'Across projects'),
          _menuRow(
            icon: Icons.all_inbox_outlined,
            label: 'All work items',
            subtitle: 'Across every project',
            onTap: () => _push(
                WorkspaceIssuesScreen(workspaceSlug: widget.workspaceSlug)),
          ),
          _menuRow(
            icon: Icons.view_list_outlined,
            label: 'Workspace views',
            subtitle: 'Saved filters that span projects',
            onTap: () => _push(
                WorkspaceViewsScreen(workspaceSlug: widget.workspaceSlug)),
          ),
          _menuRow(
            icon: Icons.loop,
            label: 'All cycles',
            onTap: () => _push(
                WorkspaceCyclesScreen(workspaceSlug: widget.workspaceSlug)),
          ),
          _menuRow(
            icon: Icons.view_module_outlined,
            label: 'All modules',
            onTap: () => _push(
                WorkspaceModulesScreen(workspaceSlug: widget.workspaceSlug)),
          ),
          const SectionHeader(label: 'Settings'),
          _menuRow(
            icon: Icons.palette_outlined,
            label: 'Profile & appearance',
            onTap: () => _push(ProfileScreen(user: widget.user)),
          ),
          // The app is installed from an APK, so there is no store to deliver
          // an update. This row is the only channel.
          _menuRow(
            icon: _update == null
                ? Icons.system_update_outlined
                : Icons.new_releases_outlined,
            label: _updateLabel,
            subtitle: _updateSubtitle,
            onTap: _updateProgress == null || _checkingUpdate
                ? _checkForUpdate
                : () {},
          ),
          _menuRow(
            icon: Icons.info_outline,
            label: 'About Plane',
            onTap: _showAbout,
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              // A button, not a `GestureDetector` around a `Container`: the
              // button theme carries the corner, the padding and the 48dp
              // height, and `errorContainer` pairs with `onErrorContainer` —
              // the slab underneath drew a 20%-alpha `errorContainer` fill and
              // then put `error` on top of it, which is not the paired role.
              child: FilledButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.logout, size: PlaneTheme.iconLarge),
                label: const Text('Disconnect'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The circular mark for a workspace, in the picker.
class _WorkspaceMark extends StatelessWidget {
  final Workspace workspace;

  const _WorkspaceMark({required this.workspace});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logo = workspace.logo;
    if (logo != null && logo.isNotEmpty) {
      return CircleAvatar(radius: 16, backgroundImage: NetworkImage(logo));
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      child: Text(
        workspace.name.isNotEmpty ? workspace.name[0].toUpperCase() : '?',
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

/// The signed-in user's avatar, in the row that opens their profile.
///
/// `titleMedium` for the initial rather than the `headlineSmall` it was: a
/// decorative letter should not be the largest type on a screen whose headings
/// are smaller than it.
class _UserMark extends StatelessWidget {
  final User user;

  const _UserMark({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatar = user.avatar;
    if (avatar != null && avatar.isNotEmpty) {
      return CircleAvatar(radius: 20, backgroundImage: NetworkImage(avatar));
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      child: Text(
        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
        style: theme.textTheme.titleMedium
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
