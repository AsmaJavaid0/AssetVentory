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

  // --- Default Task Reminder (Minutes) ---
  int get defaultReminderMinutes => _prefs?.getInt(_keyDefaultReminderMinutes) ?? 15;

  Future<bool> setDefaultReminderMinutes(int minutes) async => await prefs.setInt(_keyDefaultReminderMinutes, minutes);

  // --- Default Task Priority ('low', 'medium', 'high') ---
  String get defaultTaskPriority => _prefs?.getString(_keyDefaultTaskPriority) ?? 'medium';

  Future<bool> setDefaultTaskPriority(String priority) async => await prefs.setString(_keyDefaultTaskPriority, priority);

  // --- Default Asset View ('list', 'grid') ---
  String get defaultAssetView => _prefs?.getString(_keyDefaultAssetView) ?? 'list';

  Future<bool> setDefaultAssetView(String view) async => await prefs.setString(_keyDefaultAssetView, view);

  // --- Confirm Before Delete ---
  bool get confirmBeforeDelete => _prefs?.getBool(_keyConfirmBeforeDelete) ?? true;

  Future<bool> setConfirmBeforeDelete(bool enabled) async => await prefs.setBool(_keyConfirmBeforeDelete, enabled);

  // --- Haptic Feedback ---
  bool get hapticFeedbackEnabled => _prefs?.getBool(_keyHapticFeedback) ?? true;

  Future<bool> setHapticFeedbackEnabled(bool enabled) async => await prefs.setBool(_keyHapticFeedback, enabled);

  void triggerHaptic() {
    if (hapticFeedbackEnabled) HapticFeedback.lightImpact();
  }

  // --- Theme Mode ---
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

  // --- Notification Toggles ---
  bool get taskRemindersEnabled => _prefs?.getBool(_keyTaskRemindersEnabled) ?? true;

  Future<bool> setTaskRemindersEnabled(bool enabled) async => await prefs.setBool(_keyTaskRemindersEnabled, enabled);

  bool get pushNotificationsEnabled => _prefs?.getBool(_keyPushNotificationsEnabled) ?? true;

  Future<bool> setPushNotificationsEnabled(bool enabled) async => await prefs.setBool(_keyPushNotificationsEnabled, enabled);

  // --- Family display names ---
  // These are intentionally local to this device/user. Renaming a family
  // member changes only how that member is labelled on this user's screen.
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

  // --- Family Share PIN ---
  // Stored locally on this device. Protects access to the family sharing screen
  // and shared assets.
  String? getFamilySharePin({
    required String familyId,
    String? userId,
  }) {
    if (userId != null && userId.isNotEmpty) {
      final userPin = _prefs?.getString('family_share_pin_${familyId}_$userId');
      if (userPin != null && userPin.isNotEmpty) return userPin;
    }
    return _prefs?.getString('family_share_pin_$familyId');
  }

  bool isFamilyPinEnabled({
    required String familyId,
    String? userId,
  }) {
    final pin = getFamilySharePin(familyId: familyId, userId: userId);
    return pin != null && pin.isNotEmpty;
  }

  Future<bool> setFamilySharePin({
    required String familyId,
    String? userId,
    required String pin,
  }) async {
    if (userId != null && userId.isNotEmpty) {
      await prefs.setString('family_share_pin_${familyId}_$userId', pin.trim());
    }
    return await prefs.setString('family_share_pin_$familyId', pin.trim());
  }

  Future<bool> removeFamilySharePin({
    required String familyId,
    String? userId,
  }) async {
    if (userId != null && userId.isNotEmpty) {
      await prefs.remove('family_share_pin_${familyId}_$userId');
    }
    return await prefs.remove('family_share_pin_$familyId');
  }
}

