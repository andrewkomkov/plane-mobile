import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/search_service.dart';
import '../../models/issue.dart';

class SearchScreen extends StatefulWidget {
  final String workspaceSlug;
  const SearchScreen({super.key, required this.workspaceSlug});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Issue> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (query.length >= 2) _search(query);
    });
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final results = await SearchService.searchIssues(widget.workspaceSlug, query);
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search issues...',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? Center(
                  child: Text(
                    _controller.text.length < 2
                        ? 'Type to search'
                        : 'No results',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final issue = _results[i];
                    return ListTile(
                      title: Text(issue.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${issue.priority} | #${issue.sequenceId}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    );
                  },
                ),
    );
  }
}
