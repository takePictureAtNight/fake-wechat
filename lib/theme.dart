import 'package:flutter/material.dart';

const Color kWeChatGreen = Color(0xFF07C160);
const Color kWeChatBg = Color(0xFFEDEDED);
const Color kWeChatBar = Color(0xFFF7F7F7);

ThemeData weChatTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: kWeChatGreen, brightness: Brightness.light),
    scaffoldBackgroundColor: kWeChatBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kWeChatBar,
      foregroundColor: Colors.black87,
      elevation: 0.5,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.black87,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kWeChatBar,
      selectedItemColor: kWeChatGreen,
      unselectedItemColor: Colors.black45,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    listTileTheme: const ListTileThemeData(
      tileColor: Colors.white,
      iconColor: Colors.black54,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kWeChatGreen,
      foregroundColor: Colors.white,
    ),
  );
  return base;
}
