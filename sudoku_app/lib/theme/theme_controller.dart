// lib/theme/theme_controller.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  static const _key = 'themeMode'; // 'light' | 'dark'

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == 'dark') {
      mode.value = ThemeMode.dark;
    } else {
      mode.value = ThemeMode.light;
    }
  }

  static Future<void> toggle() async {
    final next = (mode.value == ThemeMode.light) ? ThemeMode.dark : ThemeMode.light;
    mode.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next == ThemeMode.dark ? 'dark' : 'light');
  }
}
