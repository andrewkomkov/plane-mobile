import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import '../../config/m3e/motion.dart';
import '../../config/m3e/shapes.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/m3e/text_field.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/secure_storage.dart';
import '../../config/theme.dart';
import '../../services/module_service.dart';
import '../../services/issue_service.dart';
import '../../services/attachment_service.dart';
import '../../services/comment_service.dart';
import '../../services/label_service.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../../providers/data_providers.dart';
import '../../models/issue.dart';
import '../../models/state.dart';
import '../../models/comment.dart';
import '../../models/label.dart';
import '../../models/member.dart';
import '../../models/activity.dart';
import '../../models/attachment.dart';
import '../../models/link.dart';
import '../../models/reaction.dart';
import '../../models/estimate_point.dart';
import '../../models/cycle.dart';
import '../../models/module.dart';
import '../../services/cycle_service.dart';
import '../../utils/html_to_markdown.dart';
import '../../utils/time_ago.dart';
import '../../widgets/property_chip.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/reaction_bar.dart';
import '../../widgets/skeleton_loader.dart';
import 'issue_create_screen.dart';

/// One vertical rhythm for the whole screen.
///
/// The gaps here used to be typed at each site — 24 after the description, 20
/// between every other pair of sections, 14 before the assignee list, 8 and 6
/// under the chips — so nothing lined up with anything and the eye had no grid
/// to lock onto. Three constants replace all of them.
///
/// Between two blocks whose edges are ink.
const double _sectionGap = 24;

/// The clear space a 48dp tap target already contributes around the ~28dp pill
/// drawn inside it. A block of chips or reactions therefore needs less added
/// space than a block of text to land on the same rhythm.
const double _targetInset = 10;

/// Between a section's header and its content.
const double _headerGap = 8;

