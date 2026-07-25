import 'package:flutter/material.dart';
import '../config/m3e/motion.dart';
import '../config/m3e/shapes.dart';
import '../config/theme.dart';
import '../models/issue.dart';
import '../models/label.dart';
import '../models/member.dart';
import '../models/state.dart';

/// Universal issue row widget used across all screens.
/// Matches mockup: rounded dark card, ID in gray, state icon, priority icon.
class IssueTile extends StatelessWidget {
  final Issue issue;
  final IssueState? state;
  final String? projectIdentifier;
  final String? subtitle;
  final bool showId;
  final bool showProject;
  final bool showAssignee;
  final bool showDueDate;
  final bool showPriority;
  final bool showState;
  final bool showLabels;
  final bool showSubIssues;
  final bool isUnread;
  final String? timeAgo;
  final int maxTitleLines;
  final VoidCallback onTap;
  final List<Label> allLabels;
  final List<Member> allMembers;

  const IssueTile({
    super.key,
    required this.issue,
    this.state,
    this.projectIdentifier,
    this.subtitle,
    this.showId = false,
    this.showProject = false,
    this.showAssignee = false,
    this.showDueDate = false,
    this.showPriority = true,
    this.showState = true,
    this.showLabels = false,
    this.showSubIssues = false,
    this.isUnread = false,
    this.timeAgo,
    this.maxTitleLines = 1,
    required this.onTap,
    this.allLabels = const [],
    this.allMembers = const [],
  });

