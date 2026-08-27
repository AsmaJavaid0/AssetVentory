import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../widgets/profile_section.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  static Future<void> navigateTo(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AppearanceScreen()),
    );
  }

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  final _prefs = serviceLocator.preferences;
  late ThemeMode _currentMode;

  @override
  void initState() {
    super.initState();
    _currentMode = _prefs.themeMode;
  }

  Future<void> _setTheme(ThemeMode mode) async {
    setState(() => _currentMode = mode);
    await _prefs.setThemeMode(mode);
    _prefs.triggerHaptic();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Appearance',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileSection(
              title: 'App Theme',
              children: [
                _buildThemeTile(
                  mode: ThemeMode.light,
                  title: 'Light Theme',
                  subtitle: 'Clean lavender and white interface (Default)',
                  icon: Icons.light_mode_rounded,
                ),
                _buildThemeTile(
                  mode: ThemeMode.dark,
                  title: 'Dark Theme',
                  subtitle: 'Deep violet and nighttime contrast',
                  icon: Icons.dark_mode_rounded,
                ),
                _buildThemeTile(
                  mode: ThemeMode.system,
                  title: 'System Default',
                  subtitle: 'Match your device operating system settings',
                  icon: Icons.settings_brightness_rounded,
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withAlpha(16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.palette_outlined, color: AppColors.primaryPurple, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Branded Palette',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'AssetVentory uses high-contrast accessibility and modern glassmorphism purple accents.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
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

  Widget _buildThemeTile({
    required ThemeMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _currentMode == mode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _setTheme(mode),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryPurple.withAlpha(20)
                      : const Color(0xFFF3F0F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppColors.primaryPurple : AppColors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? AppColors.primaryPurple : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primaryPurple,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