/// A gap in that rhythm.
///
/// [afterTargets] and [beforeTargets] say whether the block above or below is
/// made of 48dp tap targets. Each of those already carries [_targetInset] of
/// clear space around the pill drawn inside it, so the added gap is reduced by
/// that much and the eye sees the same [_sectionGap] at every boundary. This
/// is the difference between a rhythm and seven numbers that happen to be
/// close: chips against text and chips against chips are not the same gap.
Widget _gap({bool afterTargets = false, bool beforeTargets = false}) =>
    SizedBox(
      height: _sectionGap -
          (afterTargets ? _targetInset : 0) -
          (beforeTargets ? _targetInset : 0),
    );

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
  ConsumerState<IssueDetailScreen> createState() => _IssueDetailScreenState();
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

  /// Name of the file currently uploading, or null. Drives both the row in the
  /// attachments list and the disabled state of the attach button.
  String? _uploadingAttachment;
  String? _moduleName;
  String? _cycleName;
  List<IssueLink> _links = [];

  /// Reactions on the work item itself. Comment reactions ride along on the
  /// comments and live in [Comment.reactions].
  List<Reaction> _reactions = [];

  /// The project's estimate scale. Empty means the project has no estimate
  /// system configured, which is the common case — the control hides entirely
  /// rather than offering an empty picker.
  List<EstimatePoint> _estimatePoints = [];

  /// Loaded so the cycle and module chips can name what they point at and so
  /// their pickers open instantly. Read-only use of the two services those
  /// screens own.
  List<Cycle> _cycles = [];
  List<Module> _modules = [];
  bool _loading = true;
  String? _error;
  String _projectIdentifier = '';

  /// States for this project, keyed by id.
  ///
  /// Seeded from whatever the caller passed and refetched when that is empty.
  /// Same problem the identifier had: half the routes here — the notification
  /// feed passes `states: const {}` outright — cannot supply it, and the
  /// screen then rendered every work item's status as "Unknown" with a backlog
  /// icon. A screen should not depend on nine callers each remembering to hand
  /// it its own reference data.
  late Map<String, IssueState> _states = widget.states;
  final _commentController = TextEditingController();

  /// Who is looking at this screen. Decides which comments offer edit and
  /// delete, so it is loaded before the comment list is drawn rather than
  /// alongside it — an affordance that appears a moment late is worse than one
  /// that appears with the content.
  String? _currentUserId;

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
      if (!mounted) return;
      setState(() {
        _error = _describeLoadFailure(e);
        _loading = false;
      });
    }
  }

  /// Turns a load failure into something that names the cause.
  ///
  /// This screen used to record a flat 'Could not load issue' for anything that
  /// threw, which made a 404 from a renamed route, an auth rejection and a
  /// parse error on an unexpected response shape all look identical — and all
  /// look like the network. That is precisely how a dead endpoint survives to
  /// production unnoticed, so the status code, or the type error if the request
  /// itself succeeded, is kept and shown.
  String _describeLoadFailure(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status != null) {
        return 'Server returned $status for this work item';
      }
      return 'Could not reach the server (${e.type.name})';
    }
    // A non-Dio throw here means the response arrived and parsing it failed.
    return 'Could not read the work item response: $e';
  }

  Future<void> _lazyLoad() async {
    final ws = widget.workspaceSlug;
    final pid = widget.projectId;
    final iid = widget.issueId;
    final cache = ref.read(dataCacheProvider);

    // Identity first: the comment cards below need it to decide whether to
    // offer edit and delete, and it is a single cheap call.
    _currentUserId ??=
        (await _tryLoad<User?>(() => AuthService.getCurrentUser(), null))?.id;

    // Half the routes into this screen — notifications, the calendar, a cycle
    // or module's issue list, the sub-issue rows below — push it without an
    // identifier, and _load can only resolve one from a projects cache that
    // those routes never warmed. That is why the bar read "Issue" instead of
    // PLM-123 depending on how you arrived. Warm it here rather than plumbing
    // the identifier through nine screens: loadProjects reads SQLite first and
    // no-ops when the list is already in memory, so the common case costs
    // nothing.
    if (_projectIdentifier.isEmpty) {
      await cache.loadProjects(ws);
      final projects = cache.getProjects(ws);
      if (projects != null) {
        for (final p in projects) {
          if (p.id == pid) {
            _projectIdentifier = p.identifier;
            break;
          }
        }
      }
      if (mounted) setState(() {});
    }

    if (_states.isEmpty) {
      final states =
          await _tryLoad(() => IssueService.getStates(ws, pid), <IssueState>[]);
      if (states.isNotEmpty) {
        _states = {for (final s in states) s.id: s};
        if (mounted) setState(() {});
      }
    }

    _comments = await _tryLoad(
        () => CommentService.getComments(ws, pid, iid), <Comment>[]);
    if (mounted) setState(() {});

    // Use shared cache for labels and members (avoids duplicate API calls)
    await cache.loadLabels(ws, pid);
    await cache.loadMembers(ws, pid);
    _allLabels = cache.getLabels(ws, pid) ?? [];
    _allMembers = cache.getMembers(ws, pid) ?? [];
    if (mounted) setState(() {});

    _activities = await _tryLoad(
        () => IssueService.getActivities(ws, pid, iid), <Activity>[]);
    if (mounted) setState(() {});

    _reactions = await _tryLoad(
        () => IssueService.getReactions(ws, pid, iid), <Reaction>[]);
    if (mounted) setState(() {});

    _subIssues = await _tryLoad(
        () => IssueService.getSubIssues(ws, pid, iid), <Issue>[]);
    _relations = await _tryLoad(
        () => IssueService.getIssueRelations(ws, pid, iid),
        <Map<String, dynamic>>[]);
    _attachments = await _tryLoad(
        () => AttachmentService.getAttachments(ws, pid, iid), <Attachment>[]);
    _links = await _tryLoad(
        () => IssueService.getLinks(ws, pid, iid), <IssueLink>[]);

    // An empty scale is the normal answer for a project with no estimates
    // configured, and a 403 is the answer for a guest. _tryLoad turns the
    // second into the first, and both mean the same thing here: no control.
    _estimatePoints = await _tryLoad(
        () => IssueService.getEstimatePoints(ws, pid), <EstimatePoint>[]);
    _cycles = await _tryLoad(() => CycleService.getCycles(ws, pid), <Cycle>[]);
    _modules =
        await _tryLoad(() => ModuleService.getModules(ws, pid), <Module>[]);
    if (mounted) setState(() {});

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

  /// The estimate's display value, or null when nothing is set.
  String? _estimateLabel(Issue issue) {
    final id = issue.estimatePoint;
    if (id == null) return null;
    for (final p in _estimatePoints) {
      if (p.id == id) return p.value;
    }
    return null;
  }

  /// The cycle's name.
  ///
  /// Falls back to the name the bespoke `issue-info` proxy endpoint returns,
  /// which is the only source when the cycle list could not be loaded.
  String? _cycleLabel(Issue issue) {
    final id = issue.cycleId;
    if (id != null) {
      for (final c in _cycles) {
        if (c.id == id) return c.name;
      }
    }
    return _cycleName;
  }

  /// Module names, or a count once there is more than one — several module
  /// names side by side push every other chip off the row.
  String? _moduleLabel(Issue issue) {
    final ids = issue.moduleIds;
    if (ids.isEmpty) return _moduleName;
    final names =
        _modules.where((m) => ids.contains(m.id)).map((m) => m.name).toList();
    if (names.isEmpty) return _moduleName ?? '${ids.length}';
    if (names.length == 1) return names.first;
    return '${names.length} modules';
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

  /// Opens the editor for a comment and saves the result.
  ///
  /// The body is edited as plain text and re-wrapped in a paragraph on save,
  /// matching how [_addComment] writes them. Anything richer that was authored
  /// on the web would be flattened by a round trip through this box, so a
  /// comment whose markup is more than a single paragraph is not offered for
  /// editing at all — see [_commentIsPlainParagraph].
  Future<void> _editComment(Comment comment) async {
    final controller = TextEditingController(text: _commentPlainText(comment));
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit comment'),
        content: M3ETextField(
          label: 'Comment',
          controller: controller,
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == null) return;

    try {
      final updated = await CommentService.updateComment(
        widget.workspaceSlug,
        widget.projectId,
        widget.issueId,
        comment.id,
        '<p>$saved</p>',
      );
      if (!mounted) return;
      // Swap in place rather than reloading the screen: the server answers the
      // PATCH with the full comment, and a reload would scroll the activity
      // feed back to the top away from what was just edited.
      setState(() {
        final i = _comments.indexWhere((c) => c.id == comment.id);
        if (i != -1) _comments[i] = updated;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the comment: $e')),
      );
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment'),
        content: const Text(
            'Are you sure you want to delete this comment? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await CommentService.deleteComment(
        widget.workspaceSlug,
        widget.projectId,
        widget.issueId,
        comment.id,
      );
      if (!mounted) return;
      setState(() => _comments.removeWhere((c) => c.id == comment.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete the comment: $e')),
      );
    }
  }

  /// The comment body as plain text, which is all this screen can render.
  static String _commentPlainText(Comment comment) =>
      (comment.commentHtml ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();

  /// Whether the body survives a round trip through the plain-text editor.
  ///
  /// The editor strips markup, so offering it for a comment containing lists,
  /// links or images would quietly destroy them on save. Only a body that is a
  /// single paragraph — what this app itself writes — is safe to edit here.
  static bool _commentIsPlainParagraph(Comment comment) {
    final html = (comment.commentHtml ?? '').trim();
    if (html.isEmpty) return true;
    final withoutParagraph =
        html.replaceAll(RegExp(r'^<p>|</p>$', caseSensitive: false), '');
    return !withoutParagraph.contains('<');
  }

  Future<void> _attachFile() async {
    final picked = await FilePicker.platform.pickFiles();
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;

    final file = File(path);
    final name = picked!.files.single.name;

    setState(() => _uploadingAttachment = name);
    try {
      await AttachmentService.upload(
        widget.workspaceSlug,
        widget.projectId,
        widget.issueId,
        file: file,
        name: name,
        // The presigned policy pins the content type, so a wrong guess here is
        // rejected by the store rather than silently stored mislabelled.
        mimeType: lookupMimeType(path) ?? 'application/octet-stream',
      );
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not attach $name: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAttachment = null);
    }
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
          states: _states,
          parentIssueId: widget.issueId,
        ),
      ),
    );
    _load();
  }

  /// Makes an existing work item a child of this one.
  ///
  /// The other half of "add sub-issue": creating a new child is
  /// [_addSubIssue], adopting one that already exists is this. Parenthood is
  /// just a field on the child, so this is a PATCH of the child rather than
  /// anything on this screen's own work item.
  Future<void> _linkExistingSubIssue() async {
    final picked = await _pickIssue(
      title: 'Add existing sub-issue',
      excludeIds: {widget.issueId, ..._subIssues.map((s) => s.id)},
    );
    if (picked == null) return;
    try {
      await IssueService.updateIssue(
        widget.workspaceSlug,
        widget.projectId,
        picked.id,
        {'parent': widget.issueId},
      );
      _load();
    } catch (e) {
      _complain('Could not add the sub-issue', e);
    }
  }

  /// Detaches a child, which is clearing its parent, not deleting it.
  Future<void> _removeSubIssue(Issue sub) async {
    try {
      await IssueService.updateIssue(
        widget.workspaceSlug,
        widget.projectId,
        sub.id,
        {'parent': null},
      );
      if (mounted) {
        setState(() => _subIssues.removeWhere((s) => s.id == sub.id));
      }
    } catch (e) {
      _complain('Could not remove the sub-issue', e);
    }
  }

  void _complain(String what, Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what: $e')),
    );
  }

  // --- Reactions (#7) ---

  /// Adds or removes the current user's [code] reaction on the work item.
  ///
  /// Applied locally first and reverted on failure. A reaction is a one-tap
  /// action whose whole value is that it feels instant; waiting on a round
  /// trip to redraw makes it feel broken, and the failure case is both rare
  /// and cheap to undo.
  Future<void> _toggleIssueReaction(String code) async {
    final me = _currentUserId;
    final mine = me != null &&
        _reactions.any((r) => r.reaction == code && r.actor == me);
    final before = List<Reaction>.from(_reactions);

    setState(() {
      if (mine) {
        _reactions.removeWhere((r) => r.reaction == code && r.actor == me);
      } else {
        _reactions.add(Reaction(id: '', reaction: code, actor: me));
      }
    });

    try {
      if (mine) {
        await IssueService.removeReaction(
            widget.workspaceSlug, widget.projectId, widget.issueId, code);
      } else {
        await IssueService.addReaction(
            widget.workspaceSlug, widget.projectId, widget.issueId, code);
      }
      // Identity unknown means the optimistic row could not be attributed, so
      // the chip would not show as the user's own until the next load. Re-read
      // rather than leave it looking like someone else's.
      if (me == null || me.isEmpty) {
        final fresh = await _tryLoad(
            () => IssueService.getReactions(
                widget.workspaceSlug, widget.projectId, widget.issueId),
            before);
        if (mounted) setState(() => _reactions = fresh);
      }
    } catch (e) {
      if (mounted) setState(() => _reactions = before);
      _complain('Could not update the reaction', e);
    }
  }

  /// Same toggle, against a comment's own reaction route.
  Future<void> _toggleCommentReaction(Comment comment, String code) async {
    final me = _currentUserId;
    final mine = me != null &&
        comment.reactions.any((r) => r.reaction == code && r.actor == me);
    final before = comment.reactions;

    List<Reaction> next;
    if (mine) {
      next =
          before.where((r) => !(r.reaction == code && r.actor == me)).toList();
    } else {
      next = [...before, Reaction(id: '', reaction: code, actor: me)];
    }
    _replaceComment(comment.copyWithReactions(next));

    try {
      if (mine) {
        await CommentService.removeReaction(
            widget.workspaceSlug, widget.projectId, comment.id, code);
      } else {
        await CommentService.addReaction(
            widget.workspaceSlug, widget.projectId, comment.id, code);
      }
      if (me == null || me.isEmpty) {
        final fresh = await _tryLoad(
            () => CommentService.getReactions(
                widget.workspaceSlug, widget.projectId, comment.id),
            next);
        _replaceComment(comment.copyWithReactions(fresh));
      }
    } catch (e) {
      _replaceComment(comment.copyWithReactions(before));
      _complain('Could not update the reaction', e);
    }
  }

  void _replaceComment(Comment updated) {
    if (!mounted) return;
    setState(() {
      final i = _comments.indexWhere((c) => c.id == updated.id);
      if (i != -1) _comments[i] = updated;
    });
  }

  // --- Subscription (#8) ---

  /// Turns notifications for this work item on or off.
  ///
  /// This app already delivers push notifications with no way to decline them,
  /// so this is the off switch for those.
  Future<void> _toggleSubscription() async {
    final issue = _issue;
    if (issue == null) return;
    // Null means the server did not say. Treating unknown as subscribed makes
    // the first tap an unsubscribe, which is the safe direction: the worst
    // case is a no-op the service already swallows, rather than silently
    // subscribing someone who tapped a bell to make it stop.
    final subscribed = issue.isSubscribed ?? true;

    setState(() => _issue = _withSubscription(issue, !subscribed));
    try {
      if (subscribed) {
        await IssueService.unsubscribe(
            widget.workspaceSlug, widget.projectId, widget.issueId);
      } else {
        await IssueService.subscribe(
            widget.workspaceSlug, widget.projectId, widget.issueId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(subscribed
                ? 'Unsubscribed from this work item'
                : 'Subscribed to this work item'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _issue = issue);
      _complain('Could not change the subscription', e);
    }
  }

  /// The work item with only `is_subscribed` changed.
  ///
  /// Issue has no copyWith and adding one for a single screen's optimistic
  /// update would be a wide change to a model several screens share, so the
  /// round trip through JSON reuses the parser that is already correct about
  /// every other field.
  Issue _withSubscription(Issue issue, bool subscribed) => Issue.fromJson({
        'id': issue.id,
        'name': issue.name,
        'description_html': issue.descriptionHtml,
        'state_id': issue.state,
        'state_detail': issue.stateDetail,
        'priority': issue.priority,
        'sequence_id': issue.sequenceId,
        'project_detail': issue.projectDetail,
        'assignee_ids': issue.assignees,
        'label_ids': issue.labels,
        'created_at': issue.createdAt.toIso8601String(),
        'updated_at': issue.updatedAt.toIso8601String(),
        'created_by': issue.createdBy,
        'project_id': issue.project,
        'start_date': issue.startDate,
        'target_date': issue.targetDate,
        'parent_id': issue.parent,
        'sub_issues_count': issue.subIssuesCount,
        'is_subscribed': subscribed,
        'estimate_point': issue.estimatePoint,
        'cycle_id': issue.cycleId,
        'module_ids': issue.moduleIds,
        'archived_at': issue.archivedAt,
      });

  // --- Archive (#15) ---

  /// Whether the server will accept an archive for the current state.
  ///
  /// Plane only archives work items sitting in a completed or cancelled state
  /// group and 400s anything else. Knowing that here is what lets the menu say
  /// why instead of offering the action and then failing.
  bool get _canArchive {
    final group = _states[_issue?.state]?.group;
    return group != null && IssueService.archivableStateGroups.contains(group);
  }

  Future<void> _archiveIssue() async {
    try {
      await IssueService.archiveIssue(
          widget.workspaceSlug, widget.projectId, widget.issueId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work item archived')),
      );
      _load();
    } catch (e) {
      _complain('Could not archive the work item', e);
    }
  }

  Future<void> _unarchiveIssue() async {
    try {
      await IssueService.unarchiveIssue(
          widget.workspaceSlug, widget.projectId, widget.issueId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work item restored')),
      );
      _load();
    } catch (e) {
      _complain('Could not restore the work item', e);
    }
  }

  // --- Relations (#14) ---

  Future<void> _addRelation() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Relation type',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...IssueService.relationKinds.entries.map(
              (e) => ListTile(
                leading: Icon(_RelationChip.iconFor(e.key), size: 20),
                title: Text(e.value, style: Theme.of(ctx).textTheme.bodyMedium),
                onTap: () => Navigator.pop(ctx, e.key),
              ),
            ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;

    final picked = await _pickIssue(
      title: IssueService.relationKinds[kind] ?? 'Related work item',
      excludeIds: {
        widget.issueId,
        ..._relations.map((r) => r['id']?.toString() ?? ''),
      },
    );
    if (picked == null) return;

    try {
      await IssueService.addRelation(
        widget.workspaceSlug,
        widget.projectId,
        widget.issueId,
        kind,
        [picked.id],
      );
      _load();
    } catch (e) {
      _complain('Could not add the relation', e);
    }
  }

  Future<void> _removeRelation(Map<String, dynamic> relation) async {
    final relatedId = relation['id']?.toString();
    if (relatedId == null || relatedId.isEmpty) return;
    try {
      await IssueService.removeRelation(
          widget.workspaceSlug, widget.projectId, widget.issueId, relatedId);
      if (mounted) {
        setState(() =>
            _relations.removeWhere((r) => r['id']?.toString() == relatedId));
      }
    } catch (e) {
      _complain('Could not remove the relation', e);
    }
  }

  // --- Estimate, cycle and module (#11) ---

  void _showEstimatePicker() {
    final current = _issue?.estimatePoint;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Estimate',
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              ..._estimatePoints.map((p) => ListTile(
                    title: Text(p.value,
                        style: Theme.of(ctx).textTheme.bodyMedium),
                    subtitle: (p.description ?? '').isNotEmpty
                        ? Text(p.description!,
                            style: Theme.of(ctx).textTheme.bodySmall)
                        : null,
                    trailing: p.id == current
                        ? const Icon(Icons.check, size: 18)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _updateField({'estimate_point': p.id});
                    },
                  )),
              if (current != null) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.clear, size: 20),
                  title: Text('Clear estimate',
                      style: Theme.of(ctx).textTheme.bodyMedium),
                  onTap: () {
                    Navigator.pop(ctx);
                    _updateField({'estimate_point': null});
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showCyclePicker() {
    final current = _issue?.cycleId;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child:
                    Text('Cycle', style: Theme.of(ctx).textTheme.titleMedium),
              ),
              if (_cycles.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No cycles in this project',
                      style: Theme.of(ctx).textTheme.bodySmall),
                ),
              ..._cycles.map((c) => ListTile(
                    leading: const Icon(Icons.replay_outlined, size: 20),
                    title:
                        Text(c.name, style: Theme.of(ctx).textTheme.bodyMedium),
                    trailing: c.id == current
                        ? const Icon(Icons.check, size: 18)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _setCycle(c.id);
                    },
                  )),
              if (current != null) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.clear, size: 20),
                  title: Text('Remove from cycle',
                      style: Theme.of(ctx).textTheme.bodyMedium),
                  onTap: () {
                    Navigator.pop(ctx);
                    _setCycle(null);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Moves the work item to [cycleId], or out of its cycle when null.
  ///
  /// There is no `cycle` field on the work item to PATCH — membership lives in
  /// a join table reached through the cycle's own collection — so leaving a
  /// cycle is a delete against the old one and moving is an add to the new
  /// one, which the server treats as a move.
  Future<void> _setCycle(String? cycleId) async {
    final previous = _issue?.cycleId;
    try {
      if (cycleId == null) {
        if (previous == null) return;
        await IssueService.removeIssueFromCycle(
            widget.workspaceSlug, widget.projectId, previous, widget.issueId);
      } else {
        await IssueService.addIssueToCycle(
            widget.workspaceSlug, widget.projectId, cycleId, widget.issueId);
      }
      _load();
    } catch (e) {
      _complain('Could not change the cycle', e);
    }
  }

  void _showModulePicker() {
    final selected = Set<String>.from(_issue?.moduleIds ?? const <String>[]);
    final original = Set<String>.from(selected);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text('Modules',
                          style: Theme.of(ctx).textTheme.titleMedium),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _setModules(original, selected);
                        },
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                if (_modules.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No modules in this project',
                        style: Theme.of(ctx).textTheme.bodySmall),
                  ),
                ..._modules.map((m) => CheckboxListTile(
                      value: selected.contains(m.id),
                      onChanged: (v) => setSheetState(() {
                        if (v == true) {
                          selected.add(m.id);
                        } else {
                          selected.remove(m.id);
                        }
                      }),
                      secondary:
                          const Icon(Icons.view_module_outlined, size: 20),
                      title: Text(m.name,
                          style: Theme.of(ctx).textTheme.bodyMedium),
                      controlAffinity: ListTileControlAffinity.trailing,
                      dense: true,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sends the module change as the difference between the two sets.
  ///
  /// The endpoint takes additions and removals in one call but applies exactly
  /// what it is given — it does not diff against what is stored — so sending
  /// the whole selection as `modules` would re-add what was already there and
  /// never remove anything.
  Future<void> _setModules(Set<String> before, Set<String> after) async {
    final added = after.difference(before).toList();
    final removed = before.difference(after).toList();
    if (added.isEmpty && removed.isEmpty) return;
    try {
      await IssueService.setIssueModules(
        widget.workspaceSlug,
        widget.projectId,
        widget.issueId,
        added: added,
        removed: removed,
      );
      _load();
    } catch (e) {
      _complain('Could not change the modules', e);
    }
  }

  /// The property chips for [issue], the ones holding a value first.
  ///
  /// Set and unset are two different chips now — see [PropertyChip.hasValue] —
  /// and interleaving them throws that away: a filled "Done" sandwiched
  /// between two hollow placeholders reads as noise rather than as an answer.
  /// Partitioning keeps the relative order within each half, so nothing moves
  /// further than it has to, and gives the block a shape it did not have:
  /// what this work item is, then what it is still missing.
  List<Widget> _propertyChips(
    Issue issue,
    IssueState? state,
    List<Label> issueLabels,
    List<Member> issueMembers,
    Color secondary,
  ) {
    final valued = <Widget>[];
    final empty = <Widget>[];
    void add(bool hasValue, Widget chip) =>
        (hasValue ? valued : empty).add(chip);

    // A work item always sits in some state, so this is never a placeholder
    // even when the state map could not name it.
    add(
      true,
      PropertyChip(
        icon: PlaneTheme.stateIcon(state?.group ?? 'backlog'),
        iconColor:
            PlaneTheme.stateGroupColor(context, state?.group ?? 'backlog'),
        label: state?.name ?? 'Unknown',
        hasValue: true,
        onTap: _showStatePicker,
      ),
    );

    // Priority is the one property whose absence the API spells out instead of
    // omitting, so "None" is a placeholder despite having a label to show.
    final prioritised = issue.priority != 'none';
    add(
      prioritised,
      PropertyChip(
        icon: PlaneTheme.priorityIcon(issue.priority),
        iconColor: PlaneTheme.priorityColor(context, issue.priority),
        label: issue.priority[0].toUpperCase() + issue.priority.substring(1),
        hasValue: prioritised,
        onTap: _showPriorityPicker,
      ),
    );

    // Labels: the pills carry the value, the chip beside them is the editor,
    // so the editor follows whichever half the pills are in.
    final labelled = issueLabels.isNotEmpty;
    for (final l in issueLabels) {
      add(true, _LabelPill(label: l, onTap: _showLabelPicker));
    }
    add(
      labelled,
      Semantics(
        label: 'Edit labels',
        button: true,
        container: true,
        child: PropertyChip(
          icon: Icons.label_outline,
          // Once labels exist the chip reads "+", and a count is no name at
          // all, so this and the assignee chip carry an explicit label.
          label: labelled ? '+' : 'Label',
          iconColor: secondary,
          hasValue: labelled,
          onTap: _showLabelPicker,
        ),
      ),
    );

    final assigned = issueMembers.isNotEmpty;
    add(
      assigned,
      Semantics(
        label: 'Edit assignees',
        button: true,
        container: true,
        child: PropertyChip(
          icon: Icons.person_outline,
          label: assigned ? '${issueMembers.length}' : 'Assignee',
          iconColor: secondary,
          hasValue: assigned,
          onTap: _showAssigneePicker,
        ),
      ),
    );

    add(
      issue.startDate != null,
      PropertyChip(
        icon: Icons.calendar_today_outlined,
        iconColor: secondary,
        label: issue.startDate ?? 'Start',
        hasValue: issue.startDate != null,
        onTap: () => _pickDate('start_date', issue.startDate),
      ),
    );

    add(
      issue.targetDate != null,
      PropertyChip(
        icon: Icons.flag_outlined,
        iconColor: issue.isOverdue ? PlaneTheme.urgent : secondary,
        label: issue.targetDate ?? 'Due',
        hasValue: issue.targetDate != null,
        onTap: () => _pickDate('target_date', issue.targetDate),
      ),
    );

    // Estimate is absent entirely when the project has no estimate scale
    // configured — which is most of them — rather than offering a picker with
    // nothing in it.
    if (_estimatePoints.isNotEmpty) {
      final estimate = _estimateLabel(issue);
      add(
        estimate != null,
        Semantics(
          label: 'Edit estimate',
          button: true,
          container: true,
          child: PropertyChip(
            icon: Icons.speed_outlined,
            iconColor: secondary,
            label: estimate ?? 'Estimate',
            hasValue: estimate != null,
            onTap: _showEstimatePicker,
          ),
        ),
      );
    }

    final cycle = _cycleLabel(issue);
    add(
      cycle != null,
      Semantics(
        label: 'Edit cycle',
        button: true,
        container: true,
        child: PropertyChip(
          icon: Icons.replay_outlined,
          iconColor: secondary,
          label: cycle ?? 'Cycle',
          hasValue: cycle != null,
          onTap: _showCyclePicker,
        ),
      ),
    );

    final module = _moduleLabel(issue);
    add(
      module != null,
      Semantics(
        label: 'Edit modules',
        button: true,
        container: true,
        child: PropertyChip(
          icon: Icons.view_module_outlined,
          iconColor: secondary,
          label: module ?? 'Module',
          hasValue: module != null,
          onTap: _showModulePicker,
        ),
      ),
    );

    return [...valued, ...empty];
  }

  /// Opens a searchable list of the project's work items and returns the
  /// chosen one. Used for both relations and adopting an existing sub-issue.
  Future<Issue?> _pickIssue({
    required String title,
    required Set<String> excludeIds,
  }) {
    return showModalBottomSheet<Issue>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _IssuePickerSheet(
        title: title,
        workspaceSlug: widget.workspaceSlug,
        projectId: widget.projectId,
        excludeIds: excludeIds,
        states: _states,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: const M3EAppBar(title: 'Issue'),
        body: const IssueDetailSkeleton(),
      );
    }
    if (_error != null || _issue == null) {
      return Scaffold(
        appBar: const M3EAppBar(title: 'Issue'),
        body: ErrorStateWidget(
          message: _error ?? 'Failed to load issue',
          onRetry: _load,
        ),
      );
    }
    final issue = _issue!;
    final state = _states[issue.state];
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    // Resolve labels and members for this issue
    final issueLabels =
        _allLabels.where((l) => issue.labels.contains(l.id)).toList();
    final issueMembers =
        _allMembers.where((m) => issue.assignees.contains(m.id)).toList();

    // Merge activities and comments, sorted by date
    final activityItems = _buildActivityItems();

    final hasDescription =
        issue.descriptionHtml != null && issue.descriptionHtml!.isNotEmpty;

    // Whether the property block's last row is tap targets or the archived /
    // overdue line, which decides how much space the gap below it has to add.
    final propertiesEndInTargets = !(issue.isArchived || issue.isOverdue);

    return Scaffold(
      // The bar used to read "Plane", which told the user nothing they did
      // not already know. The issue's own identifier is the useful thing here.
      //
      // It reads the resolved identifier, not the one the route happened to
      // pass: the body below has always used the resolved one, so a screen
      // opened from the calendar or a notification showed PLM-123 in the
      // header and "Issue" in the bar at the same time.
      appBar: M3EAppBar(
        title: _projectIdentifier.isNotEmpty
            ? '$_projectIdentifier-${issue.sequenceId}'
            : 'Issue',
        actions: [
          // The bell is the only control for push notifications the app has,
          // so it sits in the bar rather than behind the overflow menu.
          M3EAppBarAction(
            icon: (issue.isSubscribed ?? false)
                ? Icons.notifications_active
                : Icons.notifications_none,
            tooltip: (issue.isSubscribed ?? false)
                ? 'Unsubscribe from this work item'
                : 'Subscribe to this work item',
            onPressed: _toggleSubscription,
          ),
          M3EAppBarAction(
              icon: Icons.share_outlined,
              tooltip: 'Share',
              onPressed: () => _shareIssue(issue)),
          M3EAppBarAction(
              icon: Icons.more_horiz,
              tooltip: 'More',
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
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        Text(
                          'Created ${_timeAgoFromDate(issue.createdAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Title
                    Text(issue.name, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: _sectionGap),
                    // Properties. This block had no header, which is most of
                    // why it read as leftovers under the title rather than as
                    // a group — every other block on the screen has one.
                    _DetailSection(
                      title: 'Properties',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            // Zero, not 6. Every child here is a 48dp target
                            // around a ~28dp pill, so a run already carries
                            // 10dp of clear space at each edge; adding
                            // runSpacing on top of that is what made the gaps
                            // between rows read as bigger than the gaps
                            // between whole sections.
                            runSpacing: 0,
                            children: _propertyChips(issue, state, issueLabels,
                                issueMembers, secondary),
                          ),
                          // Archived and overdue are states of the work item,
                          // not properties of it, but they belong to this
                          // block rather than trailing off the end of the chip
                          // Wrap at two different offsets as they used to.
                          //
                          // An archived work item is still fully editable
                          // through this screen, so saying so is not optional:
                          // otherwise every edit looks like it is going
                          // somewhere it is not.
                          if (issue.isArchived || issue.isOverdue)
                            Wrap(
                              spacing: 14,
                              runSpacing: 4,
                              children: [
                                if (issue.isArchived)
                                  _StatusFlag(
                                    icon: Icons.archive_outlined,
                                    label: 'Archived',
                                    color: secondary,
                                  ),
                                if (issue.isOverdue)
                                  const _StatusFlag(
                                    icon: Icons.error_outline,
                                    label: 'Overdue',
                                    color: PlaneTheme.urgent,
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    // Assignees are their own block now. As a bare labelMedium
                    // line wedged between the chips and the description they
                    // were the one heading on the screen that did not look
                    // like a heading.
                    if (issueMembers.isNotEmpty) ...[
                      _gap(afterTargets: propertiesEndInTargets),
                      _DetailSection(
                        title: 'Assignees',
                        count: issueMembers.length,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: issueMembers
                              .map((m) => _AssigneeChip(member: m))
                              .toList(),
                        ),
                      ),
                    ],
                    // Description
                    if (hasDescription) ...[
                      _gap(
                          afterTargets:
                              issueMembers.isEmpty && propertiesEndInTargets),
                      MarkdownBody(
                        data: htmlToMarkdown(issue.descriptionHtml!),
                        styleSheet: MarkdownStyleSheet(
                          p: theme.textTheme.bodyMedium,
                          h1: theme.textTheme.headlineSmall,
                          h2: theme.textTheme.titleLarge,
                          h3: theme.textTheme.titleMedium,
                          code: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.08)),
                          codeblockDecoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(M3EShape.large),
                          ),
                          blockquoteDecoration: BoxDecoration(
                            border: Border(
                                left: BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 3)),
                          ),
                          listBullet: theme.textTheme.bodyMedium,
                        ),
                        selectable: true,
                      ),
                      _gap(beforeTargets: true),
                    ] else
                      _gap(
                        afterTargets:
                            issueMembers.isEmpty && propertiesEndInTargets,
                        beforeTargets: true,
                      ),
                    // Reactions on the work item itself.
                    ReactionBar(
                      groups: groupReactions(_reactions, _currentUserId),
                      onToggle: _toggleIssueReaction,
                      targetDescription: 'this work item',
                    ),
                    _gap(afterTargets: true),
                    _buildSubIssuesSection(),
                    // Relations are shown even when empty, because the add
                    // control lives in the header — hiding the section when
                    // there is nothing in it is what made relations unaddable
                    // in the first place.
                    _gap(),
                    _buildRelationsSection(),
                    _gap(),
                    _buildAttachmentsSection(),
                    _gap(),
                    _buildLinksSection(),
                    _gap(),
                    _DetailSection(
                      title: 'Activity',
                      count:
                          activityItems.isEmpty ? null : activityItems.length,
                      child: activityItems.isEmpty
                          ? Text('No activity yet',
                              style: theme.textTheme.bodySmall)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: activityItems,
                            ),
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
              color: theme.colorScheme.surface.withValues(alpha: 0.80),
              border: Border(
                  top: BorderSide(
                      color: theme.colorScheme.outlineVariant, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              // The bar used to be a hand-rolled pill wrapped around a
              // borderless field, which put two outlines around one input.
              // The field carries its own now and the row just spaces it.
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    // The scheme role, not the dark constant of the same name:
                    // the raw one stayed near-black in light mode, so the
                    // comment bar carried a dark disc with a grey glyph on it.
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.person,
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: M3ETextField(
                      label: 'Comment',
                      hint: 'Add a comment...',
                      controller: _commentController,
                      compact: true,
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  M3EIconButton(
                    icon: Icons.attach_file,
                    tooltip: 'Attach a file',
                    size: M3EIconButtonSize.small,
                    // Disabled while one is in flight: the picker would
                    // happily start a second upload over the first.
                    onPressed:
                        _uploadingAttachment == null ? _attachFile : null,
                  ),
                  M3EIconButton(
                    icon: Icons.send,
                    tooltip: 'Add comment',
                    size: M3EIconButtonSize.small,
                    style: M3EIconButtonStyle.filled,
                    onPressed: _addComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Offers both ways to gain a sub-issue: make a new one, or adopt one that
  /// already exists.
  void _showAddSubIssueMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add, size: 20),
              title: Text('Create new sub-issue',
                  style: Theme.of(ctx).textTheme.bodyMedium),
              onTap: () {
                Navigator.pop(ctx);
                _addSubIssue();
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, size: 20),
              title: Text('Add existing work item',
                  style: Theme.of(ctx).textTheme.bodyMedium),
              onTap: () {
                Navigator.pop(ctx);
                _linkExistingSubIssue();
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Sub-issues section ---
  Widget _buildSubIssuesSection() {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    return _DetailSection(
      title: 'Sub-issues',
      count: _subIssues.isEmpty ? null : _subIssues.length,
      action: M3EIconButton(
        icon: Icons.add,
        tooltip: 'Add sub-issue',
        size: M3EIconButtonSize.extraSmall,
        color: secondary,
        onPressed: _showAddSubIssueMenu,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_subIssues.isEmpty)
            Text('No sub-issues', style: theme.textTheme.bodySmall)
          else
            ..._subIssues.map((sub) {
              final subState = _states[sub.state];
              return InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IssueDetailScreen(
                        workspaceSlug: widget.workspaceSlug,
                        projectId: widget.projectId,
                        issueId: sub.id,
                        // A child is in the same project, so the identifier this
                        // screen already resolved is the child's too — no reason
                        // to make it look it up again.
                        projectIdentifier: _projectIdentifier,
                        states: _states,
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
                            context, subState?.group ?? 'backlog'),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        PlaneTheme.priorityIcon(sub.priority),
                        size: 14,
                        color: PlaneTheme.priorityColor(context, sub.priority),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(sub.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall),
                      ),
                      M3EIconButton(
                        icon: Icons.close,
                        // Several of these sit in one list, so the label names
                        // which child it detaches.
                        tooltip: 'Remove sub-issue ${sub.name}',
                        size: M3EIconButtonSize.extraSmall,
                        color: secondary,
                        onPressed: () => _removeSubIssue(sub),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // --- Relations section ---
  Widget _buildRelationsSection() {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    return _DetailSection(
      title: 'Relations',
      count: _relations.isEmpty ? null : _relations.length,
      action: M3EIconButton(
        icon: Icons.add,
        tooltip: 'Add relation',
        size: M3EIconButtonSize.extraSmall,
        color: secondary,
        onPressed: _addRelation,
      ),
      child: _relations.isEmpty
          ? Text('No relations', style: theme.textTheme.bodySmall)
          : Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _relations.map((r) {
                // The server files each related issue under its relation kind
                // and returns the issue's own fields flat, so the name is on
                // the entry itself. The older nested `issue_detail` shape is
                // still read as a fallback in case an instance serialises it
                // that way.
                final relationType = r['relation_type'] ?? 'relates_to';
                final nested = r['issue_detail'] ?? r['related_issue_detail'];
                final issueName =
                    r['name'] ?? nested?['name'] ?? 'Unknown issue';
                return _RelationChip(
                  type: relationType,
                  issueName: issueName,
                  onRemove: () => _confirmRemoveRelation(r, issueName),
                );
              }).toList(),
            ),
    );
  }

  void _confirmRemoveRelation(Map<String, dynamic> relation, String name) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.link_off,
                  color: Theme.of(ctx).colorScheme.error, size: 20),
              title: Text('Remove relation to $name',
                  style: Theme.of(ctx)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Theme.of(ctx).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _removeRelation(relation);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Attachments section ---
  Widget _buildAttachmentsSection() {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    return _DetailSection(
      title: 'Attachments',
      count: _attachments.isEmpty ? null : _attachments.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The upload is a three-call round trip to object storage, so it is
          // long enough to need saying. It sits in the list rather than in a
          // toast, where the file will appear for real once it lands.
          if (_uploadingAttachment != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: secondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Uploading $_uploadingAttachment…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          if (_attachments.isEmpty && _uploadingAttachment == null)
            Text('No attachments', style: theme.textTheme.bodySmall)
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
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (a.displaySize.isNotEmpty)
                        Text(a.displaySize,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: secondary)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // --- Links section ---
  Widget _buildLinksSection() {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    return _DetailSection(
      title: 'Links',
      count: _links.isEmpty ? null : _links.length,
      action: M3EIconButton(
        icon: Icons.add,
        tooltip: 'Add link',
        size: M3EIconButtonSize.extraSmall,
        color: secondary,
        onPressed: _showAddLinkDialog,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_links.isEmpty)
            Text('No links', style: theme.textTheme.bodySmall)
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
                        Icon(Icons.link,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                link.title ?? link.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              if (link.title != null && link.title!.isNotEmpty)
                                Text(
                                  link.url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(color: secondary),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
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
            M3ETextField(
              label: 'Title',
              controller: titleController,
            ),
            const SizedBox(height: 12),
            M3ETextField(
              label: 'URL',
              hint: 'https://',
              controller: urlController,
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

  /// Names the author of a comment.
  ///
  /// The token API serialises a comment's actor as a bare id and sends no
  /// `actor_detail`, so the model's own fallback yields a raw UUID. Resolving
  /// the id against the project member list is what turns that back into a
  /// person; 'Unknown' is better than a UUID when it cannot be resolved.
  String _resolveCommentAuthor(Comment c) {
    final id = c.actor ?? c.createdBy;
    if (id != null) {
      for (final m in _allMembers) {
        if (m.id == id) {
          return m.displayName.isNotEmpty ? m.displayName : m.email;
        }
      }
    }
    final detail = c.actorDetail;
    // The model falls back to created_by, which is the very UUID just failed
    // to resolve — do not render that at people.
    if (detail != null && detail != id && detail.isNotEmpty) return detail;
    return 'Unknown';
  }

  List<Widget> _buildActivityItems() {
    final items = <_ActivityEntry>[];

    // Add comments
    for (final c in _comments) {
      // Only the author is offered edit and delete. See
      // CommentService.canModify for why the project-admin half of the
      // server's rule is not reproduced here.
      final mine = CommentService.canModify(c, _currentUserId);
      items.add(_ActivityEntry(
        date: c.createdAt,
        widget: _CommentCard(
          comment: c,
          authorName: _resolveCommentAuthor(c),
          reactionGroups: groupReactions(c.reactions, _currentUserId),
          onToggleReaction: (code) => _toggleCommentReaction(c, code),
          onEdit: mine && _commentIsPlainParagraph(c)
              ? () => _editComment(c)
              : null,
          onDelete: mine ? () => _deleteComment(c) : null,
        ),
      ));
    }

    // Add activities (skip empty ones and comment-type)
    for (final a in _activities) {
      if (a.field == 'comment') continue;
      items.add(_ActivityEntry(
        date: a.createdAt,
        widget:
            _ActivityCard(activity: a, resolvedActorName: _resolveActorName(a)),
      ));
    }

    // Sort by date descending (newest first)
    items.sort((a, b) => b.date.compareTo(a.date));

    return items.map((e) => e.widget).toList();
  }

  // --- More menu with delete ---
  void _showMoreMenu() {
    final archived = _issue?.isArchived ?? false;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (archived)
              ListTile(
                leading: const Icon(Icons.unarchive_outlined, size: 20),
                title: Text('Restore from archive',
                    style: Theme.of(ctx).textTheme.bodyMedium),
                onTap: () {
                  Navigator.pop(ctx);
                  _unarchiveIssue();
                },
              )
            else
              ListTile(
                enabled: _canArchive,
                leading: Icon(Icons.archive_outlined,
                    size: 20,
                    color: _canArchive ? null : Theme.of(ctx).disabledColor),
                title: Text('Archive work item',
                    style: Theme.of(ctx).textTheme.bodyMedium),
                // The server refuses to archive anything that is not finished,
                // so say that here rather than letting the tap fail.
                subtitle: _canArchive
                    ? null
                    : Text(
                        'Only completed or cancelled work items can be archived',
                        style: Theme.of(ctx).textTheme.bodySmall),
                onTap: _canArchive
                    ? () {
                        Navigator.pop(ctx);
                        _archiveIssue();
                      }
                    : null,
              ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error, size: 20),
              title: Text('Delete issue',
                  style: Theme.of(ctx)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Theme.of(ctx).colorScheme.error)),
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
        content: const Text('Are you sure you want to delete this issue?'),
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
            child: Text('Delete',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
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
          children: _states.values
              .map((s) => ListTile(
                    leading: Icon(PlaneTheme.stateIcon(s.group),
                        color: PlaneTheme.stateGroupColor(context, s.group),
                        size: 18),
                    title:
                        Text(s.name, style: Theme.of(ctx).textTheme.bodyMedium),
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
                        color: PlaneTheme.priorityColor(context, p), size: 18),
                    title: Text(p[0].toUpperCase() + p.substring(1),
                        style: Theme.of(ctx).textTheme.bodyMedium),
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
      '#ef4444',
      '#f97316',
      '#eab308',
      '#22c55e',
      '#06b6d4',
      '#3b82f6',
      '#8b5cf6',
      '#ec4899',
      '#6b7280',
      '#0ea5e9',
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
              M3ETextField(
                label: 'Label name',
                controller: nameController,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Wrap(
                // A swatch is pure colour — the hex is the only stable name
                // it has, and selection is otherwise only a border.
                children: colors
                    .map((c) => Semantics(
                          label: 'Select label colour $c',
                          button: true,
                          selected: selectedColor == c,
                          container: true,
                          child: GestureDetector(
                            onTap: () =>
                                setDialogState(() => selectedColor = c),
                            // 28dp circle, 48dp target: a swatch is still a control.
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: _parseColor(c),
                                    shape: BoxShape.circle,
                                    border: selectedColor == c
                                        ? Border.all(
                                            color: Theme.of(ctx)
                                                .colorScheme
                                                .onSurface,
                                            width: 2)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
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
        _allLabels = await _tryLoad(
            () =>
                LabelService.getLabels(widget.workspaceSlug, widget.projectId),
            <Label>[]);
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
                    Text('Labels', style: Theme.of(ctx).textTheme.titleMedium),
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No labels yet',
                      style: Theme.of(ctx).textTheme.bodySmall),
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
                        Text(l.name, style: Theme.of(ctx).textTheme.bodyMedium),
                    controlAffinity: ListTileControlAffinity.trailing,
                    dense: true,
                  )),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add, size: 20),
                title: Text('Create new label',
                    style: Theme.of(ctx).textTheme.bodyMedium),
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
                    Text('Assignees',
                        style: Theme.of(ctx).textTheme.titleMedium),
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No members found',
                      style: Theme.of(ctx).textTheme.bodySmall),
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
                        style: Theme.of(ctx).textTheme.bodyMedium),
                    subtitle: m.email.isNotEmpty
                        ? Text(m.email,
                            style: Theme.of(ctx).textTheme.bodySmall)
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
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.primary),
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

/// A titled block of the work item screen.
///
/// Six of these existed as hand-rolled `Row(Text, count, Spacer, action)`
/// headers, each with its own spacing underneath. Sharing one widget is what
/// turns six near-misses into a rhythm, and it is what lets the property block
/// become a section like the others instead of a loose pile of chips under the
/// title.
class _DetailSection extends StatelessWidget {
  final String title;

  /// Shown beside the title. Null hides it, which is how a section with
  /// nothing in it avoids announcing a zero.
  final int? count;

  /// Trailing control, usually the section's add button.
  ///
  /// It sits as a sibling of the title rather than nested inside anything
  /// pressable: [M3EPressable] replaces its subtree's semantics, so a labelled
  /// button inside one disappears from the accessibility tree entirely.
  final Widget? action;

  final Widget child;

  const _DetailSection({
    required this.title,
    required this.child,
    this.count,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: theme.textTheme.labelLarge?.copyWith(color: secondary)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text('$count', style: theme.textTheme.bodySmall),
            ],
            if (action != null) ...[
              const Spacer(),
              action!,
            ],
          ],
        ),
        const SizedBox(height: _headerGap),
        child,
      ],
    );
  }
}

/// An icon-and-word note about the work item as a whole — archived, overdue.
///
/// Not a chip: these are not editable and must not look like the property
/// pills they sit under.
class _StatusFlag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusFlag({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: PlaneTheme.iconSmall, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color)),
      ],
    );
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

  /// Opens the remove sheet. Null on a chip that is only being displayed.
  final VoidCallback? onRemove;

  const _RelationChip({
    required this.type,
    required this.issueName,
    this.onRemove,
  });

  static IconData iconFor(String type) {
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

  static String labelFor(String type) {
    switch (type) {
      case 'blocking':
        return 'Blocking';
      case 'blocked_by':
        return 'Blocked by';
      case 'duplicate':
        return 'Duplicate of';
      case 'relates_to':
        return 'Relates to';
      // The server also stores date-dependency relations, which this app does
      // not create but must still be able to name if it reads one back.
      case 'start_after':
        return 'Starts after';
      case 'start_before':
        return 'Starts before';
      case 'finish_after':
        return 'Finishes after';
      case 'finish_before':
        return 'Finishes before';
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
    final label = labelFor(type);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(M3EShape.full),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
        color: color.withValues(alpha: 0.05),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(type), size: 13, color: color),
          const SizedBox(width: 4),
          Text('$label: ',
              style: theme.textTheme.labelSmall?.copyWith(color: color)),
          Flexible(
            child: Text(issueName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: color)),
          ),
        ],
      ),
    );

    if (onRemove == null) return chip;
    return Semantics(
      label: '$label $issueName. Tap to remove this relation',
      button: true,
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(M3EShape.full),
        child: chip,
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
      if (newVal != null && newVal.isNotEmpty) {
        return '$actor set $fieldName to $newVal';
      }
      return '$actor created the issue';
    }
    if (verb == 'updated') {
      if (oldVal != null &&
          oldVal.isNotEmpty &&
          newVal != null &&
          newVal.isNotEmpty) {
        return '$actor changed $fieldName from $oldVal to $newVal';
      }
      if (newVal != null && newVal.isNotEmpty) {
        return '$actor set $fieldName to $newVal';
      }
      if (oldVal != null && oldVal.isNotEmpty) {
        return '$actor removed $fieldName $oldVal';
      }
      return '$actor updated $fieldName';
    }
    if (verb == 'deleted') {
      return '$actor removed $fieldName${oldVal != null ? ' $oldVal' : ''}';
    }
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
          Icon(_icon,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _description,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  timeAgo(activity.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
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
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(M3EShape.full),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
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
          Text(label.name, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );

    if (onTap == null) return pill;

    return Semantics(
      // The pill renders only the label's name, which says nothing about the
      // fact that touching it opens the label picker. Several of these sit in
      // one row, so the name has to stay in the composed label to keep them
      // distinguishable to anything driving the app by label.
      label: 'Label ${label.name}. Tap to edit labels',
      button: true,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: M3EPressable(
        pressedScale: 0.94,
        onTap: onTap,
        // Matches PropertyChip exactly: a 48dp target with the pill centred in
        // it. These share a Wrap with the property chips, and a 22dp pill
        // beside a 48dp one is what made those rows look ragged.
        child: SizedBox(
          height: 48,
          child: Center(widthFactor: 1.0, child: pill),
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
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            child: Text(
              (member.displayName.isNotEmpty ? member.displayName : '?')[0]
                  .toUpperCase(),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
        const SizedBox(width: 5),
        Text(member.displayName, style: theme.textTheme.labelMedium),
      ],
    );
  }
}

// --- Comment card ---
class _CommentCard extends StatelessWidget {
  final Comment comment;
  final String authorName;

  /// Null when the current user may not edit this comment, or when its markup
  /// is richer than the plain-text editor can round-trip.
  final VoidCallback? onEdit;

  /// Null when the current user did not write this comment.
  final VoidCallback? onDelete;

  /// Reactions already collapsed per emoji.
  final List<ReactionGroup> reactionGroups;

  final void Function(String code) onToggleReaction;

  const _CommentCard({
    required this.comment,
    required this.authorName,
    required this.reactionGroups,
    required this.onToggleReaction,
    this.onEdit,
    this.onDelete,
  });

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined, size: 20),
                title: Text('Edit comment',
                    style: Theme.of(ctx).textTheme.bodyMedium),
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit!();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(ctx).colorScheme.error, size: 20),
                title: Text('Delete comment',
                    style: Theme.of(ctx)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(ctx).colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canModify = onEdit != null || onDelete != null;
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
                  (authorName.isNotEmpty ? authorName : '?')[0].toUpperCase(),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall),
              ),
              const SizedBox(width: 8),
              Text(timeAgo(comment.createdAt),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              // An edited comment is no longer what anyone was notified about,
              // so say so rather than letting the change pass silently.
              if (comment.editedAt != null) ...[
                const SizedBox(width: 6),
                Text('(edited)',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
              const Spacer(),
              if (canModify)
                // The author's name is in the row, so the label has to name
                // which comment this acts on — several of these cards sit in
                // the same list and 'Comment actions' alone would be ambiguous
                // to anything driving the app by label.
                M3EIconButton(
                  icon: Icons.more_horiz,
                  tooltip: 'Actions for comment by $authorName',
                  size: M3EIconButtonSize.extraSmall,
                  color: theme.colorScheme.onSurfaceVariant,
                  onPressed: () => _showActions(context),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 4),
            child: Text(
              comment.commentHtml?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ??
                  '',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 6),
            child: ReactionBar(
              groups: reactionGroups,
              onToggle: onToggleReaction,
              // Names whose comment, so the add button is distinguishable
              // from the one on every other card in the feed.
              targetDescription: 'comment by $authorName',
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// A searchable list of the project's work items, returning the chosen one.
///
/// Used for relations and for adopting an existing sub-issue. It loads one
/// page and filters in memory rather than querying per keystroke: the list
/// endpoint has no name filter on this transport, and a project small enough
/// to work with on a phone fits in a page.
class _IssuePickerSheet extends StatefulWidget {
  final String title;
  final String workspaceSlug;
  final String projectId;

  /// Work items that must not be offered — this work item itself, and
  /// whatever is already related or already a child. Offering them produces a
  /// duplicate the server silently ignores, which looks like the tap failed.
  final Set<String> excludeIds;

  final Map<String, IssueState> states;

  const _IssuePickerSheet({
    required this.title,
    required this.workspaceSlug,
    required this.projectId,
    required this.excludeIds,
    required this.states,
  });

  @override
  State<_IssuePickerSheet> createState() => _IssuePickerSheetState();
}

class _IssuePickerSheetState extends State<_IssuePickerSheet> {
  final _searchController = TextEditingController();
  List<Issue> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await IssueService.getIssues(
        widget.workspaceSlug,
        widget.projectId,
        perPage: 100,
      );
      if (!mounted) return;
      setState(() {
        _all = (result['issues'] as List<Issue>)
            .where((i) => !widget.excludeIds.contains(i.id))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load work items: $e';
        _loading = false;
      });
    }
  }

  List<Issue> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _filtered;

    return SafeArea(
      child: Padding(
        // Lifts the sheet clear of the keyboard the search field summons.
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.title,
                          style: theme.textTheme.titleMedium),
                    ),
                    M3EIconButton(
                      icon: Icons.close,
                      tooltip: 'Cancel',
                      size: M3EIconButtonSize.small,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: M3ETextField(
                  label: 'Search work items',
                  hint: 'Search by title...',
                  controller: _searchController,
                  compact: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(_error!,
                                  style: theme.textTheme.bodySmall),
                            ),
                          )
                        : results.isEmpty
                            ? Center(
                                child: Text('No matching work items',
                                    style: theme.textTheme.bodySmall),
                              )
                            : ListView.builder(
                                itemCount: results.length,
                                itemBuilder: (ctx, i) {
                                  final issue = results[i];
                                  final state = widget.states[issue.state];
                                  return ListTile(
                                    leading: Icon(
                                      PlaneTheme.stateIcon(
                                          state?.group ?? 'backlog'),
                                      size: 18,
                                      color: PlaneTheme.stateGroupColor(
                                          ctx, state?.group ?? 'backlog'),
                                    ),
                                    title: Text(
                                      issue.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    onTap: () => Navigator.pop(context, issue),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
