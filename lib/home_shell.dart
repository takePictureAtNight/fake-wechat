import 'package:flutter/material.dart';

import 'tabs/chats_tab.dart';
import 'tabs/me_tab.dart';
import 'tabs/moments_tab.dart';
import 'unread_store.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  Widget _badgeIcon(Widget icon, int count) {
    if (count <= 0) return icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const ChatsTab(),
          const MomentsTab(),
          MeTab(onLogout: widget.onLogout),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: [
          BottomNavigationBarItem(
            icon: ValueListenableBuilder<int>(
              valueListenable: UnreadStore.totalUnread,
              builder: (_, c, __) => _badgeIcon(const Icon(Icons.chat_bubble_outline), c),
            ),
            activeIcon: ValueListenableBuilder<int>(
              valueListenable: UnreadStore.totalUnread,
              builder: (_, c, __) => _badgeIcon(const Icon(Icons.chat_bubble), c),
            ),
            label: '消息',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: '朋友圈',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我',
          ),
        ],
      ),
    );
  }
}
