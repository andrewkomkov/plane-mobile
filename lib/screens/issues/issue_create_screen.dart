import 'package:flutter/material.dart';
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
    final isSubIssue = widget.parentIssueId != null;
    final screenTitle = isSubIssue ? 'New Sub-issue' : 'New Issue';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: PlaneTheme.background.withValues(alpha: 0.80),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22, color: PlaneTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          screenTitle,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: PlaneTheme.onSurface,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _saving
                ? const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : GestureDetector(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: PlaneTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: PlaneTheme.primaryContainer
                                .withValues(alpha: 0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Create',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PlaneTheme.onPrimaryContainer,
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
            // Title field
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: PlaneTheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Issue title',
                hintStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 8),
            // Description field
            TextField(
              controller: _descController,
              maxLines: 6,
              style: const TextStyle(
                fontSize: 16,
                color: PlaneTheme.onSurfaceVariant,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'Add description...',
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            // Markdown hint
            Row(
              children: [
                Icon(Icons.code, size: 14,
                    color: Colors.white.withValues(alpha: 0.25)),
                const SizedBox(width: 6),
                Text(
                  'MARKDOWN SUPPORTED',
                  style: TextStyle(
                    fontSize: PlaneTheme.fontSmall,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2.0,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Status & Priority row
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showStatePicker(),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: PlaneTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STATUS',
                            style: TextStyle(
                              fontSize: PlaneTheme.fontSmall,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2.0,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
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
                                      ? PlaneTheme.stateGroupColor(
                                          _currentState!.group)
                                      : PlaneTheme.backlog,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentState?.name ?? 'Backlog',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: PlaneTheme.onSurface,
                                  ),
                                ),
                              ),
                              Icon(Icons.expand_more,
                                  size: 18,
                                  color: Colors.white.withValues(alpha: 0.30)),
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
                        color: PlaneTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRIORITY',
                            style: TextStyle(
                              fontSize: PlaneTheme.fontSmall,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2.0,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                PlaneTheme.priorityIcon(_selectedPriority),
                                size: 16,
                                color: PlaneTheme.priorityColor(
                                    _selectedPriority),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedPriority[0].toUpperCase() +
                                      _selectedPriority.substring(1),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: PlaneTheme.onSurface,
                                  ),
                                ),
                              ),
                              Icon(Icons.expand_more,
                                  size: 18,
                                  color: Colors.white.withValues(alpha: 0.30)),
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            ...widget.states.values.map((s) => ListTile(
                  leading: Icon(
                    PlaneTheme.stateIcon(s.group),
                    size: 18,
                    color: PlaneTheme.stateGroupColor(s.group),
                  ),
                  title: Text(s.name, style: const TextStyle(fontSize: 14)),
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Priority',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            ...['urgent', 'high', 'medium', 'low', 'none'].map((p) => ListTile(
                  leading: Icon(
                    PlaneTheme.priorityIcon(p),
                    size: 18,
                    color: PlaneTheme.priorityColor(p),
                  ),
                  title: Text(p[0].toUpperCase() + p.substring(1),
                      style: const TextStyle(fontSize: 14)),
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
