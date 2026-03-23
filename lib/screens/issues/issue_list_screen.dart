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
      final statesFuture = IssueService.getStates(
          widget.workspaceSlug, widget.projectId);
      final issuesFuture = IssueService.getIssues(
          widget.workspaceSlug, widget.projectId);

      final states = await statesFuture;
      final result = await issuesFuture;

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

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.amber;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
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
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: _issues.isEmpty
            ? const Center(child: Text('No issues'))
            : ListView.builder(
                itemCount: _issues.length,
                itemBuilder: (ctx, i) {
                  final issue = _issues[i];
                  final state = _states[issue.state];
                  return ListTile(
                    leading: Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _priorityColor(issue.priority),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    title: Text(
                      issue.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Row(
                      children: [
                        Text(
                          '${widget.projectIdentifier}-${issue.sequenceId}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                        if (state != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _parseColor(state.color),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(state.name,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                        ],
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IssueDetailScreen(
                            workspaceSlug: widget.workspaceSlug,
                            projectId: widget.projectId,
                            issueId: issue.id,
                            states: _states,
                          ),
                        ),
                      );
                      _load();
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
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
