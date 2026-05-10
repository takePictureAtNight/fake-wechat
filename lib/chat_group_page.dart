import 'package:flutter/material.dart';

import 'api_client.dart';
import 'avatar_utils.dart';
import 'group_detail_page.dart';
import 'session_store.dart';
import 'unread_store.dart';
import 'ws_client.dart';

class ChatGroupPage extends StatefulWidget {
  const ChatGroupPage({super.key, required this.groupId, required this.title});

  final int groupId;
  final String title;

  @override
  State<ChatGroupPage> createState() => _ChatGroupPageState();
}

class _ChatGroupPageState extends State<ChatGroupPage> {
  final _input = TextEditingController();
  List<dynamic> _msgs = [];
  int? _selfId;
  bool _loading = true;
  void Function()? _unsub;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _unsub?.call();
    WsClient.instance.setActiveThread(null);
    _input.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final p = await SessionStore.loadProfile();
    _selfId = p?['userId'] as int?;
    await _load();
    final threadKey = 'G:${widget.groupId}';
    WsClient.instance.setActiveThread(threadKey);
    await UnreadStore.markReadNow(threadKey);
    await WsClient.instance.ensureConnected();
    _unsub?.call();
    _unsub = WsClient.instance.subscribeGroup(widget.groupId, (msg) async {
      // 只追加新消息，避免重复：用 id 简单去重
      final mid = (msg['id'] as num?)?.toInt();
      if (mid != null) {
        for (final e in _msgs) {
          if (e is Map && (e['id'] as num?)?.toInt() == mid) return;
        }
      }
      if (!mounted) return;
      setState(() {
        _msgs.add(msg);
      });
      await UnreadStore.markReadNow(threadKey);
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiClient.instance.get('/api/chat/group/${widget.groupId}') as List<dynamic>;
      setState(() => _msgs = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    try {
      await ApiClient.instance.post('/api/chat/group', {
        'groupId': widget.groupId,
        'content': t,
      });
      _input.clear();
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            tooltip: '群聊详情',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GroupDetailPage(groupId: widget.groupId)),
              );
              await _load();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _msgs.length,
                      itemBuilder: (context, i) {
                        final m = _msgs[i] as Map<String, dynamic>;
                        final sid = (m['senderId'] as num).toInt();
                        final mine = sid == _selfId;
                        final content = m['content'] as String? ?? '';
                        final nick = m['senderNickname'] as String? ?? '';
                        final avatarUrl = m['senderAvatarUrl'] as String?;
                        final avatar = AvatarUtils.providerFromUrl(avatarUrl);
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Row(
                            mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!mine) ...[
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: avatar,
                                  child: avatar == null ? const Icon(Icons.person, size: 18, color: Colors.black45) : null,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (!mine && nick.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Text(nick, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                      ),
                                    Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: mine ? const Color(0xFF95EC69) : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)],
                                      ),
                                      child: Text(content),
                                    ),
                                  ],
                                ),
                              ),
                              if (mine) ...[
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.grey.shade200,
                                  child: const Icon(Icons.person, size: 18, color: Colors.black45),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
          Material(
            color: const Color(0xFFF7F7F7),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        decoration: const InputDecoration(hintText: '发送群消息', filled: true),
                        minLines: 1,
                        maxLines: 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFF07C160)),
                      onPressed: _send,
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
