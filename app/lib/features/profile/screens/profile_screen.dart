import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/error_formatter.dart';
import '../../auth/services/auth_service.dart';
import '../../family/models/family_model.dart';
import '../../family/screens/family_share_screen.dart';
import '../widgets/change_password_sheet.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_section.dart';
import '../widgets/profile_settings_tile.dart';
import 'about_screen.dart';
import 'appearance_screen.dart';
import 'app_settings_screen.dart';
import 'data_storage_screen.dart';
import 'edit_profile_screen.dart';
import 'login_security_screen.dart';

class ProfileScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const ProfileScreen({super.key, this.onNavigateTab});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _authService = AuthService();
  final _familyRepository = serviceLocator.familyRepository;
  final _prefs = serviceLocator.preferences;
  final _taskNotificationService = serviceLocator.taskNotificationService;
  final _fcmService = serviceLocator.fcmService;

  FamilyModel? _family;
  bool _isLoadingFamily = true;
  bool _taskRemindersOn = true;
  bool _pushNotificationsOn = true;
  bool _isLoggingOut = false;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
    _loadFamilyInfo();
  }

  void _loadNotificationPreferences() {
    _taskRemindersOn = _prefs.taskRemindersEnabled;
    _pushNotificationsOn = _prefs.pushNotificationsEnabled;
  }

  Future<void> _loadFamilyInfo() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingFamily = false);
      return;
    }

    try {
      final family = await _familyRepository.getUserFamily(user.uid);
      if (!mounted) return;
      setState(() {
        _family = family;
        _isLoadingFamily = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingFamily = false);
    }
  }

  Future<void> _handleEditProfile() async {
    final updated = await EditProfileScreen.navigateTo(context);
    if (updated == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _handleFamilyTap() async {
    if (widget.onNavigateTab != null) {
      // Switch to Family tab (Index 2 in MainNavigation)
      widget.onNavigateTab!(2);
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FamilyShareScreen()),
      );
      if (mounted) _loadFamilyInfo();
    }
  }

  Future<void> _toggleTaskReminders(bool value) async {
    setState(() => _taskRemindersOn = value);
    await _prefs.setTaskRemindersEnabled(value);
    _prefs.triggerHaptic();

    if (value) {
      final granted = await _taskNotificationService.requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable notification permissions in system settings'),
          ),
        );
      }
    } else {
      await _taskNotificationService.cancelAllNotifications();
    }
  }

  Future<void> _togglePushNotifications(bool value) async {
    setState(() => _pushNotificationsOn = value);
    await _prefs.setPushNotificationsEnabled(value);
    _prefs.triggerHaptic();

    if (value) {
      await _fcmService.registerDeviceToken();
    } else {
      await _fcmService.unregisterDeviceToken();
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log Out?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to log out of AssetVentory?',
          style: GoogleFonts.outfit(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoggingOut = true);

    try {
      // 1. Unregister FCM token
      await _fcmService.unregisterDeviceToken();

      // 2. Sign out via AuthService
      await _authService.signOut();

      if (!mounted) return;
      setState(() => _isLoggingOut = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorFormatter.format(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleDeleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Account?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: AppColors.error,
          ),
        ),
        content: Text(
          'This permanently deletes your account and associated cloud data.\n\nThis action cannot be undone.',
          style: GoogleFonts.outfit(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeletingAccount = true);

    try {
      // 1. Unregister FCM token
      await _fcmService.unregisterDeviceToken();

      // 2. Delete user account from Firebase
      await user.delete();

      if (!mounted) return;
      setState(() => _isDeletingAccount = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);

      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log out and log back in to verify your identity before deleting your account.'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorFormatter.format(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorFormatter.format(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data ?? _auth.currentUser;
        final familySubtitle = _isLoadingFamily
            ? 'Checking status...'
            : (_family != null ? _family!.name : 'Not connected');

        return Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          appBar: AppBar(
            title: Text(
              'Profile',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              children: [
                // 1. Profile Header
                ProfileHeader(
                  user: user,
                  onEditProfile: _handleEditProfile,
                ),
                const SizedBox(height: 24),

                // 2. ACCOUNT Section
                ProfileSection(
                  title: 'Account',
                  children: [
                    ProfileSettingsTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Edit Profile',
                      onTap: _handleEditProfile,
                    ),
                    ProfileSettingsTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Change Password',
                      onTap: () => ChangePasswordSheet.show(context),
                    ),
                    ProfileSettingsTile(
                      icon: Icons.shield_outlined,
                      title: 'Login & Security',
                      onTap: () => LoginSecurityScreen.navigateTo(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 3. FAMILY Section
                ProfileSection(
                  title: 'Family',
                  children: [
                    ProfileSettingsTile(
                      icon: Icons.groups_outlined,
                      title: 'Family Sharing',
                      subtitle: familySubtitle,
                      valueText: _family != null ? 'Connected' : 'Set Up',
                      onTap: _handleFamilyTap,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 4. NOTIFICATIONS Section
                ProfileSection(
                  title: 'Notifications',
                  children: [
                    ProfileSettingsTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Task Reminders',
                      isSwitch: true,
                      switchValue: _taskRemindersOn,
                      onSwitchChanged: _toggleTaskReminders,
                    ),
                    ProfileSettingsTile(
                      icon: Icons.send_to_mobile_rounded,
                      title: 'Push Notifications',
                      isSwitch: true,
                      switchValue: _pushNotificationsOn,
                      onSwitchChanged: _togglePushNotifications,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 5. PREFERENCES Section
                ProfileSection(
                  title: 'Preferences',
                  children: [
                    ProfileSettingsTile(
                      icon: Icons.settings_outlined,
                      title: 'App Settings',
                      onTap: () => AppSettingsScreen.navigateTo(context),
                    ),
                    ProfileSettingsTile(
                      icon: Icons.palette_outlined,
                      title: 'Appearance',
                      onTap: () => AppearanceScreen.navigateTo(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 6. PRIVACY & DATA Section
                ProfileSection(
                  title: 'Privacy & Data',
                  children: [
                    ProfileSettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy & Security',
                      onTap: () => AboutScreen.showPrivacyPolicy(context),
                    ),
                    ProfileSettingsTile(
                      icon: Icons.storage_rounded,
                      title: 'Data & Storage',
                      onTap: () => DataStorageScreen.navigateTo(context),
                    ),
                    ProfileSettingsTile(
                      icon: Icons.delete_forever_rounded,
                      isDestructive: true,
                      title: _isDeletingAccount ? 'Deleting Account...' : 'Delete Account',
                      subtitle: 'Permanently remove your account and data',
                      onTap: _isDeletingAccount ? null : _handleDeleteAccount,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 7. ABOUT Section
                ProfileSection(
                  title: 'About',
                  children: [
                    ProfileSettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About AssetVentory',
                      valueText: 'v${AboutScreen.appVersion}',
                      onTap: () => AboutScreen.navigateTo(context),
                    ),
                    ProfileSettingsTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      onTap: () => AboutScreen.showHelpAndSupport(context),
                    ),
                    ProfileSettingsTile(
                      icon: Icons.description_outlined,
                      title: 'Privacy Policy',
                      onTap: () => AboutScreen.showPrivacyPolicy(context),
                    ),
                    ProfileSettingsTile(
                      icon: Icons.gavel_rounded,
                      title: 'Terms of Service',
                      onTap: () => AboutScreen.showTermsOfService(context),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // 8. Log Out Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: (_isLoggingOut || _isDeletingAccount) ? null : _handleLogout,
                    icon: _isLoggingOut
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                          )
                        : const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                    label: Text(
                      _isLoggingOut ? 'Logging out...' : 'Log Out',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFDCED4), width: 1.5),
                      backgroundColor: const Color(0xFFFFF5F5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        );
      },
    );
  }
}
