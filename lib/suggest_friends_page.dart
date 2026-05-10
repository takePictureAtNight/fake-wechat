import 'package:flutter/material.dart';

import 'api_client.dart';

class SuggestFriendsPage extends StatefulWidget {
  const SuggestFriendsPage({super.key});

  @override
  State<SuggestFriendsPage> createState() => _SuggestFriendsPageState();
}

class _SuggestFriendsPageState extends State<SuggestFriendsPage> {
  Future<dynamic>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = ApiClient.instance.get('/api/friends/suggest');
    });
  }

  Future<void> _add(int userId) async {
    try {
      await ApiClient.instance.post('/api/friends/request/$userId');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已发送好友申请')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加好友（同群）')),
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
              return const Center(child: Text('暂无可添加的同群成员（或已是好友）'));
            }
            return ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = list[i] as Map<String, dynamic>;
                final id = (m['id'] as num).toInt();
                final nick = m['nickname'] as String? ?? '';
                return ListTile(
                  title: Text(nick),
                  subtitle: Text(m['username'] as String? ?? ''),
                  trailing: TextButton(onPressed: () => _add(id), child: const Text('添加')),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
