import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 轻量未读策略：
/// - 每个会话保存 lastReadTime（ISO8601 字符串）
/// - 会话是否未读：thread.lastTime > lastReadTime
/// - 汇总 totalUnread 用于底部「消息」tab 红点
class UnreadStore {
  UnreadStore._();

  static final ValueNotifier<int> totalUnread = ValueNotifier<int>(0);

  static const _prefix = 'lastRead:';
  static String _key(String threadKey) => '$_prefix$threadKey';

  static final Map<String, DateTime?> _lastReadCache = <String, DateTime?>{};
  static final Map<String, bool> _unreadCache = <String, bool>{};

  /// threadKey: P:<peerUserId> 或 G:<groupId>
  static Future<DateTime?> getLastRead(String threadKey) async {
    if (_lastReadCache.containsKey(threadKey)) return _lastReadCache[threadKey];
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key(threadKey));
    final v = (s == null || s.isEmpty) ? null : DateTime.tryParse(s);
    _lastReadCache[threadKey] = v;
    return v;
  }

  static Future<void> markReadNow(String threadKey) async {
    final now = DateTime.now();
    _lastReadCache[threadKey] = now;
    _unreadCache[threadKey] = false;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key(threadKey), now.toIso8601String());
    _recomputeTotal();
  }

  static bool hasUnread(String threadKey) => _unreadCache[threadKey] == true;

  static void setUnread(String threadKey, bool unread) {
    _unreadCache[threadKey] = unread;
    _recomputeTotal();
  }

  static void markUnread(String threadKey) {
    _unreadCache[threadKey] = true;
    _recomputeTotal();
  }

  /// threads 为 `/api/chat/threads` 的返回数组
  static Future<void> syncFromThreads(List<dynamic> threads) async {
    int total = 0;
    for (final t in threads) {
      if (t is! Map) continue;
      final type = t['type']?.toString() ?? '';
      final key = type == 'PRIVATE'
          ? 'P:${t['peerUserId']}'
          : 'G:${t['groupId']}';
      final lastTimeStr = t['lastTime']?.toString();
      final lastTime = lastTimeStr == null ? null : DateTime.tryParse(lastTimeStr);
      if (lastTime == null) {
        _unreadCache[key] = false;
        continue;
      }
      final lr = await getLastRead(key);
      final unread =
          lr == null ? lastTime.isAfter(DateTime.fromMillisecondsSinceEpoch(0)) : lastTime.isAfter(lr);
      _unreadCache[key] = unread;
      if (unread) total += 1; // 先简化为红点/不红点（每会话计 1）
    }
    totalUnread.value = total;
  }

  static void _recomputeTotal() {
    int total = 0;
    for (final e in _unreadCache.entries) {
      if (e.value) total += 1;
    }
    totalUnread.value = total;
  }
}

