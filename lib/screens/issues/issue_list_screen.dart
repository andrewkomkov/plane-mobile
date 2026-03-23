import 'package:flutter/material.dart';
import '../../services/issue_service.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import 'issue_detail_screen.dart';
import 'issue_create_screen.dart';

class IssueListScreen extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final String projectIdentifier;

  const IssueListScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.projectIdentifier,
  });

  @override
  State<IssueListScreen> createState() => _IssueListScreenState();
}

class _IssueListScreenState extends State<IssueListScreen>
    with AutomaticKeepAliveClientMixin {
  List<Issue> _issues = [];
  Map<String, IssueState> _states = {};
  bool _loading = true;
  String? _error;
  String? _filterState;
  String? _filterPriority;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final states = await IssueService.getStates(widget.workspaceSlug, widget.projectId);
      final result = await IssueService.getIssues(widget.workspaceSlug, widget.projectId);
      setState(() {
        _states = {for (var s in states) s.id: s};
        _issues = result['issues'] as List<Issue>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Issue> get _filteredIssues {
    return _issues.where((i) {
      if (_filterState != null && i.state != _filterState) return false;
      if (_filterPriority != null && i.priority != _filterPriority) return false;
      return true;
    }).toList();
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filterState = null;
                      _filterPriority = null;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _filterState,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ..._states.values.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
              ],
              onChanged: (v) => setState(() => _filterState = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _filterPriority,
              decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...['urgent', 'high', 'medium', 'low', 'none']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p))),
              ],
              onChanged: (v) => setState(() => _filterPriority = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final filtered = _filteredIssues;
    final hasFilters = _filterState != null || _filterPriority != null;

    return Scaffold(
      body: Column(
        children: [
          // Filter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Text('${filtered.length} issues',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const Spacer(),
                FilterChip(
                  label: Text(hasFilters ? 'Filtered' : 'Filter'),
                  selected: hasFilters,
                  onSelected: (_) => _showFilters(),
                  avatar: const Icon(Icons.filter_list, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: filtered.isEmpty
                  ? const Center(child: Text('No issues'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) => _IssueRow(
                        issue: filtered[i],
                        state: _states[filtered[i].state],
                        identifier: widget.projectIdentifier,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => IssueDetailScreen(
                                workspaceSlug: widget.workspaceSlug,
                                projectId: widget.projectId,
                                issueId: filtered[i].id,
                                states: _states,
                              ),
                            ),
                          );
                          _load();
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'create_issue',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IssueCreateScreen(
                workspaceSlug: widget.workspaceSlug,
                projectId: widget.projectId,
                states: _states,
              ),
            ),
          );
          _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  final Issue issue;
  final IssueState? state;
  final String identifier;
  final VoidCallback onTap;

  const _IssueRow({
    required this.issue,
    this.state,
    required this.identifier,
    required this.onTap,
  });

  Color _priorityColor(String p) {
    switch (p) {
      case 'urgent': return Colors.red;
      case 'high': return Colors.orange;
      case 'medium': return Colors.amber;
      case 'low': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: _priorityColor(issue.priority),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            if (state != null)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _parseColor(state!.color),
                  shape: BoxShape.circle,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(issue.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('$identifier-${issue.sequenceId}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
