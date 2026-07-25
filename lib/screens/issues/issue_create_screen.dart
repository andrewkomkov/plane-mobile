import 'package:flutter/material.dart';
import '../../config/m3e/shapes.dart';
import '../../config/m3e/motion.dart';
import '../../config/m3e/typography.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/loading_indicator.dart';
import '../../widgets/m3e/text_field.dart';
import '../../config/theme.dart';
import '../../services/issue_service.dart';
import '../../models/state.dart';

class IssueCreateScreen extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final Map<String, IssueState> states;
  final String? parentIssueId;

  const IssueCreateScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.states,
    this.parentIssueId,
  });

  @override
  State<IssueCreateScreen> createState() => _IssueCreateScreenState();
}

class _IssueCreateScreenState extends State<IssueCreateScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedState;
  String _selectedPriority = 'medium';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final defaultState = widget.states.values
        .where((s) => s.group == 'unstarted')
        .firstOrNull;
    _selectedState = defaultState?.id ?? widget.states.values.firstOrNull?.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final desc = _descController.text.trim();
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        if (desc.isNotEmpty) 'description_html': '<p>$desc</p>',
        if (_selectedState != null) 'state': _selectedState,
        'priority': _selectedPriority,
        if (widget.parentIssueId != null) 'parent': widget.parentIssueId,
      };
      await IssueService.createIssue(
        widget.workspaceSlug,
        widget.projectId,
        data,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  IssueState? get _currentState =>
      _selectedState != null ? widget.states[_selectedState] : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hintColor = scheme.onSurfaceVariant.withValues(alpha: 0.6);
    final isSubIssue = widget.parentIssueId != null;
    final screenTitle = isSubIssue ? 'New Sub-issue' : 'New Issue';

    return Scaffold(
      appBar: M3EAppBar(
        title: screenTitle,
        leading: M3EAppBarAction(
          icon: Icons.close,
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 10),
            child: _saving
                ? const M3ELoadingIndicator(size: 22)
                : M3EPressable(
                    pressedScale: 0.92,
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(M3EShape.full),
                      ),
                      child: Text(
                        'Create',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            M3ETextField(
              label: 'Issue title',
              controller: _nameController,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            // Six lines of outlined box: the field always claimed this much
            // height, it just had no border, so the space read as a gap
            // between the title and the hint below rather than as the field.
            M3ETextField(
              label: 'Description',
              hint: 'Add description...',
              controller: _descController,
              maxLines: 6,
            ),
            const SizedBox(height: 8),
            // Markdown hint
            Row(
              children: [
                Icon(Icons.code, size: 14, color: hintColor),
                const SizedBox(width: 6),
                Text(
                  'MARKDOWN SUPPORTED',
                  style: M3EType.overline(hintColor),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Status & Priority row
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showStatePicker(),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(M3EShape.large),
                        // Same outline as the fields above — these are inputs
                        // too, they just open a sheet instead of a keyboard.
                        border: Border.all(
                            color: scheme.outlineVariant, width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STATUS',
                            style: M3EType.overline(scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentState != null
                                      ? PlaneTheme.stateGroupColor(context, _currentState!.group)
                                      : PlaneTheme.backlog,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentState?.name ?? 'Backlog',
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                              Icon(Icons.expand_more,
                                  size: 18,
                                  color: scheme.onSurfaceVariant),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showPriorityPicker(),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(M3EShape.large),
                        border: Border.all(
                            color: scheme.outlineVariant, width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRIORITY',
                            style: M3EType.overline(scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                PlaneTheme.priorityIcon(_selectedPriority),
                                size: 16,
                                color: PlaneTheme.priorityColor(context, _selectedPriority),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedPriority[0].toUpperCase() +
                                      _selectedPriority.substring(1),
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                              Icon(Icons.expand_more,
                                  size: 18,
                                  color: scheme.onSurfaceVariant),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStatePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Status',
                  style: Theme.of(ctx).textTheme.titleLarge),
            ),
            ...widget.states.values.map((s) => ListTile(
                  leading: Icon(
                    PlaneTheme.stateIcon(s.group),
                    size: 18,
                    color: PlaneTheme.stateGroupColor(context, s.group),
                  ),
                  title: Text(s.name,
                      style: Theme.of(ctx).textTheme.bodyMedium),
                  trailing: _selectedState == s.id
                      ? const Icon(Icons.check, size: 18)
                      : null,
                  onTap: () {
                    setState(() => _selectedState = s.id);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showPriorityPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Priority',
                  style: Theme.of(ctx).textTheme.titleLarge),
            ),
            ...['urgent', 'high', 'medium', 'low', 'none'].map((p) => ListTile(
                  leading: Icon(
                    PlaneTheme.priorityIcon(p),
                    size: 18,
                    color: PlaneTheme.priorityColor(context, p),
                  ),
                  title: Text(p[0].toUpperCase() + p.substring(1),
                      style: Theme.of(ctx).textTheme.bodyMedium),
                  trailing: _selectedPriority == p
                      ? const Icon(Icons.check, size: 18)
                      : null,
                  onTap: () {
                    setState(() => _selectedPriority = p);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }
}
