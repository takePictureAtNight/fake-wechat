import 'package:flutter/material.dart';

import 'api_client.dart';
import 'home_shell.dart';
import 'login_screen.dart';
import 'session_store.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WxApp());
}

class WxApp extends StatelessWidget {
  const WxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '仿微信',
      theme: weChatTheme(),
      home: const WxRoot(),
    );
  }
}

class WxRoot extends StatefulWidget {
  const WxRoot({super.key});

  @override
  State<WxRoot> createState() => _WxRootState();
}

class _WxRootState extends State<WxRoot> {
  bool _ready = false;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final t = await SessionStore.loadToken();
    ApiClient.instance.token = t;
    setState(() {
      _loggedIn = t != null && t.isNotEmpty;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_loggedIn) {
      return LoginScreen(onSuccess: () => setState(() => _loggedIn = true));
    }
    return HomeShell(onLogout: () async {
      ApiClient.instance.token = null;
      await SessionStore.clear();
      setState(() => _loggedIn = false);
    });
  }
}
