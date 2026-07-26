import 'package:flutter/material.dart';
import '../../config/m3e/shapes.dart';
import '../../config/m3e/typography.dart';
import '../../config/theme.dart';
import '../../widgets/m3e/app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/project.dart';
import '../../providers/data_providers.dart';
import '../../services/intake_service.dart';
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

  @override
  Widget build(BuildContext context) {
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
          // The one primary action on this screen, so it takes the emphasized
          // tonal treatment rather than being another grey glyph.
          M3EAppBarAction(
            icon: Icons.edit_square,
            tooltip: 'New issue',
            emphasized: true,
            onPressed: _createIssue,
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
              workspaceSlug: widget.workspaceSlug,
              projectId: widget.project.id),
          ModuleListScreen(
              workspaceSlug: widget.workspaceSlug,
              projectId: widget.project.id),
          ViewListScreen(
              workspaceSlug: widget.workspaceSlug,
              projectId: widget.project.id),
          CycleListScreen(
              workspaceSlug: widget.workspaceSlug,
              projectId: widget.project.id),
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
