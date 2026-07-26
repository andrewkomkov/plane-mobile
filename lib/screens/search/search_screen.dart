import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/m3e/typography.dart';
import '../../services/search_service.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/m3e/icon_button.dart';
import '../../widgets/m3e/text_field.dart';
import '../../utils/search_result_route.dart';
import '../../widgets/section_header.dart';
import '../../widgets/plane_row.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String workspaceSlug;
  final bool autoFocus;
  const SearchScreen(
      {super.key, required this.workspaceSlug, this.autoFocus = false});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  bool _loading = false;
  Timer? _debounce;
  List<String> _recentSearches = [];

  static const _storage = FlutterSecureStorage();
  static const _recentKey = 'plane_recent_searches';

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final data = await _storage.read(key: _recentKey);
      if (data != null) {
        _recentSearches = (jsonDecode(data) as List).cast<String>();
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _saveRecentSearch(String query) async {
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.sublist(0, 10);
    }
    try {
      await _storage.write(key: _recentKey, value: jsonEncode(_recentSearches));
    } catch (_) {}
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _grouped = {};
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final results =
          await SearchService.searchAll(widget.workspaceSlug, query);
      _saveRecentSearch(query);
      setState(() {
        _grouped = results;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String _sectionLabel(String key) {
    switch (key) {
      case 'issues':
        return 'Issues';
      case 'projects':
        return 'Projects';
      case 'pages':
        return 'Pages';
      case 'cycles':
        return 'Cycles';
      case 'modules':
        return 'Modules';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showRecent =
        _controller.text.length < 2 && _grouped.isEmpty && !_loading;

    return Scaffold(
      // Search is its own surface: the field replaces the title outright. It is
      // the same M3ETextField the Projects tab uses, so the two are identical.
      //
      // Because there is no M3EAppBar there is also no M3EAppBarAction titled
      // "Back", which every other pushed screen gets for free — leaving the
      // system gesture as the only way out, and nothing at all for a screen
      // reader or for `adb_drive.py`. The button is drawn only when this
      // screen was pushed; the Projects tab hosts the same widget inline,
      // where a back arrow would have nowhere to go.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                Navigator.of(context).canPop() ? 4 : 16, 6, 16, 8),
            child: Row(
              children: [
                if (Navigator.of(context).canPop()) ...[
                  M3EIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: M3ETextField(
                    label: 'Search across workspace',
                    hint: 'Search across workspace...',
                    compact: true,
                    prefixIcon: Icons.search,
                    controller: _controller,
                    autofocus: widget.autoFocus,
                    onChanged: _onChanged,
                    suffix: _controller.text.isEmpty
                        ? null
                        : M3EIconButton(
                            icon: Icons.clear,
                            tooltip: 'Clear search',
                            size: M3EIconButtonSize.small,
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _grouped = {};
                                _loading = false;
                              });
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const LoadingStateWidget()
          : showRecent
              ? _buildRecent(theme)
              : _grouped.isEmpty
                  ? Center(
                      child: Text(
                        _controller.text.length < 2
                            ? 'Type to search'
                            : 'No results',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : _buildResults(theme),
    );
  }

  void _clearRecentSearches() {
    setState(() => _recentSearches.clear());
    _storage.write(key: _recentKey, value: jsonEncode([]));
  }

  Widget _buildRecent(ThemeData theme) {
    if (_recentSearches.isEmpty) {
      return const Center(
        child: EmptyStateWidget(
          message: 'Search issues, projects, pages and more',
          icon: Icons.search,
        ),
      );
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text('Recent searches',
                  style: M3EType.emphasized(theme.textTheme.titleSmall!)
                      .copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const Spacer(),
              // Bare "Clear" collides with the field's clear button, so this
              // one spells out what it clears. A TextButton rather than a bare
              // tap target: it carries the 48dp minimum on its own.
              //
              // Excluded, or the node reports "Clear recent searches, Clear"
              // and the collision the label was written to avoid comes back
              // through the child. The tap is re-declared here because the
              // exclusion takes the TextButton's own action with it.
              Semantics(
                label: 'Clear recent searches',
                button: true,
                container: true,
                excludeSemantics: true,
                onTap: _clearRecentSearches,
                child: TextButton(
                  onPressed: _clearRecentSearches,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    minimumSize: const Size(48, 48),
                    textStyle: theme.textTheme.labelMedium,
                  ),
                  child: const Text('Clear'),
                ),
              ),
            ],
          ),
        ),
        ..._recentSearches.map((q) => PlaneRow(
              icon: Icons.history,
              title: q,
              // The query on its own would be indistinguishable from a result
              // row carrying the same words.
              semanticLabel: '$q, recent search',
              onTap: () {
                _controller.text = q;
                _search(q);
              },
            )),
      ],
    );
  }

  Widget _buildResults(ThemeData theme) {
    final entries = _grouped.entries.toList();
    return ListView.builder(
      itemCount: entries.fold<int>(0, (sum, e) => sum + 1 + e.value.length),
      itemBuilder: (ctx, index) {
        int current = 0;
        for (final entry in entries) {
          if (index == current) {
            return SectionHeader(
              label: _sectionLabel(entry.key),
              count: entry.value.length,
            );
          }
          current++;
          final itemIndex = index - current;
          if (itemIndex < entry.value.length) {
            final item = entry.value[itemIndex];
            return _SearchResultTile(
              type: entry.key,
              item: item,
              onTap: () => openSearchResult(
                context,
                workspaceSlug: widget.workspaceSlug,
                type: entry.key,
                item: item,
              ),
            );
          }
          current += entry.value.length;
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final String type;
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.type,
    required this.item,
    required this.onTap,
  });

  IconData _iconFor(String type) {
    switch (type) {
      case 'issues':
        return Icons.radio_button_unchecked;
      case 'projects':
        return Icons.bolt_outlined;
      case 'pages':
        return Icons.description_outlined;
      case 'cycles':
        return Icons.loop;
      case 'modules':
        return Icons.view_module_outlined;
      default:
        return Icons.search;
    }
  }

  /// Singular name of what a hit is, for the row's accessibility label.
  String _kindFor(String type) {
    switch (type) {
      case 'issues':
        return 'issue';
      case 'projects':
        return 'project';
      case 'pages':
        return 'page';
      case 'cycles':
        return 'cycle';
      case 'modules':
        return 'module';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = item['name'] ?? item['title'] ?? '';
    // An issue hit reports its project under `project_identifier`, not
    // `identifier` — reading the latter meant the "XCDEV-8" subtitle never
    // appeared on the results that were supposed to carry it.
    final identifier = searchResultProjectIdentifier(item);
    final sequenceId = item['sequence_id'];
    final subtitle = sequenceId != null && identifier.isNotEmpty
        ? '$identifier-$sequenceId'
        : (item['description'] ?? '').toString();

    return PlaneRow(
      icon: _iconFor(type),
      title: name.toString(),
      subtitle: subtitle.isNotEmpty ? subtitle : null,
      // The kind of thing a hit is only shows in its icon, which the row's
      // label replaces, so it is spelled out.
      semanticLabel: [
        name.toString(),
        if (subtitle.isNotEmpty) subtitle.toString(),
        _kindFor(type),
      ].join(', '),
      onTap: onTap,
    );
  }
}
