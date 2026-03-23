import 'package:flutter/material.dart';
import '../../config/theme.dart';
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
    await IssueService.updateIssue(widget.workspaceSlug, widget.projectId, widget.issueId, data);
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
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final issue = _issue!;
    final state = widget.states[issue.state];
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_horiz, size: 20), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Identifier
                    Text('${issue.sequenceId}',
                        style: TextStyle(fontSize: 13, color: secondary)),
                    const SizedBox(height: 8),
                    // Title
                    Text(issue.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3)),
                    const SizedBox(height: 14),
                    // Chips row
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _PropertyChip(
                          icon: PlaneTheme.stateIcon(state?.group ?? 'backlog'),
                          iconColor: PlaneTheme.stateGroupColor(state?.group ?? 'backlog'),
                          label: state?.name ?? 'Unknown',
                          onTap: () => _showStatePicker(),
                        ),
                        _PropertyChip(
                          icon: PlaneTheme.priorityIcon(issue.priority),
                          iconColor: PlaneTheme.priorityColor(issue.priority),
                          label: issue.priority[0].toUpperCase() + issue.priority.substring(1),
                          onTap: () => _showPriorityPicker(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Description
                    if (issue.descriptionHtml != null && issue.descriptionHtml!.isNotEmpty) ...[
                      Text(_stripHtml(issue.descriptionHtml!),
                          style: TextStyle(fontSize: 14, height: 1.6, color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 24),
                    ],
                    // Activity header
                    Row(
                      children: [
                        Text('Activity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: secondary)),
                        const Spacer(),
                        if (_comments.isNotEmpty)
                          Text('${_comments.length}', style: TextStyle(fontSize: 12, color: secondary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Comments
                    ..._comments.map((c) => _CommentCard(comment: c)),
                    if (_comments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('No activity yet', style: TextStyle(fontSize: 13, color: secondary)),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
          // Comment input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: theme.colorScheme.outline, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Comment',
                        hintStyle: TextStyle(color: secondary, fontSize: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                      maxLines: null,
                    ),
                  ),
                  IconButton(
                    onPressed: _addComment,
                    icon: Icon(Icons.send, size: 18, color: theme.colorScheme.primary),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStatePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.states.values.map((s) => ListTile(
            leading: Icon(PlaneTheme.stateIcon(s.group), color: PlaneTheme.stateGroupColor(s.group), size: 18),
            title: Text(s.name, style: const TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(ctx);
              _updateField({'state': s.id});
            },
          )).toList(),
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
          children: ['urgent', 'high', 'medium', 'low', 'none'].map((p) => ListTile(
            leading: Icon(PlaneTheme.priorityIcon(p), color: PlaneTheme.priorityColor(p), size: 18),
            title: Text(p[0].toUpperCase() + p.substring(1), style: const TextStyle(fontSize: 14)),
            onTap: () {
              Navigator.pop(ctx);
              _updateField({'priority': p});
            },
          )).toList(),
        ),
      ),
    );
  }

  String _stripHtml(String html) => html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}

class _PropertyChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const _PropertyChip({required this.icon, required this.iconColor, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Theme.of(context).colorScheme.outline, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final Comment comment;
  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                child: Text(
                  (comment.actorDetail ?? '?')[0].toUpperCase(),
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text(comment.actorDetail ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(width: 8),
              Text(_timeAgo(comment.createdAt),
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 4),
            child: Text(
              comment.commentHtml?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '',
              style: const TextStyle(fontSize: 14),
            ),
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
