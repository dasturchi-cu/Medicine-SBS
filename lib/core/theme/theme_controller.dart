import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_system.dart';

/// Kun/tun rejimi holati (true = tun). Profildagi toggle shuni o'zgartiradi.
/// Tanlov SharedPreferences'da saqlanadi (ilova qayta ochilса ham eslab qoladi).
final themeControllerProvider = NotifierProvider<ThemeController, bool>(ThemeController.new);

class ThemeController extends Notifier<bool> {
  static const _key = 'app_dark_mode';

  @override
  bool build() {
    AppColors.isDarkMode = false;
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dark = prefs.getBool(_key) ?? false;
      AppColors.isDarkMode = dark;
      if (dark != state) state = dark;
    } catch (_) {
      // saqlangan tanlov bo'lmasa — kun rejimi.
    }
  }

  Future<void> toggle(bool dark) async {
    AppColors.isDarkMode = dark;
    state = dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, dark);
    } catch (_) {}
  }
}
