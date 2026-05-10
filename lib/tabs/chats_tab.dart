import 'package:flutter/material.dart';

import '../api_client.dart';
import '../chat_group_page.dart';
import '../chat_private_page.dart';
import '../friend_requests_page.dart';
import '../groups_page.dart';
import '../scan_page.dart';
import '../suggest_friends_page.dart';
import '../unread_store.dart';
import '../ws_client.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../avatar_utils.dart';
import '../thread_store.dart';

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  Future<dynamic>? _future;
  Timer? _timer;
  StreamSubscription? _wsSub;
  Set<String> _pinned = <String>{};
  Set<String> _deleted = <String>{};

  @override
  void initState() {
    super.initState();
    _loadThreadLocalState();
    _reload();
    _bootWs();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _reload());
  }

  Future<void> _loadThreadLocalState() async {
    final p = await ThreadStore.pinned();
    final d = await ThreadStore.deleted();
    if (!mounted) return;
    setState(() {
      _pinned = p;
      _deleted = d;
    });
  }

  Future<void> _bootWs() async {
    await WsClient.instance.ensureConnected();
    _wsSub?.cancel();
    _wsSub = WsClient.instance.messages.listen((evt) {
      if (evt['_type'] == 'inbox') {
        _reload();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wsSub?.cancel();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = ApiClient.instance.get('/api/chat/threads');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            onSelected: (v) async {
              if (v == 'add_friend') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SuggestFriendsPage()),
                );
                _reload();
                return;
              }
              if (v == 'friend_requests') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FriendRequestsPage()),
                );
                _reload();
                return;
              }
              if (v == 'group_chat') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GroupsPage()),
                );
                _reload();
                return;
              }
              if (v == 'join_group') {
                await _joinGroupByCodeDialog();
                _reload();
                return;
              }
              if (v == 'friend_code') {
                await _friendCodeDialog();
                _reload();
                return;
              }
              if (v == 'scan') {
                await _scanByCamera();
                _reload();
                return;
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'add_friend',
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_1_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('添加好友'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'friend_requests',
                child: Row(
                  children: [
                    Icon(Icons.mail_outline, size: 20),
                    SizedBox(width: 10),
                    Text('好友申请'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'group_chat',
                child: Row(
                  children: [
                    Icon(Icons.chat_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('发起群聊'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'join_group',
                child: Row(
                  children: [
                    Icon(Icons.vpn_key_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('推荐码入群'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'friend_code',
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('邀请码联系'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'scan',
                child: Row(
                  children: [
                    Icon(Icons.qr_code_scanner, size: 20),
                    SizedBox(width: 10),
                    Text('扫一扫'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<dynamic>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]);
            }
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('加载失败：${snap.error}', style: const TextStyle(color: Colors.redAccent)),
                  ),
                ],
              );
            }
            final list = (snap.data as List?) ?? [];
            // 同步未读红点（基于 lastRead vs lastTime）
            UnreadStore.syncFromThreads(list);
            // 过滤已删除
            final visible = <Map<String, dynamic>>[];
            for (final it in list) {
              if (it is! Map<String, dynamic>) continue;
              final type = it['type'] as String? ?? '';
              final key = type == 'PRIVATE' ? 'P:${it['peerUserId']}' : 'G:${it['groupId']}';
              if (_deleted.contains(key)) continue;
              visible.add(it);
            }

            // 置顶排序：置顶在前，其余保持后端排序（lastTime desc）
            visible.sort((a, b) {
              final ta = a['type'] as String? ?? '';
              final tb = b['type'] as String? ?? '';
              final ka = ta == 'PRIVATE' ? 'P:${a['peerUserId']}' : 'G:${a['groupId']}';
              final kb = tb == 'PRIVATE' ? 'P:${b['peerUserId']}' : 'G:${b['groupId']}';
              final pa = _pinned.contains(ka);
              final pb = _pinned.contains(kb);
              if (pa == pb) return 0;
              return pa ? -1 : 1;
            });

            if (visible.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('暂无会话\n点击右上角 + 添加好友/群聊')),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: visible.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final m = visible[i];
                final type = m['type'] as String? ?? '';
                final threadKey = type == 'PRIVATE'
                    ? 'P:${m['peerUserId']}'
                    : 'G:${m['groupId']}';
                final hasUnread = UnreadStore.hasUnread(threadKey);
                final title = type == 'PRIVATE'
                    ? (m['peerNickname'] as String? ?? '用户')
                    : (m['groupName'] as String? ?? '群聊');
                final sub = (m['lastContent'] as String?) ?? '';
                final avatarUrl = type == 'PRIVATE' ? (m['peerAvatarUrl'] as String?) : (m['groupAvatarUrl'] as String?);
                final avatar = AvatarUtils.providerFromUrl(avatarUrl);
                return Dismissible(
                  key: ValueKey('thread:$threadKey'),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    color: const Color(0xFF07C160),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _pinned.contains(threadKey) ? '取消置顶' : '置顶',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  secondaryBackground: Container(
                    color: Colors.redAccent,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Text('删除', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  confirmDismiss: (dir) async {
                    if (dir == DismissDirection.startToEnd) {
                      await ThreadStore.togglePin(threadKey);
                      await _loadThreadLocalState();
                      return false; // 置顶不移除
                    }
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('删除会话？'),
                        content: const Text('仅本机隐藏该会话，不会删除服务器消息。'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
                        ],
                      ),
                    );
                    return ok == true;
                  },
                  onDismissed: (dir) async {
                    if (dir == DismissDirection.endToStart) {
                      await ThreadStore.markDeleted(threadKey);
                      UnreadStore.setUnread(threadKey, false);
                      await _loadThreadLocalState();
                      _reload();
                    }
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: avatar,
                      child: avatar == null
                          ? Icon(type == 'PRIVATE' ? Icons.person : Icons.groups, color: Colors.black54)
                          : null,
                    ),
                    title: Row(
                      children: [
                        if (_pinned.contains(threadKey))
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.push_pin, size: 16, color: Colors.orange),
                          ),
                        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: hasUnread
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          )
                        : null,
                    onTap: () async {
                      WsClient.instance.setActiveThread(threadKey);
                      await UnreadStore.markReadNow(threadKey);
                      if (type == 'PRIVATE') {
                        final id = (m['peerUserId'] as num).toInt();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatPrivatePage(peerUserId: id, title: title)),
                        );
                      } else {
                        final gid = (m['groupId'] as num).toInt();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatGroupPage(groupId: gid, title: title)),
                        );
                      }
                      WsClient.instance.setActiveThread(null);
                      _reload();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _joinGroupByCodeDialog() async {
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
    if (ok != true || !mounted) return;
    try {
      await ApiClient.instance.post('/api/groups/join', {'inviteCode': codeCtrl.text.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入群聊')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _friendCodeDialog() async {
    String myCode = '';
    try {
      myCode = (await ApiClient.instance.get('/api/friends/my-code')).toString();
    } catch (_) {}
    if (!mounted) return;
    final codeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('邀请码联系'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (myCode.isNotEmpty) ...[
              Text('我的邀请码：$myCode'),
              const SizedBox(height: 8),
              Center(
                child: QrImageView(
                  data: 'FRIEND:$myCode',
                  version: QrVersions.auto,
                  size: 140,
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(hintText: '输入对方邀请码，例如 F12'),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('发送申请')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiClient.instance.post('/api/friends/request-by-code', {'code': codeCtrl.text.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已发送好友申请')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _scanByCamera() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (!mounted || raw == null || raw.trim().isEmpty) return;
    await _handleScanResult(raw.trim());
  }

  Future<void> _scanDialogFallback() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手动输入扫码结果'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'GROUP:ABCD1234 / FRIEND:F12'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final raw = ctrl.text.trim();
    if (raw.isEmpty) return;
    await _handleScanResult(raw);
  }

  Future<void> _handleScanResult(String raw) async {
    if (raw.isEmpty) return;
    final upper = raw.toUpperCase();
    try {
      if (upper.startsWith('GROUP:')) {
        final code = raw.substring(raw.indexOf(':') + 1).trim();
        await ApiClient.instance.post('/api/groups/join', {'inviteCode': code});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入群聊')));
        return;
      }
      if (upper.startsWith('FRIEND:')) {
        final code = raw.substring(raw.indexOf(':') + 1).trim();
        await ApiClient.instance.post('/api/friends/request-by-code', {'code': code});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已发送好友申请')));
        return;
      }
      await ApiClient.instance.post('/api/groups/join', {'inviteCode': raw});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入群聊')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('扫码失败：$e')));
      await _scanDialogFallback();
    }
  }
}
