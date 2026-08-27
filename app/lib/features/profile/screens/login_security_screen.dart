import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../widgets/profile_section.dart';
import '../widgets/profile_settings_tile.dart';

class LoginSecurityScreen extends StatelessWidget {
  const LoginSecurityScreen({super.key});

  static Future<void> navigateTo(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginSecurityScreen()),
    );
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'Unknown';
    return DateFormat.yMMMd().add_jm().format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final providers = user?.providerData.map((p) => p.providerId).toList() ?? [];

    String providerLabel = 'None';
    if (providers.contains('google.com') && providers.contains('password')) {
      providerLabel = 'Google & Password';
    } else if (providers.contains('google.com')) {
      providerLabel = 'Google Sign-In';
    } else if (providers.contains('password')) {
      providerLabel = 'Email & Password';
    } else if (providers.isNotEmpty) {
      providerLabel = providers.first;
    }

    final isEmailVerified = user?.emailVerified ?? false;
    final createdDate = _formatDate(user?.metadata.creationTime);
    final lastSignInDate = _formatDate(user?.metadata.lastSignInTime);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Login & Security',
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
              title: 'Account Authentication',
              children: [
                ProfileSettingsTile(
                  icon: Icons.vpn_key_rounded,
                  title: 'Primary Provider',
                  subtitle: providerLabel,
                  showChevron: false,
                ),
                ProfileSettingsTile(
                  icon: Icons.alternate_email_rounded,
                  title: 'Registered Email',
                  subtitle: user?.email ?? 'Not provided',
                  showChevron: false,
                ),
                ProfileSettingsTile(
                  icon: isEmailVerified ? Icons.verified_user_rounded : Icons.mark_email_unread_rounded,
                  iconColor: isEmailVerified ? AppColors.success : AppColors.warning,
                  title: 'Email Verification',
                  valueText: isEmailVerified ? 'Verified' : 'Unverified',
                  showChevron: false,
                ),
              ],
            ),
            const SizedBox(height: 24),
            ProfileSection(
              title: 'Session & Identity',
              children: [
                ProfileSettingsTile(
                  icon: Icons.badge_outlined,
                  title: 'User ID (UID)',
                  subtitle: user?.uid ?? 'None',
                  customTrailing: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primaryPurple),
                    tooltip: 'Copy User ID',
                    onPressed: () {
                      if (user?.uid != null) {
                        Clipboard.setData(ClipboardData(text: user!.uid));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User ID copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ),
                ProfileSettingsTile(
                  icon: Icons.calendar_today_rounded,
                  title: 'Account Created',
                  subtitle: createdDate,
                  showChevron: false,
                ),
                ProfileSettingsTile(
                  icon: Icons.access_time_rounded,
                  title: 'Last Sign-In',
                  subtitle: lastSignInDate,
                  showChevron: false,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEFEBF6)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.primaryPurple, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All sessions are token-authenticated via Firebase Authentication with end-to-end security.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
