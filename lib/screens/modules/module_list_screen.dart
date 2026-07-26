import 'package:flutter/material.dart';
import '../../widgets/m3e/text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../services/module_service.dart';
import '../../providers/data_providers.dart';
import '../../models/favorite.dart';
import '../../models/module.dart';
import '../../providers/favorites_provider.dart';
import '../../utils/api_error.dart';
import '../../widgets/archive_toggle.dart';
import '../../widgets/bottom_sheet_picker.dart';
import '../../widgets/favorite_toggle.dart';
import '../../widgets/list_count_header.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/plane_row.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/property_chip.dart';
import '../project/project_screen.dart' show kProjectListBottomInset;
import 'module_detail_screen.dart';

class ModuleListScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String projectId;

  /// Whether the signed-in user may create a module here. Resolved by
  /// `ProjectScreen` against the caller's project role; false until it lands,
  /// so the control never appears for someone the server would refuse.
  final bool canCreate;

  const ModuleListScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    this.canCreate = false,
  });

  @override
  ConsumerState<ModuleListScreen> createState() => ModuleListScreenState();
}

/// Public so `ProjectScreen` can start the create flow through a [GlobalKey].
class ModuleListScreenState extends ConsumerState<ModuleListScreen>
    with AutomaticKeepAliveClientMixin {
  bool _initialLoading = true;
  String? _error;

  /// Whether the list is showing the archive instead of the live modules.
  bool _showArchived = false;

  /// Held outside [DataCache] for the same reason as archived cycles: the
  /// cache persists to SQLite for the offline path, and an archive is a view
  /// a user opens occasionally and expects to be current.
  List<Module>? _archived;
  bool _archivedLoading = false;

  @override
  bool get wantKeepAlive => true;

  DataCache get _cache => ref.read(dataCacheProvider);

  @override
  void initState() {
    super.initState();
    _load();
    // One read per workspace, shared with every other list that draws a star.
    ref.read(favoritesProvider.notifier).load(widget.workspaceSlug);
  }

  List<Module> get _modules =>
      _cache.getModules(widget.workspaceSlug, widget.projectId) ?? [];

  Future<void> _load() async {
    setState(() => _error = null);
    if (_showArchived) return _loadArchived();
    try {
      await _cache.loadModules(widget.workspaceSlug, widget.projectId,
          force: true);
      if (mounted) setState(() => _initialLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _initialLoading = false;
        });
      }
    }
  }

  Future<void> _loadArchived() async {
    setState(() {
      _archivedLoading = true;
      _error = null;
    });
    try {
      final archived = await ModuleService.getArchivedModules(
          widget.workspaceSlug, widget.projectId);
      if (mounted) {
        setState(() {
          _archived = archived;
          _archivedLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _archivedLoading = false;
        });
      }
    }
  }

  void _toggleArchived(bool value) {
    setState(() {
      _showArchived = value;
      _error = null;
    });
    // Either direction refetches: coming back out, the live cache was
    // invalidated by any restore done while we were in, so the live list would
    // otherwise render empty.
    if (value) {
      _loadArchived();
    } else {
      _load();
    }
  }

  Future<void> _unarchive(Module module) async {
    try {
      await ModuleService.unarchiveModule(
          widget.workspaceSlug, widget.projectId, module.id);
      _cache.invalidateModules(widget.workspaceSlug, widget.projectId);
      await _loadArchived();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${module.name} restored')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                describeApiError(e, fallback: 'Could not restore the module')),
          ),
        );
      }
    }
  }

  Future<void> _confirmUnarchive(Module module) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore module'),
        content: Text('Move "${module.name}" back into the active modules?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (ok == true) await _unarchive(module);
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'planned':
        return PlaneTheme.low;
      case 'in-progress':
        return PlaneTheme.started;
      case 'paused':
        return PlaneTheme.medium;
      case 'completed':
        return PlaneTheme.completed;
      case 'cancelled':
        return PlaneTheme.cancelled;
      default:
        return PlaneTheme.backlog;
    }
  }

  String _statusLabel(String? status) {
    if (status == null || status.isEmpty) return 'Backlog';
    return status
        .split('-')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  /// Opens the "new module" form.
  ///
  /// The one entry point, called from the project screen's primary action and
  /// from the empty state below. Does nothing when the caller's role would be
  /// refused — the controls are already hidden in that case, and this is the
  /// second lock on the same door.
  void startCreate() {
    if (!widget.canCreate) return;
    _showCreateModuleDialog();
  }

  /// Every status a module can be opened in, in the order the server declares
  /// them.
  static const List<String> _statuses = [
    'backlog',
    'planned',
    'in-progress',
    'paused',
    'completed',
    'cancelled',
  ];

  void _showCreateModuleDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedStatus = 'planned';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New module'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                M3ETextField(
                  label: 'Name',
                  controller: nameController,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                M3ETextField(
                  label: 'Description',
                  controller: descController,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                // A picker rather than a `DropdownButtonFormField`, so that
                // choosing a status here looks like choosing one anywhere else
                // in the app — and so the status hues come along, which the
                // dropdown never showed.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await BottomSheetPicker.show<String>(
                        context: ctx,
                        title: 'Status',
                        selectedValue: selectedStatus,
                        items: _statuses
                            .map((s) => BottomSheetPickerItem(
                                  value: s,
                                  label: _statusLabel(s),
                                  icon: Icons.circle,
                                  iconColor: _statusColor(s),
                                ))
                            .toList(),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedStatus = picked);
                      }
                    },
                    icon: Icon(Icons.circle,
                        size: PlaneTheme.iconSmall,
                        color: _statusColor(selectedStatus)),
                    label: Text(_statusLabel(selectedStatus)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await ModuleService.createModule(
                    widget.workspaceSlug,
                    widget.projectId,
                    {
                      'name': name,
                      if (descController.text.trim().isNotEmpty)
                        'description': descController.text.trim(),
                      'status': selectedStatus,
                    },
                  );
                  _cache.invalidateModules(
                      widget.workspaceSlug, widget.projectId);
                  _load();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(describeApiError(e,
                            fallback: 'Could not create the module')),
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_showArchived && _initialLoading && _modules.isEmpty) {
      return const ProjectListSkeleton();
    }

    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _showArchived
                  ? _archivedList(favorites)
                  : _liveList(favorites),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final count = _showArchived ? (_archived?.length ?? 0) : _modules.length;
    return ListCountHeader(
      count: count,
      singular: 'module',
      trailing: ArchiveToggle(
        showArchived: _showArchived,
        entityPlural: 'modules',
        onChanged: _toggleArchived,
      ),
    );
  }

  Widget _liveList(FavoritesState favorites) {
    if (_error != null && _modules.isEmpty) {
      return ErrorStateWidget(
          message: 'Failed to load modules', onRetry: _load);
    }
    if (_modules.isEmpty) {
      return ScrollableCenter(
        padding: const EdgeInsets.only(bottom: kProjectListBottomInset),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EmptyStateWidget(
              message: 'No modules',
              icon: Icons.view_module,
              subtitle: 'A module groups the work items that ship one feature',
            ),
            if (widget.canCreate) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: startCreate,
                icon: const Icon(Icons.add),
                label: const Text('New module'),
              ),
            ],
          ],
        ),
      );
    }
    // Favourites first. Plane's own module list already orders `-is_favorite`,
    // so this only changes what happens between a star being tapped and the
    // next fetch — but it is what keeps the projects list, which the server
    // does not order, reading the same way.
    final ordered =
        favorites.favoritesFirst(FavoriteEntity.module, _modules, (m) => m.id);
    return ListView.builder(
      // Without this a list too short to scroll cannot be pulled, so the
      // RefreshIndicator wrapping it never fires.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: kProjectListBottomInset),
      itemCount: ordered.length,
      itemBuilder: (ctx, i) => _moduleRow(module: ordered[i]),
    );
  }

  Widget _archivedList(FavoritesState favorites) {
    if (_error != null) {
      return ErrorStateWidget(
          message: 'Failed to load archived modules', onRetry: _loadArchived);
    }
    final archived = _archived;
    if (archived == null || (_archivedLoading && archived.isEmpty)) {
      return const ProjectListSkeleton();
    }
    if (archived.isEmpty) {
      return const ScrollableEmptyState(
        padding: EdgeInsets.only(bottom: kProjectListBottomInset),
        message: 'No archived modules',
        icon: Icons.inventory_2_outlined,
        subtitle: 'Modules archived from here or from the web appear here',
      );
    }
    final ordered =
        favorites.favoritesFirst(FavoriteEntity.module, archived, (m) => m.id);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: kProjectListBottomInset),
      itemCount: ordered.length,
      itemBuilder: (ctx, i) => _moduleRow(module: ordered[i]),
    );
  }

  /// Same row as a cycle, with the status carried by a chip because this list
  /// is flat where the cycle list groups by status.
  ///
  /// Archived swaps the leading glyph, replaces the date range with the
  /// archive date, and adds a restore button beside the favourite star in the
  /// trailing slot — the one slot [PlaneRow] leaves outside its own semantics
  /// node, so both buttons keep names of their own.
  Widget _moduleRow({required Module module}) {
    final theme = Theme.of(context);
    final archived = module.isArchived;
    final statusColor = archived
        ? theme.colorScheme.onSurfaceVariant
        : _statusColor(module.status);
    final statusLabel = _statusLabel(module.status);
    final dates = [module.startDate, module.targetDate]
        .where((d) => d != null)
        .join(' - ');
    final count = '${module.completedIssues}/${module.totalIssues}';

    return PlaneRow(
      icon: archived ? Icons.inventory_2_outlined : Icons.view_module,
      iconColor: statusColor,
      title: module.name,
      subtitle: archived
          ? archivedOnLabel(module.archivedAt)
          : (dates.isEmpty ? null : dates),
      subtitleTrailing: count,
      progress: module.progress,
      progressColor: statusColor,
      metadata: [
        PropertyChip(
          icon: Icons.circle,
          iconColor: statusColor,
          label: statusLabel,
        ),
      ],
      semanticLabel: [
        module.name,
        if (archived) archivedOnLabel(module.archivedAt),
        statusLabel,
        '$count issues done',
        if (dates.isNotEmpty) dates,
      ].join(', '),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FavoriteToggle(
            workspaceSlug: widget.workspaceSlug,
            entity: FavoriteEntity.module,
            entityId: module.id,
            entityName: module.name,
            projectId: widget.projectId,
          ),
          if (archived)
            M3EIconButton(
              icon: Icons.unarchive_outlined,
              tooltip: 'Restore module ${module.name}',
              size: M3EIconButtonSize.small,
              onPressed: () => _confirmUnarchive(module),
            ),
        ],
      ),
      onTap: () => _openModule(module),
    );
  }

  Future<void> _openModule(Module module) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModuleDetailScreen(
          workspaceSlug: widget.workspaceSlug,
          projectId: widget.projectId,
          module: module,
        ),
      ),
    );
    if (!mounted) return;
    _cache.invalidateModules(widget.workspaceSlug, widget.projectId);
    _load();
  }
}
