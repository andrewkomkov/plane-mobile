import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/project.dart';
import '../../models/state.dart';
import '../../models/label.dart';
import '../../models/member.dart';
import '../../services/project_service.dart';
import '../../services/issue_service.dart';
import '../../services/label_service.dart';
import '../../services/member_service.dart';
import '../../services/integration_service.dart';
import '../../widgets/loading_state.dart';

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

class _ProjectSettingsScreenState
    extends ConsumerState<ProjectSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  int _network = 0;
  bool _saving = false;

  List<IssueState> _states = [];
  List<Label> _labels = [];
  List<Member> _members = [];
  List<Map<String, dynamic>> _projectMembers = [];
  List<Map<String, dynamic>> _githubRepos = [];
  bool _loading = true;

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
      final results = await Future.wait([
        IssueService.getStates(widget.workspaceSlug, widget.project.id),
        LabelService.getLabels(widget.workspaceSlug, widget.project.id),
        MemberService.getMembers(widget.workspaceSlug, widget.project.id),
        ProjectService.getProjectMembers(
            widget.workspaceSlug, widget.project.id),
        IntegrationService.getGitHubRepositories(
            widget.workspaceSlug, widget.project.id),
      ]);
      setState(() {
        _states = results[0] as List<IssueState>;
        _labels = results[1] as List<Label>;
        _members = results[2] as List<Member>;
        _projectMembers = results[3] as List<Map<String, dynamic>>;
        _githubRepos = results[4] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    setState(() => _saving = false);
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
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'State name',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: group,
                  decoration: const InputDecoration(
                    labelText: 'Group',
                    border: OutlineInputBorder(),
                  ),
                  items: ['backlog', 'unstarted', 'started', 'completed', 'cancelled']
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
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Label name',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '#EF4444', '#F97316', '#EAB308', '#22C55E',
                    '#3B82F6', '#8B5CF6', '#EC4899', '#6B7280',
                  ].map((c) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => color = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _parseColor(c),
                          shape: BoxShape.circle,
                          border: color == c
                              ? Border.all(
                                  color: Theme.of(ctx).colorScheme.onSurface,
                                  width: 2)
                              : null,
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

  Color _parseColor(String hex) {
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFF999999);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Project Settings')),
      body: _loading
          ? const LoadingStateWidget()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // General section
                _sectionHeader('General', theme),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Project name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: theme.colorScheme.outline, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Text('Identifier: ',
                          style: TextStyle(
                              fontSize: 14,
                              color:
                                  theme.colorScheme.onSurfaceVariant)),
                      Text(widget.project.identifier,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text('(read-only)',
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Network: ',
                        style: TextStyle(
                            fontSize: 14,
                            color:
                                theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Secret'),
                      selected: _network == 0,
                      onSelected: (_) =>
                          setState(() => _network = 0),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Public'),
                      selected: _network == 2,
                      onSelected: (_) =>
                          setState(() => _network = 2),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _saveGeneral,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Text('Save Changes'),
                  ),
                ),

                // Members section
                const SizedBox(height: 28),
                _sectionHeader('Members (${_members.length})', theme),
                const SizedBox(height: 8),
                ..._members.map((m) {
                  final pm = _projectMembers.firstWhere(
                    (pm) =>
                        pm['member']?['id'] == m.id ||
                        pm['id'] == m.id,
                    orElse: () => {},
                  );
                  final role = _roleLabel(pm['role'] ?? 0);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.primary
                          .withValues(alpha: 0.2),
                      child: Text(
                        (m.displayName.isNotEmpty ? m.displayName : '?')[0]
                            .toUpperCase(),
                        style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.primary),
                      ),
                    ),
                    title: Text(m.displayName,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(m.email,
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                theme.colorScheme.onSurfaceVariant)),
                    trailing: Text(role,
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                theme.colorScheme.onSurfaceVariant)),
                  );
                }),

                // States section
                const SizedBox(height: 28),
                Row(
                  children: [
                    _sectionHeader('States (${_states.length})', theme),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: _addState,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._states.map((s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        PlaneTheme.stateIcon(s.group),
                        color: PlaneTheme.stateGroupColor(s.group),
                        size: 20,
                      ),
                      title: Text(s.name,
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(s.group,
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  theme.colorScheme.onSurfaceVariant)),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: Colors.grey[500]),
                        onPressed: () => _deleteState(s),
                      ),
                    )),

                // Labels section
                const SizedBox(height: 28),
                Row(
                  children: [
                    _sectionHeader('Labels (${_labels.length})', theme),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
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
                      label: Text(l.name,
                          style: const TextStyle(fontSize: 13)),
                      deleteIcon:
                          const Icon(Icons.close, size: 16),
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
                            style: TextStyle(
                                fontSize: 13,
                                color:
                                    theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._githubRepos.map((repo) {
                    final name =
                        repo['repo_detail']?['name'] ?? repo['name'] ?? 'Unknown repo';
                    final owner =
                        repo['repo_detail']?['owner'] ?? repo['owner'] ?? '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.code, size: 20),
                      title: Text(name.toString(),
                          style: const TextStyle(fontSize: 14)),
                      subtitle: owner.toString().isNotEmpty
                          ? Text(owner.toString(),
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      theme.colorScheme.onSurfaceVariant))
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
              ],
            ),
    );
  }

  Widget _sectionHeader(String title, ThemeData theme) {
    return Text(title,
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface));
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
          Text(name, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(enabled ? 'Enabled' : 'Disabled',
              style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  String _roleLabel(dynamic role) {
    switch (role) {
      case 20:
        return 'Admin';
      case 15:
        return 'Member';
      case 10:
        return 'Viewer';
      case 5:
        return 'Guest';
      default:
        return 'Member';
    }
  }
}
