import 'package:flutter/material.dart';
import '../../services/issue_service.dart';
import '../../models/state.dart';

class IssueCreateScreen extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final Map<String, IssueState> states;

  const IssueCreateScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.states,
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
      await IssueService.createIssue(
        widget.workspaceSlug,
        widget.projectId,
        {
          'name': _nameController.text.trim(),
          if (desc.isNotEmpty) 'description_html': '<p>$desc</p>',
          if (_selectedState != null) 'state': _selectedState,
          'priority': _selectedPriority,
        },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Issue'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedState,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: widget.states.values
                        .map((s) => DropdownMenuItem(
                            value: s.id, child: Text(s.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedState = v),
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPriority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: ['urgent', 'high', 'medium', 'low', 'none']
                        .map((p) =>
                            DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedPriority = v ?? 'medium'),
                    isExpanded: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
