import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/secure_storage.dart';
import '../../config/theme.dart';
import '../../services/project_service.dart';
import '../../services/module_service.dart';
import '../../services/issue_service.dart';
import '../../services/comment_service.dart';
import '../../services/label_service.dart';
import '../../services/member_service.dart';
import '../../providers/data_providers.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../models/comment.dart';
import '../../models/label.dart';
import '../../models/member.dart';
import '../../models/activity.dart';
import '../../models/attachment.dart';
import '../../models/link.dart';
import '../../utils/html_to_markdown.dart';
import '../../utils/time_ago.dart';
import '../../widgets/property_chip.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/skeleton_loader.dart';
import 'issue_create_screen.dart';

class IssueDetailScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final String issueId;
  final String projectIdentifier;
  final Map<String, IssueState> states;

  const IssueDetailScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.issueId,
    this.projectIdentifier = '',
    required this.states,
  });

  @override
  ConsumerState<IssueDetailScreen> createState() =>
      _IssueDetailScreenState();
}

class _IssueDetailScreenState extends ConsumerState<IssueDetailScreen> {
  Issue? _issue;
  List<Comment> _comments = [];
  List<Label> _allLabels = [];
  List<Member> _allMembers = [];
  List<Issue> _subIssues = [];
  List<Map<String, dynamic>> _relations = [];
  List<Activity> _activities = [];
  List<Attachment> _attachments = [];
  String? _moduleName;
  String? _cycleName;
  List<IssueLink> _links = [];
  bool _loading = true;
  String? _error;
  String _projectIdentifier = '';
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
    // Only show spinner on first load, not on refresh
    if (_issue == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      // Resolve project identifier from cache (no API call)
      if (widget.projectIdentifier.isNotEmpty) {
        _projectIdentifier = widget.projectIdentifier;
      } else {
        final cache = ref.read(dataCacheProvider);
        final projects = cache.getProjects(widget.workspaceSlug);
        if (projects != null) {
          for (final p in projects) {
            if (p.id == widget.projectId) {
              _projectIdentifier = p.identifier;
              break;
            }
          }
        }
      }

      // Load issue
      final issue = await IssueService.getIssue(
          widget.workspaceSlug, widget.projectId, widget.issueId);
      if (!mounted) return;
      setState(() {
        _issue = issue;
        _loading = false;
      });

      // Lazy load the rest in background
      _lazyLoad();
    } catch (e) {
      setState(() {
        _error = 'Could not load issue';
        _loading = false;
      });
    }
  }

  Future<void> _lazyLoad() async {
    final ws = widget.workspaceSlug;
    final pid = widget.projectId;
    final iid = widget.issueId;
    final cache = ref.read(dataCacheProvider);

    _comments = await _tryLoad(() => CommentService.getComments(ws, pid, iid), <Comment>[]);
    if (mounted) setState(() {});

    // Use shared cache for labels and members (avoids duplicate API calls)
    await cache.loadLabels(ws, pid);
    await cache.loadMembers(ws, pid);
    _allLabels = cache.getLabels(ws, pid) ?? [];
    _allMembers = cache.getMembers(ws, pid) ?? [];
    if (mounted) setState(() {});

    _activities = await _tryLoad(() => IssueService.getActivities(ws, pid, iid), <Activity>[]);
    if (mounted) setState(() {});

    _subIssues = await _tryLoad(() => IssueService.getSubIssues(ws, pid, iid), <Issue>[]);
    _relations = await _tryLoad(() => IssueService.getIssueRelations(ws, pid, iid), <Map<String, dynamic>>[]);
    _attachments = await _tryLoad(() => IssueService.getAttachments(ws, pid, iid), <Attachment>[]);
    _links = await _tryLoad(() => IssueService.getLinks(ws, pid, iid), <IssueLink>[]);

    // Module + cycle name via proxy (single SQL query, no N+1)
    try {
      final baseUrl = await SecureStorage.getBaseUrl() ?? '';
      final apiKey = await SecureStorage.getApiKey() ?? '';
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {'X-Api-Key': apiKey},
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final resp = await dio.get('/auth/mobile/issue-info/$pid/$iid');
      if (resp.data != null) {
        _moduleName = resp.data['module_name'];
        _cycleName = resp.data['cycle_name'];
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<T> _tryLoad<T>(Future<T> Function() fn, T fallback) async {
    try {
      return await fn();
    } catch (_) {
      return fallback;
    }
  }

  String _timeAgoFromDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  Future<void> _updateField(Map<String, dynamic> data) async {
    // Optimistic: refresh only the issue itself, not everything
    await IssueService.updateIssue(
        widget.workspaceSlug, widget.projectId, widget.issueId, data);
    try {
      final updated = await IssueService.getIssue(
          widget.workspaceSlug, widget.projectId, widget.issueId);
      if (mounted) setState(() => _issue = updated);
    } catch (_) {}
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    await CommentService.addComment(
        widget.workspaceSlug, widget.projectId, widget.issueId, '<p>$text</p>');
    _commentController.clear();
    _load();
  }

  Future<void> _deleteIssue() async {
    try {
      await IssueService.deleteIssue(
          widget.workspaceSlug, widget.projectId, widget.issueId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _addSubIssue() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IssueCreateScreen(
          workspaceSlug: widget.workspaceSlug,
          projectId: widget.projectId,
          states: widget.states,
          parentIssueId: widget.issueId,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const IssueDetailSkeleton(),
      );
    }
    if (_error != null || _issue == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorStateWidget(
          message: 'Failed to load issue',
          onRetry: _load,
        ),
      );
    }
    final issue = _issue!;
    final state = widget.states[issue.state];
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    // Resolve labels and members for this issue
    final issueLabels =
        _allLabels.where((l) => issue.labels.contains(l.id)).toList();
    final issueMembers =
        _allMembers.where((m) => issue.assignees.contains(m.id)).toList();

    // Merge activities and comments, sorted by date
    final activityItems = _buildActivityItems();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: PlaneTheme.background.withValues(alpha: 0.80),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22, color: PlaneTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Plane',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: PlaneTheme.primaryContainer,
          ),
        ),
        actions: [
          IconButton(
              icon: Icon(Icons.edit_square, size: 20, color: PlaneTheme.primaryContainer),
              onPressed: () {}),
          IconButton(
              icon: Icon(Icons.share_outlined, size: 20, color: PlaneTheme.onSurfaceVariant),
              onPressed: () => _shareIssue(issue)),
          IconButton(
              icon: Icon(Icons.more_horiz, size: 20, color: PlaneTheme.onSurfaceVariant),
              onPressed: () => _showMoreMenu()),
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
                    const SizedBox(height: 8),
                    // Identifier + created time
                    Row(
                      children: [
                        Text(
                          _projectIdentifier.isNotEmpty
                              ? '$_projectIdentifier-${issue.sequenceId}'
                              : '${issue.sequenceId}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                            color: PlaneTheme.onSurfaceVariant,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: PlaneTheme.outlineVariant,
                          ),
                        ),
                        Text(
                          'Created ${_timeAgoFromDate(issue.createdAt)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: PlaneTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Title
                    Text(issue.name,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            height: 1.3,
                            color: PlaneTheme.onSurface)),
                    const SizedBox(height: 20),
                    // Chips row
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        PropertyChip(
                          icon: PlaneTheme.stateIcon(
                              state?.group ?? 'backlog'),
                          iconColor: PlaneTheme.stateGroupColor(
                              state?.group ?? 'backlog'),
                          label: state?.name ?? 'Unknown',
                          onTap: () => _showStatePicker(),
                        ),
                        PropertyChip(
                          icon: PlaneTheme.priorityIcon(issue.priority),
                          iconColor:
                              PlaneTheme.priorityColor(issue.priority),
                          label: issue.priority[0].toUpperCase() +
                              issue.priority.substring(1),
                          onTap: () => _showPriorityPicker(),
                        ),
                        // Label pills
                        ...issueLabels.map((l) => _LabelPill(
                              label: l,
                              onTap: () => _showLabelPicker(),
                            )),
                        // Add label chip
                        PropertyChip(
                          icon: Icons.label_outline,
                          iconColor: secondary,
                          label: issueLabels.isEmpty
                              ? 'Label'
                              : '+',
                          onTap: () => _showLabelPicker(),
                        ),
                        // Assignee chip
                        PropertyChip(
                          icon: Icons.person_outline,
                          iconColor: secondary,
                          label: issueMembers.isEmpty
                              ? 'Assignee'
                              : '${issueMembers.length}',
                          onTap: () => _showAssigneePicker(),
                        ),
                        // Start date chip
                        PropertyChip(
                          icon: Icons.calendar_today_outlined,
                          iconColor: secondary,
                          label: issue.startDate ?? 'Start',
                          onTap: () => _pickDate('start_date', issue.startDate),
                        ),
                        // Target date chip
                        PropertyChip(
                          icon: Icons.flag_outlined,
                          iconColor: issue.isOverdue
                              ? PlaneTheme.urgent
                              : secondary,
                          label: issue.targetDate ?? 'Due',
                          onTap: () =>
                              _pickDate('target_date', issue.targetDate),
                        ),
                      ],
                    ),
                    // Overdue text
                    if (issue.isOverdue) ...[
                      const SizedBox(height: 6),
                      Text('Overdue',
                          style: TextStyle(
                              fontSize: 12,
                              color: PlaneTheme.urgent,
                              fontWeight: FontWeight.w500)),
                    ],
                    // Module & Cycle
                    if (_moduleName != null || _cycleName != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          if (_moduleName != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.view_module_outlined, size: 14, color: secondary),
                                const SizedBox(width: 4),
                                Text(_moduleName!, style: TextStyle(fontSize: 13, color: secondary)),
                              ],
                            ),
                          if (_cycleName != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.replay_outlined, size: 14, color: secondary),
                                const SizedBox(width: 4),
                                Text(_cycleName!, style: TextStyle(fontSize: 13, color: secondary)),
                              ],
                            ),
                        ],
                      ),
                    ],
                    // Assignee avatars row
                    if (issueMembers.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text('Assignees',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: secondary)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: issueMembers
                            .map((m) => _AssigneeChip(member: m))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Description
                    if (issue.descriptionHtml != null &&
                        issue.descriptionHtml!.isNotEmpty) ...[
                      MarkdownBody(
                        data: htmlToMarkdown(issue.descriptionHtml!),
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: theme.colorScheme.onSurface),
                          h1: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface),
                          h2: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface),
                          h3: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface),
                          code: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.primary,
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.08)),
                          codeblockDecoration: BoxDecoration(
                            color: theme
                                .colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          blockquoteDecoration: BoxDecoration(
                            border: Border(
                                left: BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 3)),
                          ),
                          listBullet: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface),
                        ),
                        selectable: true,
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Sub-issues section
                    _buildSubIssuesSection(secondary),
                    // Relations section
                    if (_relations.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildRelationsSection(secondary),
                    ],
                    // Attachments section
                    const SizedBox(height: 20),
                    _buildAttachmentsSection(secondary),
                    // Links section
                    const SizedBox(height: 20),
                    _buildLinksSection(secondary),
                    const SizedBox(height: 20),
                    // Activity header
                    Row(
                      children: [
                        Text('Activity',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: secondary)),
                        const Spacer(),
                        if (activityItems.isNotEmpty)
                          Text('${activityItems.length}',
                              style: TextStyle(
                                  fontSize: 12, color: secondary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Interleaved activities and comments
                    ...activityItems,
                    if (activityItems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('No activity yet',
                            style: TextStyle(
                                fontSize: 13, color: secondary)),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
          // Comment input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: PlaneTheme.background.withValues(alpha: 0.80),
              border: Border(
                  top: BorderSide(
                      color: PlaneTheme.outlineVariant.withValues(alpha: 0.10), width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: PlaneTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    // User avatar
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: PlaneTheme.surfaceContainerHighest,
                      child: Icon(Icons.person, size: 14, color: PlaneTheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(
                            color: PlaneTheme.onSurfaceVariant.withValues(alpha: 0.50),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 14, color: PlaneTheme.onSurface),
                        maxLines: null,
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.attach_file, size: 18,
                          color: PlaneTheme.onSurfaceVariant),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    GestureDetector(
                      onTap: _addComment,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: PlaneTheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send, size: 14,
                            color: PlaneTheme.onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Sub-issues section ---
  Widget _buildSubIssuesSection(Color secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Sub-issues',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: secondary)),
            if (_subIssues.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text('${_subIssues.length}',
                  style: TextStyle(fontSize: 12, color: secondary)),
            ],
            const Spacer(),
            GestureDetector(
              onTap: _addSubIssue,
              child: Icon(Icons.add, size: 18, color: secondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_subIssues.isEmpty)
          Text('No sub-issues',
              style: TextStyle(fontSize: 13, color: secondary))
        else
          ..._subIssues.map((sub) {
            final subState = widget.states[sub.state];
            return InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IssueDetailScreen(
                      workspaceSlug: widget.workspaceSlug,
                      projectId: widget.projectId,
                      issueId: sub.id,
                      states: widget.states,
                    ),
                  ),
                );
                _load();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      PlaneTheme.stateIcon(subState?.group ?? 'backlog'),
                      size: 16,
                      color: PlaneTheme.stateGroupColor(
                          subState?.group ?? 'backlog'),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      PlaneTheme.priorityIcon(sub.priority),
                      size: 14,
                      color: PlaneTheme.priorityColor(sub.priority),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(sub.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // --- Relations section ---
  Widget _buildRelationsSection(Color secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Relations',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: secondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _relations.map((r) {
            final relationType = r['relation_type'] ?? 'relates_to';
            final relatedIssue = r['issue_detail'] ?? r['related_issue_detail'];
            final issueName = relatedIssue?['name'] ?? 'Unknown issue';
            return _RelationChip(
              type: relationType,
              issueName: issueName,
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Attachments section ---
  Widget _buildAttachmentsSection(Color secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Attachments',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: secondary)),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text('${_attachments.length}',
                  style: TextStyle(fontSize: 12, color: secondary)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (_attachments.isEmpty)
          Text('No attachments',
              style: TextStyle(fontSize: 13, color: secondary))
        else
          ..._attachments.map((a) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.attach_file, size: 16, color: secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a.filename ?? 'Unnamed file',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (a.displaySize.isNotEmpty)
                      Text(a.displaySize,
                          style: TextStyle(fontSize: 11, color: secondary)),
                  ],
                ),
              )),
      ],
    );
  }

  // --- Links section ---
  Widget _buildLinksSection(Color secondary) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Links',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: secondary)),
            if (_links.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text('${_links.length}',
                  style: TextStyle(fontSize: 12, color: secondary)),
            ],
            const Spacer(),
            GestureDetector(
              onTap: _showAddLinkDialog,
              child: Icon(Icons.add, size: 18, color: secondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_links.isEmpty)
          Text('No links',
              style: TextStyle(fontSize: 13, color: secondary))
        else
          ..._links.map((link) => InkWell(
                onTap: () {
                  // Show URL in a snackbar since url_launcher is not available
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(link.url)),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              link.title ?? link.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            if (link.title != null && link.title!.isNotEmpty)
                              Text(
                                link.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11, color: secondary),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  // --- Add link dialog ---
  void _showAddLinkDialog() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await IssueService.addLink(
                  widget.workspaceSlug,
                  widget.projectId,
                  widget.issueId,
                  {
                    'url': url,
                    if (titleController.text.trim().isNotEmpty)
                      'title': titleController.text.trim(),
                  },
                );
                _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add link: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // --- Build interleaved activity items ---
  String _resolveActorName(Activity a) {
    if (a.actorDetail != null) return a.actorDetail!;
    if (a.actorId != null && _allMembers.isNotEmpty) {
      for (final m in _allMembers) {
        if (m.id == a.actorId) {
          return m.displayName.isNotEmpty ? m.displayName : m.email;
        }
      }
    }
    return 'Someone';
  }

  List<Widget> _buildActivityItems() {
    final items = <_ActivityEntry>[];

    // Add comments
    for (final c in _comments) {
      items.add(_ActivityEntry(
        date: c.createdAt,
        widget: _CommentCard(comment: c),
      ));
    }

    // Add activities (skip empty ones and comment-type)
    for (final a in _activities) {
      if (a.field == 'comment') continue;
      items.add(_ActivityEntry(
        date: a.createdAt,
        widget: _ActivityCard(activity: a, resolvedActorName: _resolveActorName(a)),
      ));
    }

    // Sort by date descending (newest first)
    items.sort((a, b) => b.date.compareTo(a.date));

    return items.map((e) => e.widget).toList();
  }

  // --- More menu with delete ---
  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 20),
              title: const Text('Delete issue',
                  style: TextStyle(color: Colors.red, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete issue'),
        content:
            const Text('Are you sure you want to delete this issue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteIssue();
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- State picker ---
  void _showStatePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.states.values
              .map((s) => ListTile(
                    leading: Icon(PlaneTheme.stateIcon(s.group),
                        color: PlaneTheme.stateGroupColor(s.group),
                        size: 18),
                    title: Text(s.name,
                        style: const TextStyle(fontSize: 14)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _updateField({'state': s.id});
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  // --- Priority picker ---
  void _showPriorityPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['urgent', 'high', 'medium', 'low', 'none']
              .map((p) => ListTile(
                    leading: Icon(PlaneTheme.priorityIcon(p),
                        color: PlaneTheme.priorityColor(p), size: 18),
                    title: Text(p[0].toUpperCase() + p.substring(1),
                        style: const TextStyle(fontSize: 14)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _updateField({'priority': p});
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  // --- Label picker (multi-select) ---
  Future<void> _shareIssue(Issue issue) async {
    final baseUrl = await SecureStorage.getBaseUrl() ?? '';
    final id = _projectIdentifier.isNotEmpty
        ? '$_projectIdentifier-${issue.sequenceId}'
        : '${issue.sequenceId}';
    final url =
        '$baseUrl/${widget.workspaceSlug}/projects/${widget.projectId}/issues/${widget.issueId}';
    await SharePlus.instance.share(
      ShareParams(text: '$id: ${issue.name}\n$url'),
    );
  }

  Future<void> _createLabel() async {
    final nameController = TextEditingController();
    final colors = [
      '#ef4444', '#f97316', '#eab308', '#22c55e', '#06b6d4',
      '#3b82f6', '#8b5cf6', '#ec4899', '#6b7280', '#0ea5e9',
    ];
    var selectedColor = colors[0];

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
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
                children: colors.map((c) => GestureDetector(
                  onTap: () => setDialogState(() => selectedColor = c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _parseColor(c),
                      shape: BoxShape.circle,
                      border: selectedColor == c
                          ? Border.all(color: Theme.of(ctx).colorScheme.onSurface, width: 2)
                          : null,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx, {'name': name, 'color': selectedColor});
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        await LabelService.createLabel(
            widget.workspaceSlug, widget.projectId, result);
        // Reload labels and reopen picker
        _allLabels = await _tryLoad(() => LabelService.getLabels(
            widget.workspaceSlug, widget.projectId), <Label>[]);
        if (mounted) {
          setState(() {});
          _showLabelPicker();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating label: $e')),
          );
        }
      }
    }
  }

  void _showLabelPicker() {
    final selected = Set<String>.from(_issue?.labels ?? []);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Text('Labels',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _updateField({'labels': selected.toList()});
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              if (_allLabels.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No labels yet',
                      style: TextStyle(fontSize: 13)),
                ),
              ..._allLabels.map((l) => CheckboxListTile(
                    value: selected.contains(l.id),
                    onChanged: (v) {
                      setSheetState(() {
                        if (v == true) {
                          selected.add(l.id);
                        } else {
                          selected.remove(l.id);
                        }
                      });
                    },
                    secondary: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _parseColor(l.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title:
                        Text(l.name, style: const TextStyle(fontSize: 14)),
                    controlAffinity: ListTileControlAffinity.trailing,
                    dense: true,
                  )),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add, size: 20),
                title: const Text('Create new label', style: TextStyle(fontSize: 14)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _createLabel();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Assignee picker (multi-select) ---
  void _showAssigneePicker() {
    final selected = Set<String>.from(_issue?.assignees ?? []);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Text('Assignees',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _updateField({'assignees': selected.toList()});
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              if (_allMembers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No members found',
                      style: TextStyle(fontSize: 13)),
                ),
              ..._allMembers.map((m) => CheckboxListTile(
                    value: selected.contains(m.id),
                    onChanged: (v) {
                      setSheetState(() {
                        if (v == true) {
                          selected.add(m.id);
                        } else {
                          selected.remove(m.id);
                        }
                      });
                    },
                    secondary: _buildMemberAvatar(m),
                    title: Text(m.displayName,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: m.email.isNotEmpty
                        ? Text(m.email,
                            style: const TextStyle(fontSize: 12))
                        : null,
                    controlAffinity: ListTileControlAffinity.trailing,
                    dense: true,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(Member m) {
    final theme = Theme.of(context);
    if (m.avatar != null && m.avatar!.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundImage: NetworkImage(m.avatar!),
        backgroundColor: theme.colorScheme.surface,
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      child: Text(
        (m.displayName.isNotEmpty ? m.displayName : '?')[0].toUpperCase(),
        style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
      ),
    );
  }

  // --- Date picker ---
  Future<void> _pickDate(String field, String? currentValue) async {
    final now = DateTime.now();
    DateTime initial = now;
    if (currentValue != null) {
      final parsed = DateTime.tryParse(currentValue);
      if (parsed != null) initial = parsed;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      final formatted =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _updateField({field: formatted});
    }
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF999999);
  }
}

// --- Activity entry for sorting ---
class _ActivityEntry {
  final DateTime date;
  final Widget widget;
  _ActivityEntry({required this.date, required this.widget});
}

// --- Relation chip widget ---
class _RelationChip extends StatelessWidget {
  final String type;
  final String issueName;
  const _RelationChip({required this.type, required this.issueName});

  IconData get _icon {
    switch (type) {
      case 'blocking':
        return Icons.block;
      case 'blocked_by':
        return Icons.pause_circle_outline;
      case 'duplicate':
        return Icons.content_copy;
      case 'relates_to':
        return Icons.link;
      default:
        return Icons.link;
    }
  }

  String get _label {
    switch (type) {
      case 'blocking':
        return 'Blocking';
      case 'blocked_by':
        return 'Blocked by';
      case 'duplicate':
        return 'Duplicate of';
      case 'relates_to':
        return 'Relates to';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = type == 'blocking' || type == 'blocked_by'
        ? PlaneTheme.urgent
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
        color: color.withValues(alpha: 0.05),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text('$_label: ',
              style: TextStyle(fontSize: 11, color: color,
                  fontWeight: FontWeight.w500)),
          Flexible(
            child: Text(issueName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: color)),
          ),
        ],
      ),
    );
  }
}

// --- Activity card widget ---
class _ActivityCard extends StatelessWidget {
  final Activity activity;
  final String? resolvedActorName;
  const _ActivityCard({required this.activity, this.resolvedActorName});

  String get _description {
    final actor = resolvedActorName ?? activity.actorDetail ?? 'Someone';
    final field = activity.field;
    final verb = activity.verb;
    if (field == null || field.isEmpty) {
      if (verb == 'created') return '$actor created the issue';
      return '$actor updated the issue';
    }
    final fieldName = Activity.formatFieldName(field);
    final oldVal = activity.oldValue;
    final newVal = activity.newValue;
    if (verb == 'created') {
      if (newVal != null && newVal.isNotEmpty) return '$actor set $fieldName to $newVal';
      return '$actor created the issue';
    }
    if (verb == 'updated') {
      if (oldVal != null && oldVal.isNotEmpty && newVal != null && newVal.isNotEmpty) {
        return '$actor changed $fieldName from $oldVal to $newVal';
      }
      if (newVal != null && newVal.isNotEmpty) return '$actor set $fieldName to $newVal';
      if (oldVal != null && oldVal.isNotEmpty) return '$actor removed $fieldName $oldVal';
      return '$actor updated $fieldName';
    }
    if (verb == 'deleted') return '$actor removed $fieldName${oldVal != null ? ' $oldVal' : ''}';
    return '$actor $verb $fieldName';
  }

  IconData get _icon {
    switch (activity.field) {
      case 'state':
        return Icons.circle_outlined;
      case 'priority':
        return Icons.flag_outlined;
      case 'assignees':
        return Icons.person_outline;
      case 'labels':
        return Icons.label_outline;
      case 'name':
        return Icons.title;
      case 'description':
        return Icons.description_outlined;
      case 'target_date':
        return Icons.calendar_today_outlined;
      case 'start_date':
        return Icons.calendar_today_outlined;
      case 'parent':
        return Icons.subdirectory_arrow_right;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 16,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _description,
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  timeAgo(activity.createdAt),
                  style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Label pill widget ---
class _LabelPill extends StatelessWidget {
  final Label label;
  final VoidCallback? onTap;
  const _LabelPill({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(label.color);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(label.name,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
    );
  }

  static Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF999999);
  }
}

// --- Assignee chip widget ---
class _AssigneeChip extends StatelessWidget {
  final Member member;
  const _AssigneeChip({required this.member});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (member.avatar != null && member.avatar!.isNotEmpty)
          CircleAvatar(
            radius: 12,
            backgroundImage: NetworkImage(member.avatar!),
            backgroundColor: theme.colorScheme.surface,
          )
        else
          CircleAvatar(
            radius: 12,
            backgroundColor:
                theme.colorScheme.primary.withValues(alpha: 0.2),
            child: Text(
              (member.displayName.isNotEmpty ? member.displayName : '?')[0]
                  .toUpperCase(),
              style: TextStyle(
                  fontSize: 10, color: theme.colorScheme.primary),
            ),
          ),
        const SizedBox(width: 5),
        Text(member.displayName,
            style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// --- Comment card ---
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
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.2),
                child: Text(
                  (comment.actorDetail ?? '?')[0].toUpperCase(),
                  style: TextStyle(
                      fontSize: 11, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text(comment.actorDetail ?? 'Unknown',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(width: 8),
              Text(timeAgo(comment.createdAt),
                  style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 4),
            child: Text(
              comment.commentHtml
                      ?.replaceAll(RegExp(r'<[^>]*>'), '')
                      .trim() ??
                  '',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
