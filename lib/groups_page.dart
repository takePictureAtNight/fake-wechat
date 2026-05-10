import 'package:flutter/material.dart';

import 'api_client.dart';
import 'avatar_utils.dart';
import 'chat_group_page.dart';
import 'group_detail_page.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  Future<dynamic>? _future;

  static List<Map<String, dynamic>> _asObjectList(dynamic data) {
    if (data == null) return [];
    if (data is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        out.add(item);
      } else if (item is Map) {
        out.add(Map<String, dynamic>.from(item));
      }
    }
    return out;
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static bool _asBool(dynamic v) {
    if (v == true || v == 1) return true;
    if (v == false || v == 0) return false;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'true' || s == '1';
    }
    return false;
  }

  /// 兼容 Jackson 对 boolean getter 的多种序列化键名
  static bool _isOwner(Map<String, dynamic> m) {
    if (_asBool(m['iAmOwner'])) return true;
    if (_asBool(m['IAmOwner'])) return true;
    if (_asBool(m['iamOwner'])) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = ApiClient.instance.get('/api/groups/mine');
    });
  }

  Future<void> _create() async {
    final nameCtrl = TextEditingController();
    String? avatarUrl;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setInnerState) => AlertDialog(
          title: const Text('创建群聊'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final file = await AvatarUtils.pickAvatarFile();
                  if (file != null) {
                    final pickedUrl = await ApiClient.instance.uploadImage(file);
                    setInnerState(() => avatarUrl = pickedUrl);
                  }
                },
                child: CircleAvatar(
                  radius: 32,
                  backgroundImage: AvatarUtils.providerFromUrl(avatarUrl),
                  child: AvatarUtils.providerFromUrl(avatarUrl) == null
                      ? const Icon(Icons.camera_alt_outlined)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              const Text('点击选择群头像', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: '群名称')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('创建')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      final created = await ApiClient.instance.post('/api/groups', {
        'name': name,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      });
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('创建成功')));

      // 仿微信体验：创建后群主立刻拿到推荐码（仍然由群主生成，符合权限约束）
      if (created is Map) {
        final m = Map<String, dynamic>.from(created);
        final id = _asInt(m['id']);
        final owner = _isOwner(m);
        if (id != null && owner) {
          await _inviteCode(context, id, true);
        }
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _inviteCode(BuildContext context, int groupId, bool owner) async {
    if (!owner) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('仅群主可生成推荐码')));
      return;
    }
    try {
      final d = await ApiClient.instance.post('/api/groups/$groupId/invite-code') as Map<String, dynamic>;
      final code = d['code'] as String? ?? '';
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('推荐码'),
          content: SelectableText(code, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
        ),
      );
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的群聊')),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
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
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 40),
                  Text('加载失败：${snap.error}', style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 12),
                  Text('请检查 ${ApiClient.instance.baseUrl} 是否可访问、是否已登录', style: TextStyle(color: Colors.grey.shade700)),
                ],
              );
            }
            final list = _asObjectList(snap.data);
            if (list.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 120), Center(child: Text('暂无群聊，点击 + 创建或通过推荐码加入'))],
              );
            }
            return ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = list[i];
                final id = _asInt(m['id']);
                final name = m['name']?.toString() ?? '';
                final owner = _isOwner(m);
                if (id == null) {
                  return const ListTile(title: Text('数据格式异常'), subtitle: Text('群 id 无效'));
                }
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: AvatarUtils.providerFromUrl(m['avatarUrl']?.toString()),
                    child: AvatarUtils.providerFromUrl(m['avatarUrl']?.toString()) == null
                        ? const Icon(Icons.groups)
                        : null,
                  ),
                  title: Text(name),
                  subtitle: Text(owner ? '你是群主' : '成员'),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GroupDetailPage(groupId: id)),
                    );
                    _reload();
                  },
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'code') {
                        await _inviteCode(context, id, owner);
                      } else if (v == 'detail') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => GroupDetailPage(groupId: id)),
                        );
                        _reload();
                      } else if (v == 'chat') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatGroupPage(groupId: id, title: name)),
                        );
                        _reload();
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'chat', child: Text('进入群聊')),
                      PopupMenuItem(value: 'detail', child: Text('群聊详情')),
                      PopupMenuItem(value: 'code', child: Text('生成推荐码')),
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
