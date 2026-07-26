import 'issue.dart';

/// A draft work item.
///
/// Plane keeps drafts in their own table, not as work items with a flag set.
/// `Issue.is_draft` still exists in the internal serialiser's field list and is
/// still excluded by `IssueManager`, but nothing writes it any more: migration
/// 0077 moved every `is_draft=True` row into `DraftIssue` and the field is now
/// dead weight on the work-item model. A draft therefore has its own id space,
/// its own endpoints, and — importantly — no `sequence_id` in any response, so
/// it can never render as `PLM-123`.
///
/// The overlap with a work item is otherwise near-total: `DraftIssueSerializer`
/// emits the same id-suffixed names (`state_id`, `assignee_ids`, `label_ids`,
/// `parent_id`) that [Issue.fromJson] already reads. So the draft's contents
/// are parsed as an [Issue] and this type carries what is true of the *draft*
/// rather than of the work item inside it.
class DraftIssue {
  /// The draft's contents, parsed with the work-item parser.
  ///
  /// Faithful to what the server holds, including an empty name — see
  /// [rowIssue] for the display substitution.
  final Issue issue;

  const DraftIssue({required this.issue});

  factory DraftIssue.fromJson(Map<String, dynamic> json) =>
      DraftIssue(issue: Issue.fromJson(json));

  /// The draft's own id, which addresses `draft-issues/{id}/`. Not a work-item
  /// id — nothing on the `issues/` routes will find it.
  String get id => issue.id;

  /// What an unnamed draft is called on screen.
  static const String untitled = 'Untitled draft';

  bool get hasName => issue.name.trim().isNotEmpty;

  /// Whether `draft-to-issue/` will accept this draft.
  ///
  /// Two server-side refusals, checked here so the app can say why instead of
  /// surfacing a 400. `create_draft_to_issue` returns "Project is required to
  /// create an issue." for a project-less draft, and the `IssueCreateSerializer`
  /// it then runs requires a name.
  bool get canPromote => issue.project != null && hasName;

  /// The draft as something [IssueRow] can title itself from.
  ///
  /// `DraftIssue.name` is nullable server-side and Plane's own draft modal
  /// saves without one, so a blank title is a shape the app will meet. A row
  /// with no text is unreadable and — because automation locates rows by their
  /// accessible name — untappable. The stand-in is substituted only here;
  /// [issue] keeps the empty name so the editor does not open with
  /// "Untitled draft" already typed into the field.
  Issue get rowIssue => hasName
      ? issue
      : Issue(
          id: issue.id,
          name: untitled,
          descriptionHtml: issue.descriptionHtml,
          state: issue.state,
          priority: issue.priority,
          sequenceId: issue.sequenceId,
          assignees: issue.assignees,
          labels: issue.labels,
          createdAt: issue.createdAt,
          updatedAt: issue.updatedAt,
          project: issue.project,
          startDate: issue.startDate,
          targetDate: issue.targetDate,
          parent: issue.parent,
          estimatePoint: issue.estimatePoint,
          cycleId: issue.cycleId,
          moduleIds: issue.moduleIds,
        );

  /// The body that `draft-to-issue/{id}/` needs to build the work item.
  ///
  /// The endpoint does **not** copy the draft. It reads `request.data` into a
  /// fresh `IssueCreateSerializer` and takes only the project and workspace
  /// from the draft row, then deletes it. Send an empty body and you get an
  /// empty work item and a destroyed draft, which is the worst outcome
  /// available — so every field the draft holds is re-sent here.
  ///
  /// Keys stay in the model's own vocabulary; [DraftIssueService] translates
  /// them to the write names, exactly as `Issue.toCreateJson` does.
  /// `cycle_id` and `module_ids` are the exceptions and are already spelled the
  /// way the server wants: the view pulls those two straight out of
  /// `request.data` and creates the join rows itself, bypassing the serialiser.
  Map<String, dynamic> toPromoteJson() {
    final description = issue.descriptionHtml;
    return {
      'name': issue.name,
      if (description != null && description.isNotEmpty)
        'description_html': description,
      if (issue.state != null) 'state': issue.state,
      'priority': issue.priority,
      if (issue.assignees.isNotEmpty) 'assignees': issue.assignees,
      if (issue.labels.isNotEmpty) 'labels': issue.labels,
      if (issue.startDate != null) 'start_date': issue.startDate,
      if (issue.targetDate != null) 'target_date': issue.targetDate,
      if (issue.parent != null) 'parent': issue.parent,
      // Not renamed: `IssueCreateSerializer` takes `fields = "__all__"` off the
      // Issue model, where the foreign key is plain `estimate_point`.
      if (issue.estimatePoint != null) 'estimate_point': issue.estimatePoint,
      if (issue.cycleId != null) 'cycle_id': issue.cycleId,
      if (issue.moduleIds.isNotEmpty) 'module_ids': issue.moduleIds,
    };
  }
}
