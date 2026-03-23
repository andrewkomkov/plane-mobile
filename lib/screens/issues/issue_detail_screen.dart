import 'package:flutter/material.dart';
import '../../services/issue_service.dart';
import '../../services/comment_service.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../models/comment.dart';

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
  List<Comment> _comments = [];
  bool _loading = true;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        IssueService.getIssue(widget.workspaceSlug, widget.projectId, widget.issueId),
        CommentService.getComments(widget.workspaceSlug, widget.projectId, widget.issueId),
      ]);
      setState(() {
        _issue = results[0] as Issue;
        _comments = results[1] as List<Comment>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateField(Map<String, dynamic> data) async {
    await IssueService.updateIssue(
        widget.workspaceSlug, widget.projectId, widget.issueId, data);
    _load();
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    await CommentService.addComment(
        widget.workspaceSlug, widget.projectId, widget.issueId, '<p>$text</p>');
    _commentController.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
          appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final issue = _issue!;
    final state = widget.states[issue.state];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('#${issue.sequenceId}')),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(issue.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // Status & Priority chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChip(state?.name ?? '?', _parseColor(state?.color ?? '#999')),
                        _buildChip(issue.priority, _priorityColor(issue.priority)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Status dropdown
                    DropdownButtonFormField<String>(
                      value: issue.state,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: widget.states.values
                          .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) _updateField({'state': v});
                      },
                    ),
                    const SizedBox(height: 12),

                    // Priority dropdown
                    DropdownButtonFormField<String>(
                      value: issue.priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: ['urgent', 'high', 'medium', 'low', 'none']
                          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) _updateField({'priority': v});
                      },
                    ),
                    const SizedBox(height: 20),

                    // Description
                    if (issue.descriptionHtml != null && issue.descriptionHtml!.isNotEmpty) ...[
                      Text('Description',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_stripHtml(issue.descriptionHtml!)),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Comments
                    Text('Comments (${_comments.length})',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    if (_comments.isEmpty)
                      Text('No comments yet', style: TextStyle(color: Colors.grey[400], fontSize: 13))
                    else
                      ..._comments.map((c) => _CommentCard(comment: c)),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),

          // Comment input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add comment...',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addComment,
                  icon: const Icon(Icons.send),
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 5),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }

  String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

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
}

class _CommentCard extends StatelessWidget {
  final Comment comment;
  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(comment.actorDetail ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Text(_timeAgo(comment.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            comment.commentHtml?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
