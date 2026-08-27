import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/asset_logo.dart';
import '../widgets/profile_section.dart';
import '../widgets/profile_settings_tile.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static Future<void> navigateTo(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AboutScreen()),
    );
  }

  static const String appVersion = '1.0.0+1';

  static void showHelpAndSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withAlpha(16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.help_outline_rounded, color: AppColors.primaryPurple),
                ),
                const SizedBox(width: 12),
                Text(
                  'Help & Support',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _faqItem(
                    'How is my asset data stored?',
                    'Your personal assets and documents are stored securely on your local device using an encrypted SQLite database. When you use Family Sharing, shared items are safely synchronized via Firebase Firestore.',
                  ),
                  _faqItem(
                    'How do Task Reminders work?',
                    'AssetVentory schedules native device alarms and push notifications for your scheduled maintenance tasks and warranty expiries according to your reminder preferences.',
                  ),
                  _faqItem(
                    'Can I invite family members?',
                    'Yes! Navigate to the Family Sharing tab to create a family hub or invite members via their email.',
                  ),
                  _faqItem(
                    'How can I get assistance?',
                    'If you experience any issues or have questions, contact the support team at support@assetventory.app.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Privacy Policy',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  'AssetVentory is built with a privacy-first mindset.\n\n'
                  '1. Data Collection & Privacy\n'
                  'We only collect information strictly required to authenticate your account and sync your shared items when you use family features.\n\n'
                  '2. Local Storage\n'
                  'Your personal assets, receipts, and images stay strictly on your device unless you explicitly share them with family members.\n\n'
                  '3. Cloud Security\n'
                  'All remote communications with Firebase are encrypted in transit and at rest with strict Firestore security rules.\n\n'
                  '4. No Data Selling\n'
                  'We do not sell, rent, or monetize your personal or asset data.\n\n'
                  'Last updated: August 2026',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void showTermsOfService(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Terms of Service',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  'Welcome to AssetVentory.\n\n'
                  '1. Acceptance of Terms\n'
                  'By accessing and using AssetVentory, you agree to comply with these terms of service.\n\n'
                  '2. Proper Usage\n'
                  'You agree not to misuse the application or attempt unauthorized access to another user’s assets or family spaces.\n\n'
                  '3. Intellectual Property\n'
                  'All logos, trademarks, designs, and software belong to AssetVentory.\n\n'
                  '4. Termination\n'
                  'You may stop using the app and delete your account at any time via the Profile module.\n\n'
                  'Last updated: August 2026',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _faqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F8FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFEBF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            answer,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'About AssetVentory',
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFEFEBF6)),
              ),
              child: Column(
                children: [
                  const AssetLogo(size: 64, showText: true),
                  const SizedBox(height: 12),
                  Text(
                    'Manage your assets. Never forget.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withAlpha(16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Version $appVersion',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ProfileSection(
              title: 'Information & Legal',
              children: [
                ProfileSettingsTile(
                  icon: Icons.help_center_outlined,
                  title: 'Help & Support',
                  onTap: () => showHelpAndSupport(context),
                ),
                ProfileSettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () => showPrivacyPolicy(context),
                ),
                ProfileSettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  onTap: () => showTermsOfService(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
