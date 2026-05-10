import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api_client.dart';
import 'avatar_utils.dart';
import 'chat_group_page.dart';

class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({super.key, required this.groupId});

  final int groupId;

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  bool _loading = true;
  Map<String, dynamic>? _group;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final g = await ApiClient.instance.get('/api/groups/${widget.groupId}');
      final ms = await ApiClient.instance.get('/api/groups/${widget.groupId}/members');
      final members = <Map<String, dynamic>>[];
      if (ms is List) {
        for (final it in ms) {
          if (it is Map<String, dynamic>) {
            members.add(it);
          } else if (it is Map) {
            members.add(Map<String, dynamic>.from(it));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _group = g is Map<String, dynamic> ? g : (g is Map ? Map<String, dynamic>.from(g) : null);
        _members = members;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _iAmOwner => (_group?['iAmOwner'] == true) || (_group?['IAmOwner'] == true);

  String _nick(Map<String, dynamic> m) => (m['nickname']?.toString().trim().isNotEmpty == true)
      ? m['nickname'].toString()
      : (m['username']?.toString() ?? '');

  String _avatarText(String s) {
    if (s.isEmpty) return '?';
    return s.characters.first.toUpperCase();
  }

  Future<void> _updateGroupAvatar() async {
    if (!_iAmOwner) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('仅群主可修改群头像')));
      return;
    }
    String? avatar;
    try {
      final file = await AvatarUtils.pickAvatarFile();
      if (file != null) {
        avatar = await ApiClient.instance.uploadImage(file);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('打开相册失败：$e')));
      return;
    }
    if (avatar == null) return;
    try {
      final g = await ApiClient.instance.put('/api/groups/${widget.groupId}/avatar', {'avatarUrl': avatar});
      if (!mounted) return;
      setState(() {
        _group = g is Map<String, dynamic> ? g : (g is Map ? Map<String, dynamic>.from(g) : _group);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('群头像已更新')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _rename() async {
    if (!_iAmOwner) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('仅群主可修改群名称')));
      return;
    }
    final old = _group?['name']?.toString() ?? '';
    final ctrl = TextEditingController(text: old);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改群聊名称'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '群名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    try {
      final g = await ApiClient.instance.put('/api/groups/${widget.groupId}', {'name': name});
      if (!mounted) return;
      setState(() {
        _group = g is Map<String, dynamic> ? g : (g is Map ? Map<String, dynamic>.from(g) : _group);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已修改')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _inviteCode() async {
    if (!_iAmOwner) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('仅群主可生成推荐码')));
      return;
    }
    try {
      final d = await ApiClient.instance.post('/api/groups/${widget.groupId}/invite-code');
      final code = (d is Map ? d['code']?.toString() : null) ?? '';
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('推荐码'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(code, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: QrImageView(
                      data: 'GROUP:$code',
                      version: QrVersions.auto,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('可通过扫一扫识别入群', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openChat() async {
    final title = _group?['name']?.toString() ?? '群聊';
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatGroupPage(groupId: widget.groupId, title: title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _group?['name']?.toString() ?? '群聊详情';
    final groupAvatar = AvatarUtils.providerFromUrl(_group?['avatarUrl']?.toString());
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _sectionTitle('群头像'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: _updateGroupAvatar,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundImage: groupAvatar,
                              child: groupAvatar == null
                                  ? const Icon(Icons.groups_2_outlined, size: 32)
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _iAmOwner ? '点击修改群头像' : '仅群主可修改群头像',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _sectionTitle('成员'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _members.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        itemBuilder: (context, i) {
                          final m = _members[i];
                          final nick = _nick(m);
                          final role = m['roleInGroup']?.toString() ?? '';
                          return Column(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: role == 'OWNER' ? const Color(0xFF07C160) : Colors.blue.shade200,
                                    child: Text(_avatarText(nick), style: const TextStyle(color: Colors.white)),
                                  ),
                                  if (role == 'OWNER')
                                    const Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: CircleAvatar(
                                        radius: 8,
                                        backgroundColor: Colors.white,
                                        child: Icon(Icons.star, size: 12, color: Color(0xFF07C160)),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(nick, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionTitle('群聊信息'),
                  _tile(
                    title: '修改群头像',
                    subtitle: _iAmOwner ? '从相册选择新头像' : '仅群主可修改',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _updateGroupAvatar,
                  ),
                  _tile(
                    title: '群聊名称',
                    subtitle: title,
                    trailing: _iAmOwner ? const Icon(Icons.edit_outlined) : null,
                    onTap: _rename,
                  ),
                  _tile(
                    title: '推荐码',
                    subtitle: _iAmOwner ? '生成推荐码邀请好友入群' : '仅群主可生成推荐码',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _inviteCode,
                  ),
                  _tile(
                    title: '进入群聊',
                    subtitle: '查看群消息',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openChat,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Text(t, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
    );
  }

  Widget _tile({
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
      elevation: 0,
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

