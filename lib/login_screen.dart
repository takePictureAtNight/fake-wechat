import 'package:flutter/material.dart';

import 'api_client.dart';
import 'session_store.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController(text: 'admin');
  final _pass = TextEditingController(text: 'admin123');
  bool _busy = false;
  bool _register = false;
  final _nick = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _nick.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final path = _register ? '/api/auth/register' : '/api/auth/login';
      final body = {
        'username': _user.text.trim(),
        'password': _pass.text,
        if (_register) 'nickname': _nick.text.trim().isEmpty ? _user.text.trim() : _nick.text.trim(),
      };
      final d = await ApiClient.instance.post(path, body) as Map<String, dynamic>;
      final token = d['token'] as String;
      final userId = (d['userId'] as num).toInt();
      final nickname = d['nickname'] as String? ?? '';
      final role = d['role'] as String? ?? 'USER';
      final username = d['username'] as String? ?? '';
      ApiClient.instance.token = token;
      await SessionStore.save(
        token: token,
        userId: userId,
        nickname: nickname,
        role: role,
        username: username,
      );
      widget.onSuccess();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text('仿微信', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                _register ? '注册新账号' : '使用账号登录',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _user,
                decoration: const InputDecoration(labelText: '用户名'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                decoration: const InputDecoration(labelText: '密码'),
                obscureText: true,
              ),
              if (_register) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _nick,
                  decoration: const InputDecoration(labelText: '昵称（可选）'),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF07C160),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_register ? '注册并登录' : '登录'),
              ),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _register = !_register),
                child: Text(_register ? '已有账号？去登录' : '没有账号？注册'),
              ),
              const Spacer(),
              Text(
                '默认管理员：admin / admin123（后端首次启动自动创建）',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
