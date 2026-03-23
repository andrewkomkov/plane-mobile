import 'package:flutter/material.dart';
import '../../services/issue_service.dart';
import '../../models/issue.dart';
import '../../models/state.dart';

class IssueDetailScreen extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final String issueId;
  final Map<String, IssueState> states;

  const IssueDetailScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.issueId,
    required this.states,
  });

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  Issue? _issue;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final issue = await IssueService.getIssue(
        widget.workspaceSlug,
        widget.projectId,
        widget.issueId,
      );
      setState(() {
        _issue = issue;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateState(String stateId) async {
    await IssueService.updateIssue(
      widget.workspaceSlug,
      widget.projectId,
      widget.issueId,
      {'state': stateId},
    );
    _load();
  }

  Future<void> _updatePriority(String priority) async {
    await IssueService.updateIssue(
      widget.workspaceSlug,
      widget.projectId,
      widget.issueId,
      {'priority': priority},
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final issue = _issue!;
    final state = widget.states[issue.state];

    return Scaffold(
      appBar: AppBar(
        title: Text('${issue.sequenceId}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(issue.name,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _chip('Status', state?.name ?? 'Unknown',
                    state != null ? _parseColor(state.color) : Colors.grey),
                const SizedBox(width: 8),
                _chip('Priority', issue.priority, _priorityColor(issue.priority)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _dropdown(
                    'Change status',
                    widget.states.values
                        .map((s) => DropdownMenuItem(
                            value: s.id, child: Text(s.name)))
                        .toList(),
                    issue.state,
                    _updateState,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _dropdown(
                    'Change priority',
                    ['urgent', 'high', 'medium', 'low', 'none']
                        .map((p) =>
                            DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    issue.priority,
                    _updatePriority,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (issue.descriptionHtml != null &&
                issue.descriptionHtml!.isNotEmpty) ...[
              const Text('Description',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              Text(_stripHtml(issue.descriptionHtml!)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 6),
      label: Text(value, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _dropdown(String hint, List<DropdownMenuItem<String>> items,
      String? current, Function(String) onChanged) {
    return DropdownButtonFormField<String>(
      value: current,
      decoration: InputDecoration(
        labelText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      isExpanded: true,
      style: const TextStyle(fontSize: 13, color: Colors.black87),
    );
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'urgent': return Colors.red;
      case 'high': return Colors.orange;
      case 'medium': return Colors.amber;
      case 'low': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }
}
