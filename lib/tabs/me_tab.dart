import 'package:flutter/material.dart';

import '../admin_groups_page.dart';
import '../api_client.dart';
import '../avatar_utils.dart';
import '../friend_requests_page.dart';
import '../groups_page.dart';
import '../session_store.dart';
import '../suggest_friends_page.dart';

class MeTab extends StatefulWidget {
  const MeTab({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<MeTab> createState() => _MeTabState();
}

class _MeTabState extends State<MeTab> {
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final local = await SessionStore.loadProfile();
    setState(() => _profile = local);
    try {
      final me = await ApiClient.instance.get('/api/me') as Map<String, dynamic>;
      final u = me['user'] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _profile = {
          ...?_profile,
          'nickname': u['nickname'],
          'username': u['username'],
          'role': me['role'],
          'avatarUrl': me['avatarUrl'],
        };
      });
    } catch (_) {}
  }

  Future<void> _pickAndSaveAvatar() async {
    final file = await AvatarUtils.pickAvatarFile();
    if (file == null) return;
    try {
      final avatarUrl = await ApiClient.instance.uploadImage(file);
      await ApiClient.instance.put('/api/me/profile', {'avatarUrl': avatarUrl});
      if (!mounted) return;
      setState(() {
        _profile = {...?_profile, 'avatarUrl': avatarUrl};
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('头像已更新')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final nick = _profile?['nickname']?.toString() ?? '';
    final user = _profile?['username']?.toString() ?? '';
    final role = _profile?['role']?.toString() ?? 'USER';
    final avatarUrl = _profile?['avatarUrl']?.toString();
    final avatarProvider = AvatarUtils.providerFromUrl(avatarUrl);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: const Color(0xFF07C160),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(nick.isEmpty ? '我' : nick),
              background: Container(
                color: const Color(0xFF07C160),
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickAndSaveAvatar,
                      child: CircleAvatar(
                        radius: 28,
                        backgroundImage: avatarProvider,
                        child: avatarProvider == null ? const Icon(Icons.person, size: 32) : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nick, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                          Text(user, style: TextStyle(color: Colors.white.withOpacity(0.85))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _tile(Icons.account_circle_outlined, '设置头像', _pickAndSaveAvatar),
              _tile(Icons.group_outlined, '我的群聊', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupsPage()));
              }),
              _tile(Icons.person_add_alt_1_outlined, '添加好友（同群）', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SuggestFriendsPage()));
              }),
              _tile(Icons.mail_outline, '好友申请', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendRequestsPage()));
              }),
              _tile(Icons.vpn_key_outlined, '通过推荐码加入群聊', () => _joinDialog(context)),
              if (role == 'ADMIN')
                _tile(Icons.admin_panel_settings_outlined, '系统管理 · 群聊', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminGroupsPage()));
                }),
              _tile(Icons.logout, '退出登录', () async {
                await widget.onLogout();
              }, danger: true),
              const SizedBox(height: 24),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap, {bool danger = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
      elevation: 0,
      child: ListTile(
        leading: Icon(icon, color: danger ? Colors.redAccent : null),
        title: Text(title, style: TextStyle(color: danger ? Colors.redAccent : null)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Future<void> _joinDialog(BuildContext context) async {
    final codeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('输入推荐码'),
        content: TextField(
          controller: codeCtrl,
          decoration: const InputDecoration(hintText: '群主分享的推荐码'),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('加入')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ApiClient.instance.post('/api/groups/join', {'inviteCode': codeCtrl.text.trim()});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入群聊')));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
