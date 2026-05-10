import 'package:flutter/material.dart';

import 'api_client.dart';
import 'avatar_utils.dart';
import 'session_store.dart';
import 'unread_store.dart';
import 'ws_client.dart';

class ChatPrivatePage extends StatefulWidget {
  const ChatPrivatePage({super.key, required this.peerUserId, required this.title});

  final int peerUserId;
  final String title;

  @override
  State<ChatPrivatePage> createState() => _ChatPrivatePageState();
}

class _ChatPrivatePageState extends State<ChatPrivatePage> {
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
    final threadKey = 'P:${widget.peerUserId}';
    WsClient.instance.setActiveThread(threadKey);
    await UnreadStore.markReadNow(threadKey);
    await WsClient.instance.ensureConnected();
    final myId = _selfId;
    if (myId != null) {
      _unsub?.call();
      _unsub = WsClient.instance.subscribePrivate(myId, (msg) async {
        // 只关心与当前 peer 相关的消息
        final sid = (msg['senderId'] as num?)?.toInt();
        final rid = (msg['receiverUserId'] as num?)?.toInt();
        final pid = widget.peerUserId;
        final related = (sid == pid && rid == myId) || (sid == myId && rid == pid);
        if (!related) return;
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
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiClient.instance.get('/api/chat/private/${widget.peerUserId}') as List<dynamic>;
      setState(() => _msgs = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    try {
      await ApiClient.instance.post('/api/chat/private', {
        'receiverUserId': widget.peerUserId,
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
      appBar: AppBar(title: Text(widget.title)),
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
                        decoration: const InputDecoration(hintText: '发送消息', filled: true),
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
