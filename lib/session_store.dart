import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const _token = 'token';
  static const _userId = 'userId';
  static const _nickname = 'nickname';
  static const _role = 'role';
  static const _username = 'username';

  static Future<void> save({
    required String token,
    required int userId,
    required String nickname,
    required String role,
    required String username,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_token, token);
    await p.setInt(_userId, userId);
    await p.setString(_nickname, nickname);
    await p.setString(_role, role);
    await p.setString(_username, username);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_token);
    await p.remove(_userId);
    await p.remove(_nickname);
    await p.remove(_role);
    await p.remove(_username);
  }

  static Future<String?> loadToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_token);
  }

  static Future<Map<String, dynamic>?> loadProfile() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString(_token);
    if (t == null) return null;
    return {
      'token': t,
      'userId': p.getInt(_userId),
      'nickname': p.getString(_nickname) ?? '',
      'role': p.getString(_role) ?? 'USER',
      'username': p.getString(_username) ?? '',
    };
  }
}
