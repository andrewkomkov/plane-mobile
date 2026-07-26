import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/intake_service.dart';
import '../../utils/api_error.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/app_bar.dart';
import '../../widgets/m3e/text_field.dart';
import '../../widgets/plane_row.dart';

/// Picks the work item an intake entry is a duplicate of.
///
/// Search rather than a scrollable list of everything: a project with any
/// history has thousands of work items, and the maintainer marking a duplicate
/// already knows roughly which one they mean.
///
/// The candidates come from the project's own `search-issues/`, whose queryset
/// runs through `Issue.issue_objects` — a manager that excludes anything in a
/// triage state. That is what stops this offering one intake entry as the
/// duplicate of another, and it is the server's doing, not a filter here.
class IntakeDuplicatePicker extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;

  /// The entry being marked, so it cannot be offered as its own original.
  /// The triage-state exclusion above should already rule it out, but only
  /// while the entry is actually in Triage — accepting moves it out.
  final String excludeIssueId;

  const IntakeDuplicatePicker({
    super.key,
    required this.workspaceSlug,
    required this.projectId,
    required this.excludeIssueId,
  });

  @override
  State<IntakeDuplicatePicker> createState() => _IntakeDuplicatePickerState();
}

class _IntakeDuplicatePickerState extends State<IntakeDuplicatePicker> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<IntakeDuplicateCandidate> _results = [];
  bool _loading = true;
  String? _error;

  /// Which query the in-flight request is for. A slow response for an earlier
  /// query must not overwrite the results of a later one — the classic
  /// search-box race, and the reason this is compared rather than a bare
  /// `mounted` check.
  String _inFlight = '';

  @override
  void initState() {
    super.initState();
    // The endpoint answers an empty query with the first hundred work items,
    // which is a useful starting list rather than an empty screen.
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
      _inFlight = query;
    });
    try {
      final results = await IntakeService.searchDuplicateTargets(
        widget.workspaceSlug,
        widget.projectId,
        query,
      );
      if (!mounted || _inFlight != query) return;
      setState(() {
        _results = results.where((r) => r.id != widget.excludeIssueId).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted || _inFlight != query) return;
      setState(() {
        _error = describeApiError(e, fallback: 'Could not search work items');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const M3EAppBar(
        title: 'Duplicate of',
        subtitle: 'Pick the work item this repeats',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: M3ETextField(
              label: 'Search work items',
              hint: 'Title or identifier',
              controller: _controller,
              compact: true,
              autofocus: true,
              prefixIcon: Icons.search,
              onChanged: _onChanged,
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingStateWidget();
    if (_error != null) {
      return ErrorStateWidget(
        message: _error,
        onRetry: () => _search(_controller.text),
      );
    }
    if (_results.isEmpty) {
      return const EmptyStateWidget(
        message: 'No matching work items',
        icon: Icons.search_off,
        subtitle: 'Only work items already in this project can be the original',
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (ctx, i) {
        final candidate = _results[i];
        final state = candidate.stateName;
        return PlaneRow(
          identifier: candidate.label,
          title: candidate.name,
          subtitle: state,
          semanticLabel: [
            candidate.label,
            candidate.name,
            if (state != null) 'state $state',
          ].join(', '),
          onTap: () => Navigator.pop(context, candidate),
        );
      },
    );
  }
}
