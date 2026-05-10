import 'package:flutter/material.dart';

import 'api_client.dart';

class AdminGroupsPage extends StatefulWidget {
  const AdminGroupsPage({super.key});

  @override
  State<AdminGroupsPage> createState() => _AdminGroupsPageState();
}

class _AdminGroupsPageState extends State<AdminGroupsPage> {
  Future<dynamic>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = ApiClient.instance.get('/api/admin/groups');
    });
  }

  Future<void> _delete(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除群聊'),
        content: Text('确定删除「$name」？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiClient.instance.delete('/api/admin/groups/$id');
      _reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('系统管理 · 群聊')),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<dynamic>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('${snap.error}'));
            }
            final list = (snap.data as List?) ?? [];
            if (list.isEmpty) {
              return const Center(child: Text('暂无群聊'));
            }
            return ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = list[i] as Map<String, dynamic>;
                final id = (m['id'] as num).toInt();
                final name = m['name'] as String? ?? '';
                final mc = m['memberCount'];
                return ListTile(
                  title: Text(name),
                  subtitle: Text('群主 userId=${m['ownerUserId']} · 成员数 $mc'),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _delete(id, name)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
