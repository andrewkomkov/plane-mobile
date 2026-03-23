import 'package:flutter/material.dart';
import '../../services/module_service.dart';
import '../../models/module.dart';

class ModuleListScreen extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;

  const ModuleListScreen({super.key, required this.workspaceSlug, required this.projectId});

  @override
  State<ModuleListScreen> createState() => _ModuleListScreenState();
}

class _ModuleListScreenState extends State<ModuleListScreen>
    with AutomaticKeepAliveClientMixin {
  List<Module> _modules = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final modules = await ModuleService.getModules(widget.workspaceSlug, widget.projectId);
      setState(() {
        _modules = modules;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_modules.isEmpty) return const Center(child: Text('No modules'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _modules.length,
        itemBuilder: (ctx, i) {
          final m = _modules[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.view_module),
              title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Row(
                children: [
                  if (m.startDate != null) ...[
                    Text(m.startDate!, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    if (m.targetDate != null)
                      Text(' - ${m.targetDate!}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                  const Spacer(),
                  Text('${m.completedIssues}/${m.totalIssues}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              trailing: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: m.progress,
                  strokeWidth: 3,
                  backgroundColor: Colors.grey[200],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
