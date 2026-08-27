import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../widgets/profile_section.dart';
import '../widgets/profile_settings_tile.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  static Future<void> navigateTo(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AppSettingsScreen()),
    );
  }

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _prefs = serviceLocator.preferences;

  late int _defaultReminderMinutes;
  late String _defaultTaskPriority;
  late String _defaultAssetView;
  late bool _confirmBeforeDelete;
  late bool _hapticFeedback;

  final Map<int, String> _reminderOptions = {
    0: 'At task time',
    5: '5 minutes before',
    10: '10 minutes before',
    15: '15 minutes before',
    30: '30 minutes before',
    60: '1 hour before',
    1440: '1 day before',
  };

  final Map<String, String> _priorityOptions = {
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
  };

  final Map<String, String> _assetViewOptions = {
    'list': 'List View',
    'grid': 'Grid View',
  };

  @override
  void initState() {
    super.initState();
    _defaultReminderMinutes = _prefs.defaultReminderMinutes;
    _defaultTaskPriority = _prefs.defaultTaskPriority;
    _defaultAssetView = _prefs.defaultAssetView;
    _confirmBeforeDelete = _prefs.confirmBeforeDelete;
    _hapticFeedback = _prefs.hapticFeedbackEnabled;
  }

  Future<void> _showReminderPicker() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Default Task Reminder',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ..._reminderOptions.entries.map((entry) {
                final isSelected = entry.key == _defaultReminderMinutes;
                return ListTile(
                  title: Text(
                    entry.value,
                    style: GoogleFonts.outfit(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.primaryPurple : AppColors.textPrimary,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded, color: AppColors.primaryPurple)
                      : null,
                  onTap: () => Navigator.pop(context, entry.key),
                );
              }),
            ],
          ),
        ),
      ),
    );

    if (selected != null && selected != _defaultReminderMinutes) {
      await _prefs.setDefaultReminderMinutes(selected);
      setState(() => _defaultReminderMinutes = selected);
      _prefs.triggerHaptic();
    }
  }

  Future<void> _showPriorityPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Default Task Priority',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ..._priorityOptions.entries.map((entry) {
                final isSelected = entry.key == _defaultTaskPriority;
                return ListTile(
                  title: Text(
                    entry.value,
                    style: GoogleFonts.outfit(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.primaryPurple : AppColors.textPrimary,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded, color: AppColors.primaryPurple)
                      : null,
                  onTap: () => Navigator.pop(context, entry.key),
                );
              }),
            ],
          ),
        ),
      ),
    );

    if (selected != null && selected != _defaultTaskPriority) {
      await _prefs.setDefaultTaskPriority(selected);
      setState(() => _defaultTaskPriority = selected);
      _prefs.triggerHaptic();
    }
  }

  Future<void> _showAssetViewPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Default Asset View',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ..._assetViewOptions.entries.map((entry) {
                final isSelected = entry.key == _defaultAssetView;
                return ListTile(
                  title: Text(
                    entry.value,
                    style: GoogleFonts.outfit(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.primaryPurple : AppColors.textPrimary,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded, color: AppColors.primaryPurple)
                      : null,
                  onTap: () => Navigator.pop(context, entry.key),
                );
              }),
            ],
          ),
        ),
      ),
    );

    if (selected != null && selected != _defaultAssetView) {
      await _prefs.setDefaultAssetView(selected);
      setState(() => _defaultAssetView = selected);
      _prefs.triggerHaptic();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'App Settings',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            ProfileSection(
              title: 'Task Defaults',
              children: [
                ProfileSettingsTile(
                  icon: Icons.alarm_rounded,
                  title: 'Default Task Reminder',
                  valueText: _reminderOptions[_defaultReminderMinutes] ?? '15 mins before',
                  onTap: _showReminderPicker,
                ),
                ProfileSettingsTile(
                  icon: Icons.flag_rounded,
                  title: 'Default Task Priority',
                  valueText: _priorityOptions[_defaultTaskPriority] ?? 'Medium',
                  onTap: _showPriorityPicker,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ProfileSection(
              title: 'Asset Experience',
              children: [
                ProfileSettingsTile(
                  icon: Icons.view_quilt_rounded,
                  title: 'Default Asset View',
                  valueText: _assetViewOptions[_defaultAssetView] ?? 'List',
                  onTap: _showAssetViewPicker,
                ),
                ProfileSettingsTile(
                  icon: Icons.delete_sweep_rounded,
                  title: 'Confirm Before Delete',
                  subtitle: 'Show confirmation prompt when removing assets or tasks',
                  isSwitch: true,
                  switchValue: _confirmBeforeDelete,
                  onSwitchChanged: (val) async {
                    await _prefs.setConfirmBeforeDelete(val);
                    setState(() => _confirmBeforeDelete = val);
                    _prefs.triggerHaptic();
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            ProfileSection(
              title: 'Feedback & Interaction',
              children: [
                ProfileSettingsTile(
                  icon: Icons.vibration_rounded,
                  title: 'Haptic Feedback',
                  subtitle: 'Vibrate slightly on tap interactions and switches',
                  isSwitch: true,
                  switchValue: _hapticFeedback,
                  onSwitchChanged: (val) async {
                    await _prefs.setHapticFeedbackEnabled(val);
                    setState(() => _hapticFeedback = val);
                    if (val) _prefs.triggerHaptic();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
