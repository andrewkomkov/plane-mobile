import 'package:flutter/material.dart';
import '../../config/m3e/shapes.dart';
import '../../config/m3e/motion.dart';
import '../../config/m3e/typography.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/loading_indicator.dart';
import '../../widgets/m3e/text_field.dart';
import '../../config/theme.dart';
import '../../models/draft_issue.dart';
import '../../services/draft_issue_service.dart';
import '../../services/issue_service.dart';
import '../../models/state.dart';

/// What the screen did before it closed, so the list underneath knows which of
/// its listings went stale.
///
/// The two are different lists behind different endpoints: promoting a draft
/// changes both, saving one changes only the drafts listing. Returning a bare
/// bool would make the caller refetch both every time or guess.
enum IssueCreateOutcome {
  /// A draft was created or edited. The drafts listing is stale.
  draftSaved,

  /// A draft was discarded. The drafts listing is stale.
  draftDiscarded,

  /// A real work item exists now. Both listings are stale — promoting also
  /// destroys the draft it came from.
  issueCreated,
}

/// Composes a work item, and — when handed a [draft] — edits one that was
/// saved earlier.
///
/// The two are the same form. A draft holds the same fields a new work item
/// does and Plane's own web client uses one modal for both, so splitting this
/// into two screens would mean every field added to one having to be added to
/// the other, or quietly not being.
class IssueCreateScreen extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;
  final Map<String, IssueState> states;
  final String? parentIssueId;

  /// The draft being edited. Null composes a new work item.
  final DraftIssue? draft;

  const IssueCreateScreen({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.states,
    this.parentIssueId,
    this.draft,
  });

  @override
  State<IssueCreateScreen> createState() => _IssueCreateScreenState();
}

/// Which of the screen's writes is in flight. Two actions share the bar, so a
/// single boolean could not say which one to put the spinner on.
enum _Busy { savingDraft, creating, discarding }

