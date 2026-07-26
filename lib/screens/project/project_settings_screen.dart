import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../config/m3e/shapes.dart';
import '../../widgets/m3e/loading_indicator.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/m3e/text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/project.dart';
import '../../models/state.dart';
import '../../models/label.dart';
import '../../models/member.dart';
import '../../models/member_permissions.dart';
import '../../services/project_service.dart';
import '../../services/issue_service.dart';
import '../../services/label_service.dart';
import '../../services/member_service.dart';
import '../../services/workspace_service.dart';
import '../../services/integration_service.dart';
import '../../utils/api_error.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/member_row.dart';

class ProjectSettingsScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final Project project;

  const ProjectSettingsScreen({
    super.key,
    required this.workspaceSlug,
    required this.project,
  });

  @override
  ConsumerState<ProjectSettingsScreen> createState() =>
      _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends ConsumerState<ProjectSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  int _network = 0;
  bool _saving = false;

  List<IssueState> _states = [];
  List<Label> _labels = [];
  List<Membership> _members = [];
  List<Map<String, dynamic>> _githubRepos = [];
  bool _loading = true;

  /// What the signed-in user may do to the member list.
  ///
  /// Starts empty, which denies everything: the two role lookups are async and
  /// until they land the screen must offer nothing rather than everything.
  MemberPermissions _permissions = const MemberPermissions();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project.name);
    _descController =
        TextEditingController(text: widget.project.description ?? '');
    _network = widget.project.network;
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final states =
          IssueService.getStates(widget.workspaceSlug, widget.project.id);
      final labels =
          LabelService.getLabels(widget.workspaceSlug, widget.project.id);
      final members = MemberService.getProjectMemberships(
          widget.workspaceSlug, widget.project.id);
      // Both roles are needed before a single action can be offered: the
      // project rules are written in terms of the caller's project role *and*
      // their workspace role, because a workspace admin is exempt from several
      // of the project checks. The workspace call also supplies the caller's
      // own user id, which is what tells their row apart from everyone else's.
      final myProject = MemberService.getMyMembership(
          widget.workspaceSlug, widget.project.id);
      final myWorkspace =
          WorkspaceService.getMyMembership(widget.workspaceSlug);
      final repos = IntegrationService.getGitHubRepositories(
          widget.workspaceSlug, widget.project.id);

      final loaded = (
        states: await states,
        labels: await labels,
        members: await members,
        myProject: await myProject,
        myWorkspace: await myWorkspace,
        repos: await repos,
      );
      if (!mounted) return;
      setState(() {
        _states = loaded.states;
        _labels = loaded.labels;
        _members = loaded.members;
        _githubRepos = loaded.repos;
        _permissions = MemberPermissions(
          currentUserId:
              loaded.myWorkspace?.member.id ?? loaded.myProject?.member.id,
          projectRole: loaded.myProject?.role,
          workspaceRole: loaded.myWorkspace?.role,
        );
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Reload only the member list, after a change to it.
  Future<void> _reloadMembers() async {
    try {
      final members = await MemberService.getProjectMemberships(
          widget.workspaceSlug, widget.project.id);
      if (mounted) setState(() => _members = members);
    } catch (_) {}
  }

  Future<void> _saveGeneral() async {
    setState(() => _saving = true);
    try {
      await ProjectService.updateProject(
        widget.workspaceSlug,
        widget.project.id,
        {
          'name': _nameController.text.trim(),
          'description': _descController.text.trim(),
          'network': _network,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Project updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    setState(() => _saving = false);
  }

  // ---------------------------------------------------------------------------
  //  Members
  //
  //  Nothing below decides for itself who may do what — every control is built
  //  only when [_permissions] says the server would accept it. The rules and
  //  where they were read from live in lib/models/member_permissions.dart.
  // ---------------------------------------------------------------------------

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Add a workspace member to the project.
  ///
  /// The candidate list is fetched here rather than with the screen because it
  /// is only needed by an admin who taps this, and it must be current: a person
  /// invited to the workspace five minutes ago should appear without a reload.
  Future<void> _addMember() async {
    List<Membership> workspaceMembers;
    try {
      workspaceMembers =
          await WorkspaceService.getWorkspaceMemberships(widget.workspaceSlug);
    } on DioException catch (e) {
      _report(
          describeApiError(e, fallback: 'Could not load workspace members'));
      return;
    }
    if (!mounted) return;

    final already = _members.map((m) => m.member.id).toSet();
    final candidates = workspaceMembers
        .where((m) => !already.contains(m.member.id))
        .toList()
      ..sort((a, b) =>
          a.member.label.toLowerCase().compareTo(b.member.label.toLowerCase()));

    if (candidates.isEmpty) {
      _report('Everyone in this workspace is already in the project');
      return;
    }

    final chosen = await showModalBottomSheet<Membership>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Add a workspace member',
                    style: theme.textTheme.titleMedium),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (_, i) {
                    final c = candidates[i];
                    return ListTile(
                      title: Text(c.member.label,
                          style: theme.textTheme.bodyLarge),
                      subtitle: Text(
                        c.member.email.isEmpty
                            ? '${MemberRole.label(c.role)} in this workspace'
                            : c.member.email,
                        style: theme.textTheme.bodySmall,
                      ),
                      onTap: () => Navigator.pop(ctx, c),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (chosen == null || !mounted) return;

    // A workspace admin can only be a project admin and a workspace guest can
    // only be a project guest — the server rejects the whole batch otherwise —
    // so those two are added at their one legal role without asking.
    final allowed = MemberPermissions.addableProjectRoles(chosen.role);
    if (allowed.isEmpty) {
      _report('${chosen.member.label} is not an active workspace member');
      return;
    }
    int role = allowed.first;
    if (allowed.length > 1) {
      final picked = await showRolePicker(
        context,
        title: 'Role for ${chosen.member.label}',
        allowed: allowed,
        current: chosen.role,
      );
      if (picked == null) return;
      role = picked;
    }

    try {
      await MemberService.addMembers(
        widget.workspaceSlug,
        widget.project.id,
        {chosen.member.id: role},
      );
      _report('${chosen.member.label} added as ${MemberRole.label(role)}');
      await _reloadMembers();
    } catch (e) {
      _report(describeApiError(e, fallback: 'Could not add member'));
    }
  }

  Future<void> _changeRole(Membership target) async {
    final allowed = _permissions.assignableProjectRoles(target);
    if (allowed.isEmpty) return;
    final picked = await showRolePicker(
      context,
      title: 'Role for ${target.member.label}',
      allowed: allowed,
      current: target.role,
    );
    if (picked == null || picked == target.role) return;
    try {
      await MemberService.updateRole(
        widget.workspaceSlug,
        widget.project.id,
        target.id,
        picked,
      );
      _report('${target.member.label} is now ${MemberRole.label(picked)}');
      await _reloadMembers();
    } catch (e) {
      _report(describeApiError(e, fallback: 'Could not change role'));
    }
  }

  Future<void> _removeMember(Membership target) async {
    final ok = await confirmMemberAction(
      context,
      title: 'Remove ${target.member.label}?',
      message: '${target.member.label} loses access to ${widget.project.name}. '
          'Work items they created or were assigned stay where they are.',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    try {
      await MemberService.removeMember(
          widget.workspaceSlug, widget.project.id, target.id);
      _report('${target.member.label} removed from the project');
      await _reloadMembers();
    } catch (e) {
      _report(describeApiError(e, fallback: 'Could not remove member'));
    }
  }

  Future<void> _leaveProject() async {
    final ok = await confirmMemberAction(
      context,
      title: 'Leave ${widget.project.name}?',
      message: 'You lose access to this project. An admin has to add you back.',
      confirmLabel: 'Leave',
    );
    if (!ok) return;
    try {
      await MemberService.leave(widget.workspaceSlug, widget.project.id);
      if (!mounted) return;
      // Nothing on this screen is readable to a non-member any more, so it
      // closes rather than reloading into a wall of permission errors.
      Navigator.of(context).pop();
    } catch (e) {
      _report(describeApiError(e, fallback: 'Could not leave the project'));
    }
  }

  /// The overflow actions for one member's row.
  List<MemberAction> _memberActions(Membership m) {
    final isSelf = _permissions.isSelf(m);
    return [
      if (_permissions.canChangeProjectRole(m))
        MemberAction(
          label: 'Change role',
          icon: Icons.badge_outlined,
          onSelected: () => _changeRole(m),
        ),
      if (_permissions.canRemoveProjectMember(m))
        MemberAction(
          label: 'Remove from project',
          icon: Icons.person_remove_outlined,
          destructive: true,
          onSelected: () => _removeMember(m),
        ),
      // Leaving is a different route from being removed, and the server
      // refuses it for the project's last admin — so it is only offered when
      // the member list on screen already shows another one.
      if (isSelf && _permissions.canLeaveProject(_members))
        MemberAction(
          label: 'Leave project',
          icon: Icons.logout,
          destructive: true,
          onSelected: _leaveProject,
        ),
    ];
  }

  Future<void> _addState() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        final nameCtrl = TextEditingController();
        String group = 'backlog';
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Add State'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                M3ETextField(
                  label: 'State name',
                  controller: nameCtrl,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: group,
                  // The dropdown is not an M3ETextField, so it restates the
                  // same outline rather than falling back to the stock one.
                  decoration: InputDecoration(
                    labelText: 'Group',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(M3EShape.large),
                      borderSide: BorderSide(
                          color: Theme.of(ctx).colorScheme.outlineVariant,
                          width: 0.8),
                    ),
                  ),
                  items: [
                    'backlog',
                    'unstarted',
                    'started',
                    'completed',
                    'cancelled'
                  ]
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => group = v);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(
                      ctx, {'name': nameCtrl.text.trim(), 'group': group}),
                  child: const Text('Add')),
            ],
          ),
        );
      },
    );
    if (result != null && result['name']!.isNotEmpty) {
      try {
        await IssueService.createState(
          widget.workspaceSlug,
          widget.project.id,
          {
            'name': result['name'],
            'group': result['group'],
            'color': '#6B7280',
          },
        );
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _deleteState(IssueState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete State'),
        content: Text('Delete "${state.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await IssueService.deleteState(
            widget.workspaceSlug, widget.project.id, state.id);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _addLabel() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        final nameCtrl = TextEditingController();
        String color = '#6B7280';
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Add Label'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                M3ETextField(
                  label: 'Label name',
                  controller: nameCtrl,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '#EF4444',
                    '#F97316',
                    '#EAB308',
                    '#22C55E',
                    '#3B82F6',
                    '#8B5CF6',
                    '#EC4899',
                    '#6B7280',
                  ].map((c) {
                    // A bare colour circle carries no text, so the swatch is
                    // anonymous to a screen reader and to `uiautomator dump`
                    // unless it is named here.
                    return Semantics(
                      label: 'Label colour ${_colorName(c)}',
                      button: true,
                      selected: color == c,
                      container: true,
                      child: GestureDetector(
                        onTap: () => setDialogState(() => color = c),
                        // 32dp circle, 48dp target: a swatch is a control.
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _parseColor(c),
                                shape: BoxShape.circle,
                                border: color == c
                                    ? Border.all(
                                        color:
                                            Theme.of(ctx).colorScheme.onSurface,
                                        width: 2)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(
                      ctx, {'name': nameCtrl.text.trim(), 'color': color}),
                  child: const Text('Add')),
            ],
          ),
        );
      },
    );
    if (result != null && result['name']!.isNotEmpty) {
      try {
        await LabelService.createLabel(
          widget.workspaceSlug,
          widget.project.id,
          {'name': result['name'], 'color': result['color']},
        );
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _deleteLabel(Label label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Label'),
        content: Text('Delete "${label.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await LabelService.deleteLabel(
            widget.workspaceSlug, widget.project.id, label.id);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  /// Human names for the label swatch palette, so the colour picker exposes
  /// something a screen reader or an automation script can address.
  static const _swatchNames = {
    '#EF4444': 'Red',
    '#F97316': 'Orange',
    '#EAB308': 'Yellow',
    '#22C55E': 'Green',
    '#3B82F6': 'Blue',
    '#8B5CF6': 'Purple',
    '#EC4899': 'Pink',
    '#6B7280': 'Grey',
  };

  String _colorName(String hex) => _swatchNames[hex] ?? hex;

  Color _parseColor(String hex) {
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFF999999);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const M3EAppBar(title: 'Project Settings'),
      body: _loading
          ? const LoadingStateWidget()
          // Horizontal padding is applied per section rather than to the whole
          // list, because the member rows are PlaneRows and PlaneRow already
          // carries its own margin — nesting it inside a padded list would
          // indent the cards twice as far as everything above them.
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _inset([
                  // General section
                  _sectionHeader('General', theme),
                  const SizedBox(height: 12),
                  M3ETextField(
                    label: 'Project name',
                    controller: _nameController,
                  ),
                  const SizedBox(height: 12),
                  M3ETextField(
                    label: 'Description',
                    controller: _descController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(M3EShape.large),
                      border: Border.all(
                          color: theme.colorScheme.outlineVariant, width: 0.8),
                    ),
                    child: Row(
                      children: [
                        Text('Identifier: ',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        Text(widget.project.identifier,
                            style: theme.textTheme.labelLarge),
                        const Spacer(),
                        Text('(read-only)', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Network: ',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Secret'),
                        selected: _network == 0,
                        onSelected: (_) => setState(() => _network = 0),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Public'),
                        selected: _network == 2,
                        onSelected: (_) => setState(() => _network = 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _saveGeneral,
                      child: _saving
                          ? const M3ELoadingIndicator(size: 16)
                          : const Text('Save Changes'),
                    ),
                  ),
                ]),

                // Members section
                const SizedBox(height: 28),
                _inset([
                  Row(
                    children: [
                      _sectionHeader('Members (${_members.length})', theme),
                      const Spacer(),
                      if (_permissions.canAddProjectMembers)
                        M3EIconButton(
                          icon: Icons.person_add_alt,
                          tooltip: 'Add member',
                          size: M3EIconButtonSize.small,
                          onPressed: _addMember,
                        ),
                    ],
                  ),
                ]),
                const SizedBox(height: 8),
                ..._members.map((m) => MemberRow(
                      member: m.member,
                      role: m.role,
                      isSelf: _permissions.isSelf(m),
                      actions: _memberActions(m),
                    )),

                _inset([
                  // States section
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      _sectionHeader('States (${_states.length})', theme),
                      const Spacer(),
                      M3EIconButton(
                        icon: Icons.add,
                        tooltip: 'Add state',
                        size: M3EIconButtonSize.small,
                        onPressed: _addState,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._states.map((s) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          PlaneTheme.stateIcon(s.group),
                          color: PlaneTheme.stateGroupColor(context, s.group),
                          size: 20,
                        ),
                        title: Text(s.name, style: theme.textTheme.bodyMedium),
                        subtitle:
                            Text(s.group, style: theme.textTheme.bodySmall),
                        // Named per state so repeated rows stay distinguishable
                        // to external automation.
                        trailing: M3EIconButton(
                          icon: Icons.delete_outline,
                          tooltip: 'Delete state ${s.name}',
                          size: M3EIconButtonSize.small,
                          color: theme.colorScheme.onSurfaceVariant,
                          onPressed: () => _deleteState(s),
                        ),
                      )),

                  // Labels section
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      _sectionHeader('Labels (${_labels.length})', theme),
                      const Spacer(),
                      M3EIconButton(
                        icon: Icons.add,
                        tooltip: 'Add label',
                        size: M3EIconButtonSize.small,
                        onPressed: _addLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _labels.map((l) {
                      return Chip(
                        avatar: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _parseColor(l.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        label: Text(l.name, style: theme.textTheme.labelMedium),
                        deleteIcon: Icon(Icons.close,
                            size: 16, semanticLabel: 'Delete label ${l.name}'),
                        deleteButtonTooltipMessage: 'Delete label',
                        onDeleted: () => _deleteLabel(l),
                      );
                    }).toList(),
                  ),

                  // Integrations section
                  const SizedBox(height: 28),
                  _sectionHeader('Integrations', theme),
                  const SizedBox(height: 8),
                  if (_githubRepos.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Set up integrations in the web app',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._githubRepos.map((repo) {
                      final name = repo['repo_detail']?['name'] ??
                          repo['name'] ??
                          'Unknown repo';
                      final owner =
                          repo['repo_detail']?['owner'] ?? repo['owner'] ?? '';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.code, size: 20),
                        title: Text(name.toString(),
                            style: theme.textTheme.bodyMedium),
                        subtitle: owner.toString().isNotEmpty
                            ? Text(owner.toString(),
                                style: theme.textTheme.bodySmall)
                            : null,
                      );
                    }),

                  // Features section
                  const SizedBox(height: 28),
                  _sectionHeader('Features', theme),
                  const SizedBox(height: 8),
                  _featureRow('Cycles', true, theme),
                  _featureRow('Modules', true, theme),
                  _featureRow('Views', true, theme),
                  _featureRow('Pages', true, theme),

                  const SizedBox(height: 40),
                ]),
              ],
            ),
    );
  }

  /// Standard page margin, for the sections that are not full-bleed rows.
  Widget _inset(List<Widget> children) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      );

  Widget _sectionHeader(String title, ThemeData theme) {
    return Text(title, style: theme.textTheme.titleMedium);
  }

  Widget _featureRow(String name, bool enabled, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: enabled ? PlaneTheme.completed : PlaneTheme.cancelled,
          ),
          const SizedBox(width: 10),
          Text(name, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(enabled ? 'Enabled' : 'Disabled',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