  /// Label the row reports to accessibility and to `adb shell uiautomator`.
  ///
  /// External automation locates a row by its issue identifier (e.g. "AFS-415")
  /// with a prefix match, so the identifier has to be the first token. The name
  /// follows so a human listener still knows which issue this is.
  String get _semanticLabel {
    if (projectIdentifier == null) return issue.name;
    return '$projectIdentifier-${issue.sequenceId} ${issue.name}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final issueLabels =
        allLabels.where((l) => issue.labels.contains(l.id)).toList();
    final issueMembers =
        allMembers.where((m) => issue.assignees.contains(m.id)).toList();

    // If subtitle is present, use the two-line inbox-style layout
    if (subtitle != null) {
      return _buildInboxLayout(context, theme, secondary);
    }

    // Standard card layout. M3E press feedback: the whole row squeezes on
    // touch-down and springs back with a slight overshoot on release.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: M3EPressable(
        pressedScale: 0.975,
        onTap: onTap,
        semanticLabel: _semanticLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(M3EShape.large),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // State icon
                if (showState) ...[
                  Icon(
                    PlaneTheme.stateIcon(state?.group ?? 'backlog'),
                    size: PlaneTheme.iconMedium,
                    color: state != null
                        ? PlaneTheme.stateGroupColor(state!.group)
                        : PlaneTheme.backlog,
                  ),
                  const SizedBox(width: 12),
                ],
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ID + priority row
                      Row(
                        children: [
                          if (showId && projectIdentifier != null) ...[
                            Text(
                              '$projectIdentifier-${issue.sequenceId}',
                              style: _identifierStyle(theme),
                            ),
                          ],
                          if (showPriority) ...[
                            const SizedBox(width: 8),
                            Icon(
                              PlaneTheme.priorityIcon(issue.priority),
                              size: PlaneTheme.iconSmall,
                              color: PlaneTheme.priorityColor(issue.priority),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Title
                      Text(
                        issue.name,
                        maxLines: maxTitleLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: PlaneTheme.fontBody,
                          fontWeight: PlaneTheme.fontBodyWeight,
                          color: theme.colorScheme.onSurface,
                          height: 1.3,
                        ),
                      ),
                      // Label pills
                      if (showLabels && issueLabels.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: issueLabels.take(3).map((l) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _parseColor(l.color)
                                      .withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(M3EShape.full),
                                ),
                                child: Text(
                                  l.name,
                                  style: TextStyle(
                                    fontSize: PlaneTheme.fontSmall,
                                    color: _parseColor(l.color),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                // Right side: assignee avatars + other indicators
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sub-issues count
                    if (showSubIssues && issue.subIssuesCount > 0) ...[
                      Icon(Icons.subdirectory_arrow_right,
                          size: PlaneTheme.iconSmall, color: secondary),
                      const SizedBox(width: 2),
                      Text('${issue.subIssuesCount}',
                          style: TextStyle(
                              fontSize: PlaneTheme.fontSmall, color: secondary)),
                      const SizedBox(width: 8),
                    ],
                    // Due date indicators
                    if (showDueDate && issue.isOverdue) ...[
                      Icon(Icons.schedule,
                          size: PlaneTheme.iconSmall, color: PlaneTheme.urgent),
                      const SizedBox(width: 8),
                    ],
                    if (showDueDate && issue.targetDate != null && !issue.isOverdue) ...[
                      Icon(Icons.calendar_today,
                          size: PlaneTheme.iconSmall, color: secondary),
                      const SizedBox(width: 8),
                    ],
                    // Project icon
                    if (showProject && issue.project != null) ...[
                      Icon(Icons.folder_outlined,
                          size: PlaneTheme.iconSmall, color: secondary),
                      const SizedBox(width: 8),
                    ],
                    // Assignee avatars
                    if (showAssignee && issueMembers.isNotEmpty) ...[
                      SizedBox(
                        width: issueMembers.length == 1
                            ? 24
                            : (24 + (issueMembers.take(3).length - 1) * 14).toDouble(),
                        height: 24,
                        child: Stack(
                          children: [
                            for (int i = 0; i < issueMembers.take(3).length; i++)
                              Positioned(
                                left: i * 14.0,
                                child: _MiniAvatar(member: issueMembers[i]),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (showAssignee &&
                        issueMembers.isEmpty &&
                        issue.assignees.isNotEmpty) ...[
                      Icon(Icons.person, size: PlaneTheme.iconSmall, color: secondary),
                    ],
                    // Sequence ID on the right (when not showing full identifier)
                    if (showId && projectIdentifier == null) ...[
                      Text('${issue.sequenceId}',
                          style: TextStyle(
                              fontSize: PlaneTheme.fontSmall, color: secondary)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInboxLayout(
      BuildContext context, ThemeData theme, Color secondary) {
    return M3EPressable(
      pressedScale: 0.985,
      onTap: onTap,
      semanticLabel: _semanticLabel,
      child: Container(
        color: isUnread
            ? theme.colorScheme.surfaceContainerLow
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // State icon
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                PlaneTheme.stateIcon(state?.group ?? 'backlog'),
                size: PlaneTheme.iconLarge,
                color: PlaneTheme.stateGroupColor(state?.group ?? 'backlog'),
              ),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Issue ID + title
                  Row(
                    children: [
                      if (showId && projectIdentifier != null) ...[
                        Text(
                          '$projectIdentifier-${issue.sequenceId}',
                          style: _identifierStyle(theme),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          issue.name,
                          maxLines: maxTitleLines,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: PlaneTheme.fontBody,
                            fontWeight: isUnread
                                ? FontWeight.w600
                                : PlaneTheme.fontBodyWeight,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Activity text + time
                  Row(
                    children: [
                      if (showPriority) ...[
                        Icon(PlaneTheme.priorityIcon(issue.priority),
                            size: PlaneTheme.iconSmall,
                            color: PlaneTheme.priorityColor(issue.priority)),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: PlaneTheme.fontSection,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (timeAgo != null) ...[
                        Text(
                          ' \u2022 $timeAgo',
                          style: TextStyle(
                            fontSize: PlaneTheme.fontSection,
                            // outline is the border role; the timestamp is text
                            // that should simply sit below the subtitle.
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One treatment for the issue identifier in both layouts — the inbox row
  /// used to render the same string two points larger and in monospace, which
  /// made the two lists look like different products.
  static TextStyle _identifierStyle(ThemeData theme) => TextStyle(
        fontSize: PlaneTheme.fontSmall,
        fontWeight: FontWeight.w500,
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.5,
      );

  static Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF999999);
  }
}

class _MiniAvatar extends StatelessWidget {
  final Member member;
  const _MiniAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (member.avatar != null && member.avatar!.isNotEmpty) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: 0.8,
          ),
        ),
        child: CircleAvatar(
          radius: 12,
          backgroundImage: NetworkImage(member.avatar!),
          backgroundColor: theme.colorScheme.surface,
        ),
      );
    }
    return CircleAvatar(
      radius: 12,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      child: Text(
        (member.displayName.isNotEmpty ? member.displayName : '?')[0]
            .toUpperCase(),
        style: TextStyle(fontSize: 10, color: theme.colorScheme.primary),
      ),
    );
  }
}