class _IssueCreateScreenState extends State<IssueCreateScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedState;
  String _selectedPriority = 'medium';
  _Busy? _busy;

  DraftIssue? get _draft => widget.draft;
  bool get _isEditingDraft => _draft != null;
  bool get _saving => _busy != null;

  /// Whether the draft arrived holding markup this plain-text editor cannot
  /// represent, and would therefore destroy on save.
  bool _draftHasRichText = false;

  @override
  void initState() {
    super.initState();
    final draft = _draft;
    if (draft != null) {
      _nameController.text = draft.issue.name;
      _descController.text = _plainTextFromHtml(draft.issue.descriptionHtml);
      _draftHasRichText = _hasRichMarkup(draft.issue.descriptionHtml);
      _selectedPriority = draft.issue.priority;
      // A draft's state may point at a state this screen was not given — the
      // command palette passes an empty map. Only adopt one that is present,
      // so the picker never shows a selection it cannot name.
      if (draft.issue.state != null &&
          widget.states.containsKey(draft.issue.state)) {
        _selectedState = draft.issue.state;
      }
    }
    _selectedState ??= widget.states.values
            .where((s) => s.group == 'unstarted')
            .firstOrNull
            ?.id ??
        widget.states.values.firstOrNull?.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// Flattens a draft's stored HTML into what this editor can hold.
  ///
  /// The description field is plain text and [_descriptionHtml] wraps whatever
  /// it holds in a single paragraph. A draft written on the web can carry real
  /// rich text, so opening one here has to flatten it — and saving would then
  /// flatten it permanently, which is what [_draftHasRichText] warns about.
  /// Block ends become newlines so paragraphs survive as paragraphs.
  static String _plainTextFromHtml(String? html) {
    if (html == null || html.isEmpty) return '';
    var text = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
            RegExp(r'</(p|div|li|h[1-6]|blockquote)>', caseSensitive: false),
            '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '');
    // `&amp;` last: decoding it first would turn `&amp;lt;` into a `<`.
    const entities = {
      '&nbsp;': ' ',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&amp;': '&',
    };
    entities.forEach((entity, char) => text = text.replaceAll(entity, char));
    return text.trim();
  }

  /// True when the markup is more than the single paragraph this screen writes.
  static bool _hasRichMarkup(String? html) {
    if (html == null || html.isEmpty) return false;
    final tags = RegExp(r'<\s*/?\s*([a-zA-Z0-9]+)')
        .allMatches(html)
        .map((m) => m.group(1)!.toLowerCase())
        .toSet();
    tags.remove('p');
    tags.remove('br');
    return tags.isNotEmpty;
  }

  String get _name => _nameController.text.trim();

  /// The description as the server stores it. Empty text still writes a
  /// paragraph, because that is Plane's own default and an omitted key would
  /// leave a cleared description standing.
  String get _descriptionHtml {
    final desc = _descController.text.trim();
    return desc.isEmpty ? '<p></p>' : '<p>$desc</p>';
  }

  /// The form's contents, in the model's own key vocabulary. Both services
  /// translate to the server's write names on the way out.
  Map<String, dynamic> _formFields() => {
        'name': _name,
        'description_html': _descriptionHtml,
        if (_selectedState != null) 'state': _selectedState,
        'priority': _selectedPriority,
        if (widget.parentIssueId != null) 'parent': widget.parentIssueId,
      };

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(
      _Busy busy, Future<IssueCreateOutcome> Function() work) async {
    if (_saving) return;
    setState(() => _busy = busy);
    try {
      final outcome = await work();
      if (mounted) Navigator.pop(context, outcome);
    } catch (e) {
      if (mounted) setState(() => _busy = null);
      _report('Error: $e');
    }
  }

  /// The primary action: a real work item, either from scratch or out of the
  /// draft on screen.
  Future<void> _create() async {
    if (_name.isEmpty) {
      _report('A work item needs a title');
      return;
    }
    final draft = _draft;
    if (draft == null) {
      await _run(_Busy.creating, () async {
        await IssueService.createIssue(
          widget.workspaceSlug,
          widget.projectId,
          _formFields(),
        );
        return IssueCreateOutcome.issueCreated;
      });
      return;
    }

    if (draft.issue.project == null) {
      // `create_draft_to_issue` refuses outright; say so rather than let it 400.
      _report('This draft has no project and cannot become a work item');
      return;
    }
    await _run(_Busy.creating, () async {
      // Unsaved edits ride along as overrides rather than being PATCHed first:
      // promotion deletes the draft, so a separate save would be a write to a
      // row that is about to stop existing.
      await DraftIssueService.promoteDraft(
        widget.workspaceSlug,
        draft,
        overrides: _formFields(),
      );
      return IssueCreateOutcome.issueCreated;
    });
  }

  /// Saves the form as a draft — new, or over the one being edited.
  Future<void> _saveDraft() async {
    final draft = _draft;
    // A draft's name is nullable server-side, so an untitled one is allowed
    // here even though a work item's is not.
    if (draft == null) {
      await _run(_Busy.savingDraft, () async {
        await DraftIssueService.createDraft(
          widget.workspaceSlug,
          widget.projectId,
          _formFields(),
        );
        return IssueCreateOutcome.draftSaved;
      });
      return;
    }
    await _run(_Busy.savingDraft, () async {
      await DraftIssueService.updateDraft(
        widget.workspaceSlug,
        draft.id,
        // The draft's own project, not the screen's — they are the same today
        // because the list that opens this filters by project, but the field
        // the serialiser validates against should come from the row.
        draft.issue.project ?? widget.projectId,
        _formFields(),
      );
      return IssueCreateOutcome.draftSaved;
    });
  }

  Future<void> _discardDraft() async {
    final draft = _draft;
    if (draft == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard draft?'),
        content: const Text(
            'This draft will be deleted. Plane offers no way to bring it back.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(_Busy.discarding, () async {
      await DraftIssueService.deleteDraft(widget.workspaceSlug, draft.id);
      return IssueCreateOutcome.draftDiscarded;
    });
  }

  IssueState? get _currentState =>
      _selectedState != null ? widget.states[_selectedState] : null;

  String get _screenTitle {
    if (_isEditingDraft) return 'Edit draft';
    return widget.parentIssueId != null ? 'New Sub-issue' : 'New Issue';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hintColor = scheme.onSurfaceVariant.withValues(alpha: 0.6);

    return Scaffold(
      appBar: M3EAppBar(
        title: _screenTitle,
        leading: M3EAppBarAction(
          icon: Icons.close,
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Two pills in a fixed order, in both modes. The same word does the
          // same thing whether or not a draft is open: "Create" ends with a
          // work item, "Save draft" ends with a draft.
          _BarAction(
            label: 'Save draft',
            semanticLabel: _isEditingDraft ? 'Save draft' : 'Save as draft',
            emphasized: false,
            busy: _busy == _Busy.savingDraft,
            onTap: _saving ? null : _saveDraft,
          ),
          _BarAction(
            label: 'Create',
            semanticLabel: _isEditingDraft
                ? 'Create work item from draft'
                : 'Create work item',
            emphasized: true,
            busy: _busy == _Busy.creating,
            onTap: _saving ? null : _create,
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
            if (_draftHasRichText) ...[
              const SizedBox(height: 12),
              const _RichTextWarning(),
            ],
            const SizedBox(height: 24),
            // Status & Priority row
            Row(
              children: [
                Expanded(
                  // The card reads as an input but is a raw GestureDetector:
                  // it announced "STATUS Backlog" with no button role, and
                  // deferToChild meant only the glyphs answered a tap, not the
                  // 16dp of padding that looks like part of the control.
                  child: Semantics(
                    label: 'Status: ${_currentState?.name ?? 'Backlog'}. '
                        'Change status',
                    button: true,
                    container: true,
                    excludeSemantics: true,
                    onTap: _showStatePicker,
                    child: GestureDetector(
                      onTap: () => _showStatePicker(),
                      behavior: HitTestBehavior.opaque,
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
                                        ? PlaneTheme.stateGroupColor(
                                            context, _currentState!.group)
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
                                    size: 18, color: scheme.onSurfaceVariant),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  // Same treatment as the status card beside it.
                  child: Semantics(
                    label: 'Priority: '
                        '${_selectedPriority[0].toUpperCase()}'
                        '${_selectedPriority.substring(1)}. Change priority',
                    button: true,
                    container: true,
                    excludeSemantics: true,
                    onTap: _showPriorityPicker,
                    child: GestureDetector(
                      onTap: () => _showPriorityPicker(),
                      behavior: HitTestBehavior.opaque,
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
                                  color: PlaneTheme.priorityColor(
                                      context, _selectedPriority),
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
                                    size: 18, color: scheme.onSurfaceVariant),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Discarding sits at the far end of the form rather than in the
            // app bar: it is irreversible, and it has no business being a
            // thumb's width from the two buttons that save.
            if (_isEditingDraft) ...[
              const SizedBox(height: 32),
              _DiscardDraftButton(
                busy: _busy == _Busy.discarding,
                onTap: _saving ? null : _discardDraft,
              ),
            ],
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
              child: Text('Status', style: Theme.of(ctx).textTheme.titleLarge),
            ),
            ...widget.states.values.map((s) => ListTile(
                  leading: Icon(
                    PlaneTheme.stateIcon(s.group),
                    size: 18,
                    color: PlaneTheme.stateGroupColor(context, s.group),
                  ),
                  title:
                      Text(s.name, style: Theme.of(ctx).textTheme.bodyMedium),
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
              child:
                  Text('Priority', style: Theme.of(ctx).textTheme.titleLarge),
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

/// A text action in the app bar, sized to its word.
///
/// The bar carries two of these and its title is what gives way, so they keep
/// their intrinsic width and never wrap. The visible text is short; the
/// announced name says what the tap will produce, because "Create" alone does
/// not distinguish making a work item from making one out of a draft.
class _BarAction extends StatelessWidget {
  final String label;
  final String semanticLabel;
  final bool emphasized;
  final bool busy;
  final VoidCallback? onTap;

  const _BarAction({
    required this.label,
    required this.semanticLabel,
    required this.emphasized,
    required this.busy,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background =
        emphasized ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final foreground =
        emphasized ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 6),
      child: busy
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: M3ELoadingIndicator(size: 22),
            )
          : M3EPressable(
              pressedScale: 0.92,
              semanticLabel: semanticLabel,
              onTap: onTap,
              // The pill draws at about 38dp. M3EPressable hit-tests opaquely
              // over whatever child it is given, so centring the pill in a
              // 48dp box buys the touch-target minimum without changing what
              // is painted — and the 56dp app bar has the room already.
              child: SizedBox(
                height: kMinInteractiveDimension,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: onTap == null
                          ? background.withValues(alpha: 0.4)
                          : background,
                      borderRadius: BorderRadius.circular(M3EShape.full),
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Says out loud that saving will cost the draft its formatting.
///
/// The alternative was to refuse to open a rich draft at all, which would put
/// the app back where it started — drafts made on the web being unreachable.
class _RichTextWarning extends StatelessWidget {
  const _RichTextWarning();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(M3EShape.medium),
        border: Border.all(color: scheme.outlineVariant, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This draft was written with formatting. Saving it here keeps '
              'the text and drops the formatting.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscardDraftButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onTap;

  const _DiscardDraftButton({required this.busy, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: M3EPressable(
        pressedScale: 0.96,
        semanticLabel: 'Discard draft',
        onTap: onTap,
        // Roughly 42dp of pill in a 48dp hit box. The pressable is opaque, so
        // the extra 6dp are tappable without the outline growing to meet them.
        child: SizedBox(
          height: kMinInteractiveDimension,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(M3EShape.full),
                border: Border.all(
                    color: scheme.error.withValues(alpha: 0.4), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    const M3ELoadingIndicator(size: 16)
                  else
                    Icon(Icons.delete_outline, size: 18, color: scheme.error),
                  const SizedBox(width: 8),
                  Text(
                    'Discard draft',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: scheme.error),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
