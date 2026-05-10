import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import 'app_config.dart';
import 'session_store.dart';
import 'unread_store.dart';

class WsClient {
  WsClient._();
  static final WsClient instance = WsClient._();

  StompClient? _client;
  bool _connecting = false;
  bool _connected = false;

  StompUnsubscribe? _inboxUnsub;

  int? _selfId;
  String? _token;

  String? _activeThreadKey; // 当前正在看的会话

  final StreamController<Map<String, dynamic>> _messageStream = StreamController.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageStream.stream;

  Future<void> ensureConnected() async {
    if (_connected || _connecting) return;
    _connecting = true;
    final p = await SessionStore.loadProfile();
    _selfId = (p?['userId'] as int?);
    _token = (p?['token'] as String?) ?? (await SessionStore.loadToken());
    if (_selfId == null || _token == null || _token!.isEmpty) {
      _connecting = false;
      return;
    }

    final wsUrl = _buildWsUrl(_token!);
    final c = StompClient(
      config: StompConfig(
        url: wsUrl,
        stompConnectHeaders: const {},
        webSocketConnectHeaders: const {},
        reconnectDelay: const Duration(seconds: 3),
        onConnect: _onConnect,
        onWebSocketError: (dynamic e) {
          _connected = false;
        },
        onStompError: (StompFrame f) {
          _connected = false;
        },
        onDisconnect: (_) {
          _connected = false;
        },
        heartbeatIncoming: const Duration(seconds: 0),
        heartbeatOutgoing: const Duration(seconds: 0),
      ),
    );
    _client = c;
    c.activate();
    _connecting = false;
  }

  Future<void> disconnect() async {
    _activeThreadKey = null;
    _connected = false;
    _inboxUnsub?.call();
    _inboxUnsub = null;
    _client?.deactivate();
    _client = null;
  }

  void setActiveThread(String? threadKey) {
    _activeThreadKey = threadKey;
    if (threadKey != null) {
      UnreadStore.markReadNow(threadKey);
    }
  }

  bool get isConnected => _connected;
  int? get selfId => _selfId;

  StompUnsubscribe? subscribeGroup(int groupId, void Function(Map<String, dynamic> msg) onMsg) {
    final c = _client;
    if (c == null || !_connected) return null;
    return c.subscribe(
      destination: '/topic/group/$groupId',
      callback: (f) => _handleFrame(f, onMsg),
    );
  }

  StompUnsubscribe? subscribePrivate(int myUserId, void Function(Map<String, dynamic> msg) onMsg) {
    final c = _client;
    if (c == null || !_connected) return null;
    return c.subscribe(
      destination: '/topic/private/$myUserId',
      callback: (f) => _handleFrame(f, onMsg),
    );
  }

  void _onConnect(StompFrame frame) {
    _connected = true;
    _subscribeInbox();
  }

  void _subscribeInbox() {
    final c = _client;
    final uid = _selfId;
    if (c == null || uid == null) return;
    _inboxUnsub?.call();
    _inboxUnsub = c.subscribe(
      destination: '/topic/inbox/$uid',
      callback: (f) {
        if (f.body == null) return;
        Map<String, dynamic>? data;
        try {
          data = json.decode(f.body!) as Map<String, dynamic>;
        } catch (_) {
          return;
        }
        final threadKey = data['threadKey']?.toString();
        if (threadKey == null || threadKey.isEmpty) return;

        // 当前会话里：直接认为已读（避免红点）
        if (threadKey == _activeThreadKey) {
          UnreadStore.markReadNow(threadKey);
        } else {
          UnreadStore.markUnread(threadKey);
        }

        // 通知外部：让会话列表刷新 lastContent/lastTime
        _messageStream.add({'_type': 'inbox', ...data});
      },
    );
  }

  void _handleFrame(StompFrame f, void Function(Map<String, dynamic> msg) onMsg) {
    if (f.body == null) return;
    Map<String, dynamic> data;
    try {
      data = json.decode(f.body!) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    onMsg(data);
    _messageStream.add({'_type': 'chat', ...data});
  }

  String _buildWsUrl(String token) {
    var base = AppConfig.apiBaseUrl.trim();
    if (base.startsWith('https://')) {
      base = base.replaceFirst('https://', 'wss://');
    } else if (base.startsWith('http://')) {
      base = base.replaceFirst('http://', 'ws://');
    }
    // Spring endpoint: /ws
    return '$base/ws?token=${Uri.encodeComponent(token)}';
  }
}

