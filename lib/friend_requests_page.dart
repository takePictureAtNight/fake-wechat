import 'package:flutter/material.dart';

import 'api_client.dart';

class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({super.key});

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  Future<dynamic>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = ApiClient.instance.get('/api/friends/requests/incoming');
    });
  }

  Future<void> _accept(int id) async {
    try {
      await ApiClient.instance.post('/api/friends/requests/$id/accept');
      _reload();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _reject(int id) async {
    try {
      await ApiClient.instance.post('/api/friends/requests/$id/reject');
      _reload();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('好友申请')),
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
              return const Center(child: Text('暂无待处理申请'));
            }
            return ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = list[i] as Map<String, dynamic>;
                final id = (m['id'] as num).toInt();
                final nick = m['fromNickname'] as String? ?? '';
                return ListTile(
                  title: Text(nick),
                  subtitle: Text('来自用户 ${m['fromUserId']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(onPressed: () => _reject(id), child: const Text('拒绝')),
                      FilledButton(onPressed: () => _accept(id), child: const Text('接受')),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
