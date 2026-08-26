import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._(this._mode);

  static const String _prefKey = 'theme_mode';

  ThemeMode _mode;
  ThemeMode get mode => _mode;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    final mode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return AppSettings._(mode);
  }

  bool get isDark => _mode == ThemeMode.dark;
  bool get isSystem => _mode == ThemeMode.system;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    _persist();
    notifyListeners();
  }

  void toggle() => setMode(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = switch (_mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_prefKey, value);
    } catch (e) {
      debugPrint('Theme persist error: $e');
    }
  }
}
