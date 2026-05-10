import 'package:shared_preferences/shared_preferences.dart';

/// 消息页会话的本地状态（不依赖后端）：
/// - 置顶：pinnedThreads
/// - 删除：deletedThreads（仅本机隐藏，不影响对方/服务器）
class ThreadStore {
  ThreadStore._();

  static const _pinnedKey = 'threads:pinned';
  static const _deletedKey = 'threads:deleted';

  static Set<String>? _pinnedCache;
  static Set<String>? _deletedCache;

  static Future<Set<String>> _loadSet(String key) async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(key) ?? []).toSet();
  }

  static Future<void> _saveSet(String key, Set<String> v) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(key, v.toList());
  }

  static Future<Set<String>> pinned() async {
    _pinnedCache ??= await _loadSet(_pinnedKey);
    return _pinnedCache!;
  }

  static Future<Set<String>> deleted() async {
    _deletedCache ??= await _loadSet(_deletedKey);
    return _deletedCache!;
  }

  static Future<bool> isPinned(String threadKey) async {
    final s = await pinned();
    return s.contains(threadKey);
  }

  static Future<bool> isDeleted(String threadKey) async {
    final s = await deleted();
    return s.contains(threadKey);
  }

  static Future<void> togglePin(String threadKey) async {
    final s = await pinned();
    if (s.contains(threadKey)) {
      s.remove(threadKey);
    } else {
      s.add(threadKey);
    }
    _pinnedCache = s;
    await _saveSet(_pinnedKey, s);
  }

  static Future<void> markDeleted(String threadKey) async {
    final d = await deleted();
    d.add(threadKey);
    _deletedCache = d;
    await _saveSet(_deletedKey, d);
    // 删除时顺便取消置顶
    final p = await pinned();
    if (p.remove(threadKey)) {
      _pinnedCache = p;
      await _saveSet(_pinnedKey, p);
    }
  }

  static Future<void> restore(String threadKey) async {
    final d = await deleted();
    if (d.remove(threadKey)) {
      _deletedCache = d;
      await _saveSet(_deletedKey, d);
    }
  }
}

