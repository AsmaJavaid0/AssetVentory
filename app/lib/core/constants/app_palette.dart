import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Semantic, theme-aware color tokens for AssetVentory.
///
/// AppColors holds the raw brand palette plus the two ThemeData objects.
/// AppPalette resolves a single set of *surface / border / text* tokens that
/// correctly adapt to light and dark mode, eliminating the scattered
/// hard-coded hex values (0xFFEFEBF6, 0xFFE4DFEE, 0xFF9E98AD, ...) that
/// previously lived in every screen.
///
/// Usage:
///   final palette = AppPalette.of(context);
///   Container(decoration: BoxDecoration(color: palette.surface, border: Border.all(color: palette.border)));
class AppPalette {
  AppPalette._({
    required this.brightness,
    required this.border,
    required this.divider,
    required this.inputBorder,
    required this.chipBackground,
    required this.chipBorder,
    required this.chipSelectedBackground,
    required this.surfaceVariant,
    required this.iconMuted,
    required this.textMuted,
    required this.textSubtle,
    required this.handle,
    required this.controlBorder,
    required this.heroSubtitle,
    required this.googleText,
    required this.successSoft,
    required this.errorSoft,
    required this.warningSoft,
    required this.overlay,
  });

  final Brightness brightness;
  final Color surface;
  final Color surfaceContainer;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color border;
  final Color divider;
  final Color inputBorder;
  final Color chipBackground;
  final Color chipBorder;
  final Color chipSelectedBackground;
  final Color surfaceVariant;
  final Color iconMuted;
  final Color textMuted;
  final Color textSubtle;
  final Color handle;
  final Color controlBorder;
  final Color heroSubtitle;
  final Color googleText;
  final Color successSoft;
  final Color errorSoft;
  final Color warningSoft;
  final Color overlay;

  static AppPalette of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? _dark : _light;
  }

  static final AppPalette _light = AppPalette._(
    brightness: Brightness.light,
    surface: AppColors.surfaceWhite,
    surfaceContainer: AppColors.lightLavender,
    onSurface: AppColors.textPrimary,
    onSurfaceMuted: AppColors.textSecondary,
    border: const Color(0xFFECE8F5),
    divider: const Color(0xFFECE8F5),
    inputBorder: const Color(0xFFE4DFEE),
    chipBackground: AppColors.scaffoldBg,
    chipBorder: const Color(0xFFE5E1F0),
    chipSelectedBackground: AppColors.primaryPurple,
    surfaceVariant: AppColors.lightLavender,
    iconMuted: const Color(0xFF9E98AD),
    textMuted: AppColors.textMuted,
    textSubtle: const Color(0xFF6B52A3),
    handle: const Color(0xFFDDD8E8),
    controlBorder: const Color(0xFFC7C1D8),
    heroSubtitle: const Color(0xFFB8AED6),
    googleText: const Color(0xFF2C243B),
    successSoft: const Color(0xFF10B981).withAlpha(28),
    errorSoft: const Color(0xFFEF4444).withAlpha(26),
    warningSoft: const Color(0xFFF59E0B).withAlpha(26),
    overlay: Colors.black.withAlpha(90),
  );

  static final AppPalette _dark = AppPalette._(
    brightness: Brightness.dark,
    surface: AppColors.heroCardBg,
    surfaceContainer: const Color(0xFF241640),
    onSurface: AppColors.textWhite,
    onSurfaceMuted: AppColors.textWhite70,
    border: const Color(0xFF332B50),
    divider: const Color(0xFF332B50),
    inputBorder: const Color(0xFF3B3260),
    chipBackground: AppColors.heroCardBg,
    chipBorder: const Color(0xFF3B3260),
    chipSelectedBackground: AppColors.primaryPurple,
    surfaceVariant: const Color(0xFF241640),
    iconMuted: const Color(0xFF8E87A8),
    textMuted: const Color(0xFF9A92AE),
    textSubtle: const Color(0xFFB39BFF),
    handle: const Color(0xFF473C66),
    controlBorder: const Color(0xFF4A4070),
    heroSubtitle: const Color(0xFFC4BAE5),
    googleText: const Color(0xFF1E1535),
    successSoft: const Color(0xFF10B981).withAlpha(40),
    errorSoft: const Color(0xFFEF4444).withAlpha(38),
    warningSoft: const Color(0xFFF59E0B).withAlpha(38),
    overlay: Colors.black.withAlpha(120),
  );

  bool get isDark => brightness == Brightness.dark;

  /// Tint used for soft icon containers (e.g. list leading icons, avatars).
  Color tint(Color base) => base.withAlpha(20);
}
