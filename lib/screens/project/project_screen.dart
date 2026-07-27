import 'package:flutter/material.dart';
import 'project_settings_screen.dart';
import '../../config/m3e/shapes.dart';
import '../../config/m3e/typography.dart';
import '../../config/theme.dart';
import '../../widgets/m3e/app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/member_permissions.dart';
import '../../models/project.dart';
import '../../providers/data_providers.dart';
import '../../services/intake_service.dart';
import '../../services/member_service.dart';
import '../../services/workspace_service.dart';
import '../../widgets/app_navbar.dart';
import '../intake/intake_screen.dart';
import '../issues/issues_tab_screen.dart';
import '../issues/issue_create_screen.dart';
import '../pages/page_list_screen.dart';
import '../modules/module_list_screen.dart';
import '../cycles/cycle_list_screen.dart';
import '../views/view_list_screen.dart';
import '../search/search_screen.dart';

class ProjectScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final Project project;

  const ProjectScreen(
      {super.key, required this.workspaceSlug, required this.project});

  @override
  ConsumerState<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends ConsumerState<ProjectScreen> {
  int _tab = 0;

  /// Whether this project offers Intake, and how much is queued.
  ///
  /// Seeded from the project the screen was handed — the workspace project
  /// list annotates both `inbox_view` and `intake_count`, so in the normal
  /// path this is already right and the action appears with the first frame.
  /// It is confirmed against the server anyway because a project read out of
  /// the SQLite cache predates both columns and would report intake off.
  IntakeAvailability _intake = const IntakeAvailability(enabled: false);

  /// What the signed-in user may create in this project.
  ///
  /// Starts fully closed and is only opened by an answer from the server.
  /// Plane gates creation by role — a cycle, module, page and work item all
  /// need admin or member — so guessing would mean offering a guest a button
  /// that returns a 403 after they have filled the form in. The cost of failing
  /// closed is that the action appears a moment after the screen does, which is
  /// the same trade the intake badge makes above.
  MemberPermissions _permissions = const MemberPermissions();

  /// Each list owns its own create flow: it is the thing that has to refresh
  /// afterwards, and the same flow backs the button in its empty state. The
  /// app-bar action reaches the visible one through its key rather than keeping
  /// a second copy of the flow up here.
  final _pagesKey = GlobalKey<PageListScreenState>();
  final _modulesKey = GlobalKey<ModuleListScreenState>();
  final _viewsKey = GlobalKey<ViewListScreenState>();
  final _cyclesKey = GlobalKey<CycleListScreenState>();

  /// The bottom-bar destinations. Intake is deliberately not one of them.
  ///
  /// `AppNavBar` shows four destinations plus a More sheet as soon as it is
  /// given more than five, so a sixth entry does not crowd the bar — it
  /// silently demotes the fifth, Cycles, into a bottom sheet. Two things make
  /// that a bad trade. Cycles is a place people go daily and Intake is a queue
  /// that is empty most of the time; and because Intake is per-project, the
  /// bar would then have a different shape in two projects of the same
  /// workspace, with Cycles present in one and hidden in the other. Bottom
  /// navigation that rearranges itself between sibling screens is worse than
  /// one destination being an app-bar action.
  ///
  /// So it lives here instead, where it can also carry the pending count —
  /// which is the only thing that makes the queue worth a trip — and where it
  /// can be absent entirely for the projects that have Intake switched off.
  static const _navItems = [
    NavItem(
        icon: Icons.list_alt_outlined,
        activeIcon: Icons.list_alt,
        label: 'Issues'),
    NavItem(
        icon: Icons.description_outlined,
        activeIcon: Icons.description,
        label: 'Pages'),
    NavItem(
        icon: Icons.view_module_outlined,
        activeIcon: Icons.view_module,
        label: 'Modules'),
    NavItem(
        icon: Icons.visibility_outlined,
        activeIcon: Icons.visibility,
        label: 'Views'),
    NavItem(icon: Icons.loop_outlined, activeIcon: Icons.loop, label: 'Cycles'),
  ];

  @override
  void initState() {
    super.initState();
    _intake = IntakeAvailability(
      enabled: widget.project.intakeEnabled,
      pendingCount: widget.project.pendingIntakeCount,
    );
    _refreshIntake();
    _resolvePermissions();
  }

  /// Read the caller's project and workspace roles, once per visit.
  ///
  /// Both are needed, not just the project one: Plane's `allow_permission`
  /// decorator also passes anyone who is an active project member *and* a
  /// workspace admin, which is how a workspace admin who joined a project as a
  /// guest can still create in it. Both service calls swallow their own errors
  /// and answer null, so a failure leaves every create control hidden rather
  /// than offering one that cannot work.
  Future<void> _resolvePermissions() async {
    final project =
        MemberService.getMyMembership(widget.workspaceSlug, widget.project.id);
    final workspace = WorkspaceService.getMyMembership(widget.workspaceSlug);
    final roles = (project: await project, workspace: await workspace);
    if (!mounted) return;
    setState(() {
      _permissions = MemberPermissions(
        projectRole: roles.project?.role,
        workspaceRole: roles.workspace?.role,
      );
    });
  }

  Future<void> _refreshIntake() async {
    try {
      final resolved = await IntakeService.resolveAvailability(
        widget.workspaceSlug,
        widget.project.id,
      );
      if (mounted) setState(() => _intake = resolved);
    } catch (_) {
      // Leave the seeded value alone. Hiding an entry point because one
      // request failed would be a worse answer than a slightly stale badge.
    }
  }

  void _openIntake() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IntakeScreen(
          workspaceSlug: widget.workspaceSlug,
          projectId: widget.project.id,
          projectIdentifier: widget.project.identifier,
        ),
      ),
    );
    // Triaging changes the pending count, and the badge is the only thing on
    // this screen that shows it.
    _refreshIntake();
  }

  void _createIssue() async {
    final states = ref
            .read(dataCacheProvider)
            .getStates(widget.workspaceSlug, widget.project.id) ??
        {};
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IssueCreateScreen(
          workspaceSlug: widget.workspaceSlug,
          projectId: widget.project.id,
          states: states,
        ),
      ),
    );
  }

  /// The create action for whichever destination is on screen.
  ///
  /// One primary action, always in the same place, that means whatever the
  /// current tab is about. Before this, the four lists behind the other four
  /// destinations had create flows with no call site anywhere in the app: a
  /// cycle, module, page or view could not be created at all from the phone.
  ///
  /// Null when the user's role would be refused, which is also when the empty
  /// state below drops its button — one gate, read in two places.
  ///
  /// Work items keep the compose glyph they have always had. The four lists
  /// share one plus rather than each picking a glyph of its own: the
  /// destination underneath already says what is being added, and the tooltip
  /// — which is the accessible name — says it again.
  ({IconData icon, String tooltip, VoidCallback onPressed})? get _createAction {
    switch (_tab) {
      case 0:
        if (!_permissions.canCreateIssue) return null;
        return (
          icon: Icons.edit_square,
          tooltip: 'New issue',
          onPressed: _createIssue
        );
      case 1:
        if (!_permissions.canCreatePage) return null;
        return (
          icon: Icons.add,
          tooltip: 'New page',
          onPressed: () => _pagesKey.currentState?.startCreate()
        );
      case 2:
        if (!_permissions.canCreateModule) return null;
        return (
          icon: Icons.add,
          tooltip: 'New module',
          onPressed: () => _modulesKey.currentState?.startCreate()
        );
      case 3:
        if (!_permissions.canCreateView) return null;
        return (
          icon: Icons.add,
          tooltip: 'New view',
          onPressed: () => _viewsKey.currentState?.startCreate()
        );
      case 4:
        if (!_permissions.canCreateCycle) return null;
        return (
          icon: Icons.add,
          tooltip: 'New cycle',
          onPressed: () => _cyclesKey.currentState?.startCreate()
        );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final create = _createAction;

    return Scaffold(
      appBar: M3EAppBar(
        title: widget.project.name,
        subtitle: widget.project.identifier,
        actions: [
          if (_intake.enabled)
            _IntakeAction(
              pendingCount: _intake.pendingCount,
              onPressed: _openIntake,
            ),
          // `ProjectSettingsScreen` had no call site anywhere in the app: the
          // whole screen — general, members, states, labels, integrations and
          // the Features section — was written, compiled and unreachable. The
          // analyzer does not report that for a public class, which is exactly
          // how the four create flows stayed dead as well.
          M3EAppBarAction(
            icon: Icons.settings_outlined,
            tooltip: 'Project settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProjectSettingsScreen(
                  workspaceSlug: widget.workspaceSlug,
                  project: widget.project,
                ),
              ),
            ),
          ),
          // The one primary action on this screen, so it takes the emphasized
          // tonal treatment rather than being another grey glyph. The tooltip
          // is the accessible name and it names what will be created, so the
          // action does not read as "add" with no object.
          if (create != null)
            M3EAppBarAction(
              icon: create.icon,
              tooltip: create.tooltip,
              emphasized: true,
              onPressed: create.onPressed,
            ),
        ],
      ),
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          IssuesTabScreen(
              workspaceSlug: widget.workspaceSlug,
              projectId: widget.project.id,
              projectIdentifier: widget.project.identifier),
          PageListScreen(
              key: _pagesKey,
              workspaceSlug: widget.workspaceSlug,
              projectId: widget.project.id,
              canCreate: _permissions.canCreatePage),
          ModuleListScreen(
              key: _modulesKey,
              workspaceSlug: widget.workspaceSlug,
              projectId: widget.project.id,
              canCreate: _permissions.canCreateModule),
          ViewListScreen(
              key: _viewsKey,
              workspaceSlug: widget.workspaceSlug,
              projectId: widget.project.id,
              canCreate: _permissions.canCreateView),
          CycleListScreen(
              key: _cyclesKey,
              workspaceSlug: widget.workspaceSlug,
              projectId: widget.project.id,
              canCreate: _permissions.canCreateCycle),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        items: _navItems,
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        showSearch: true,
        onSearchTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SearchScreen(
                workspaceSlug: widget.workspaceSlug,
                autoFocus: true,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The way into the project's Intake queue, with what is waiting in it.
///
/// The count is the point. An icon that only says "there is a triage queue
/// here" is worth almost nothing on a screen someone opens twenty times a day;
/// a number that says three things are waiting is why they would tap it. When
/// the count is not known — a project opened from a search hit, or a count
/// request that failed — the badge is simply absent rather than showing a zero
/// nobody counted.
///
/// The word "Intake" is used and the word "Inbox" is not, anywhere in the
/// label. The app's Inbox is the notification feed and lives in the home tab
/// bar; these are different places and must not read as the same one.
class _IntakeAction extends StatelessWidget {
  final int? pendingCount;
  final VoidCallback onPressed;

  const _IntakeAction({required this.pendingCount, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final count = pendingCount;
    final showBadge = count != null && count > 0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        M3EAppBarAction(
          icon: Icons.fact_check_outlined,
          // The tooltip is the accessible name, so it has to carry the count
          // too — the badge below sits outside the button's semantics node.
          tooltip: showBadge
              ? 'Intake, $count waiting to be triaged'
              : 'Intake triage queue',
          onPressed: onPressed,
        ),
        if (showBadge)
          Positioned(
            // Pinned to the top-right of the 48dp action circle.
            right: 4,
            top: 4,
            // The count is already in the action's own label; a second node
            // reading just "3" would be noise in the accessibility tree and a
            // second, meaningless target for `tool/adb_drive.py`.
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: PlaneTheme.pendingColor(context),
                    borderRadius: BorderRadius.circular(M3EShape.full),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: M3EType.emphasized(
                      Theme.of(context).textTheme.labelSmall!,
                    ).copyWith(color: PlaneTheme.onPendingColor(context)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
