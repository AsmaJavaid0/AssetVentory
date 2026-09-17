import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesService {
  static final AppPreferencesService _instance = AppPreferencesService._internal();
  factory AppPreferencesService() => _instance;
  AppPreferencesService._internal();

  static const String _keyDefaultReminderMinutes = 'pref_default_reminder_minutes';
  static const String _keyDefaultTaskPriority = 'pref_default_task_priority';
  static const String _keyDefaultAssetView = 'pref_default_asset_view';
  static const String _keyConfirmBeforeDelete = 'pref_confirm_before_delete';
  static const String _keyHapticFeedback = 'pref_haptic_feedback';
  static const String _keyThemeMode = 'pref_theme_mode';
  static const String _keyTaskRemindersEnabled = 'pref_task_reminders_enabled';
  static const String _keyPushNotificationsEnabled = 'pref_push_notifications_enabled';

  SharedPreferences? _prefs;

  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    themeModeNotifier.value = themeMode;
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('AppPreferencesService has not been initialized. Call init() first.');
    }
    return _prefs!;
  }

  int get defaultReminderMinutes => _prefs?.getInt(_keyDefaultReminderMinutes) ?? 15;
  Future<bool> setDefaultReminderMinutes(int minutes) async => await prefs.setInt(_keyDefaultReminderMinutes, minutes);

  String get defaultTaskPriority => _prefs?.getString(_keyDefaultTaskPriority) ?? 'medium';
  Future<bool> setDefaultTaskPriority(String priority) async => await prefs.setString(_keyDefaultTaskPriority, priority);

  String get defaultAssetView => _prefs?.getString(_keyDefaultAssetView) ?? 'list';
  Future<bool> setDefaultAssetView(String view) async => await prefs.setString(_keyDefaultAssetView, view);

  bool get confirmBeforeDelete => _prefs?.getBool(_keyConfirmBeforeDelete) ?? true;
  Future<bool> setConfirmBeforeDelete(bool enabled) async => await prefs.setBool(_keyConfirmBeforeDelete, enabled);

  bool get hapticFeedbackEnabled => _prefs?.getBool(_keyHapticFeedback) ?? true;
  Future<bool> setHapticFeedbackEnabled(bool enabled) async => await prefs.setBool(_keyHapticFeedback, enabled);

  void triggerHaptic() {
    if (hapticFeedbackEnabled) HapticFeedback.lightImpact();
  }

  ThemeMode get themeMode {
    final raw = _prefs?.getString(_keyThemeMode) ?? 'light';
    switch (raw) {
      case 'system': return ThemeMode.system;
      case 'dark': return ThemeMode.dark;
      case 'light':
      default: return ThemeMode.light;
    }
  }

  Future<bool> setThemeMode(ThemeMode mode) async {
    String value;
    switch (mode) {
      case ThemeMode.system: value = 'system'; break;
      case ThemeMode.dark: value = 'dark'; break;
      case ThemeMode.light: value = 'light'; break;
    }
    themeModeNotifier.value = mode;
    return await prefs.setString(_keyThemeMode, value);
  }

  bool get taskRemindersEnabled => _prefs?.getBool(_keyTaskRemindersEnabled) ?? true;
  Future<bool> setTaskRemindersEnabled(bool enabled) async => await prefs.setBool(_keyTaskRemindersEnabled, enabled);

  bool get pushNotificationsEnabled => _prefs?.getBool(_keyPushNotificationsEnabled) ?? true;
  Future<bool> setPushNotificationsEnabled(bool enabled) async => await prefs.setBool(_keyPushNotificationsEnabled, enabled);

  // Family display names are intentionally local to this device/user.
  String familyDisplayName({
    required String familyId,
    required String viewerId,
    required String memberUserId,
    required String fallback,
  }) {
    final key = 'family_display_name_${familyId}_${viewerId}_$memberUserId';
    return _prefs?.getString(key)?.trim().isNotEmpty == true
        ? _prefs!.getString(key)!.trim()
        : fallback;
  }

  Future<bool> setFamilyDisplayName({
    required String familyId,
    required String viewerId,
    required String memberUserId,
    required String displayName,
  }) async {
    final key = 'family_display_name_${familyId}_${viewerId}_$memberUserId';
    return await prefs.setString(key, displayName.trim());
  }
}
