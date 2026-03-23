import 'package:flutter/material.dart';
import '../../services/cycle_service.dart';
import '../../models/cycle.dart';

class CycleListScreen extends StatefulWidget {
  final String workspaceSlug;
  final String projectId;

  const CycleListScreen({super.key, required this.workspaceSlug, required this.projectId});

  @override
  State<CycleListScreen> createState() => _CycleListScreenState();
}

class _CycleListScreenState extends State<CycleListScreen>
    with AutomaticKeepAliveClientMixin {
  List<Cycle> _cycles = [];
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
      final cycles = await CycleService.getCycles(widget.workspaceSlug, widget.projectId);
      setState(() {
        _cycles = cycles;
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
    if (_cycles.isEmpty) return const Center(child: Text('No cycles'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _cycles.length,
        itemBuilder: (ctx, i) {
          final c = _cycles[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.loop),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Row(
                children: [
                  if (c.startDate != null) ...[
                    Text(c.startDate!, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    if (c.endDate != null)
                      Text(' - ${c.endDate!}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                  const Spacer(),
                  Text('${c.completedIssues}/${c.totalIssues}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              trailing: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: c.progress,
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
