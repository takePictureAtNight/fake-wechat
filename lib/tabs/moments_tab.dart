import 'package:flutter/material.dart';

import '../api_client.dart';
import '../post_moment_page.dart';

class MomentsTab extends StatefulWidget {
  const MomentsTab({super.key});

  @override
  State<MomentsTab> createState() => _MomentsTabState();
}

class _MomentsTabState extends State<MomentsTab> {
  Future<dynamic>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = ApiClient.instance.get('/api/moments/feed');
    });
  }

  String _visLabel(String? v) {
    switch (v) {
      case 'ALL':
        return '好友可见';
      case 'SELF':
        return '仅自己';
      case 'GROUPS':
        return '部分群可见';
      default:
        return v ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('朋友圈'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const PostMomentPage()));
              _reload();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<dynamic>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('加载失败：${snap.error}'),
                  ),
                ],
              );
            }
            final list = (snap.data as List?) ?? [];
            if (list.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('暂无动态，点击右上角相机发布')),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = list[i] as Map<String, dynamic>;
                final nick = m['authorNickname'] as String? ?? '';
                final content = m['content'] as String? ?? '';
                final vis = m['visibility'] as String?;
                final time = m['createdAt'] as String? ?? '';
                return ListTile(
                  tileColor: Colors.white,
                  isThreeLine: true,
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(nick, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(content),
                      const SizedBox(height: 6),
                      Text('${_visLabel(vis)} · $time', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
