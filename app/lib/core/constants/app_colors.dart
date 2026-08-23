import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Dark Hero Area (Deep violet-purple)
  static const Color heroDarkBg = Color(0xFF1B0F38);
  static const Color heroDarkBgDarker = Color(0xFF120826);
  static const Color heroCardBg = Color(0xFF281850);

  // Soft Light Lavender Interface
  static const Color scaffoldBg = Color(0xFFF6F4FC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color lightLavender = Color(0xFFEDE9F8);
  static const Color lightLavenderBorder = Color(0xFFE2DCF3);

  // Vibrant Blue/Purple Gradients
  static const Color primaryPurple = Color(0xFF7E43F8);
  static const Color primaryBlue = Color(0xFF4C66FF);
  static const Color vibrantViolet = Color(0xFF9854FA);
  static const Color accentCyan = Color(0xFF00D2FF);

  // Text Colors
  static const Color textPrimary = Color(0xFF1E1535);
  static const Color textSecondary = Color(0xFF756F86);
  static const Color textMuted = Color(0xFFA09BAC);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textWhite70 = Color(0xB3FFFFFF);

  // Input & Borders
  static const Color inputBorder = Color(0xFFE4DFEE);
  static const Color inputFill = Color(0xFFFFFFFF);
  static const Color inputHint = Color(0xFFA8A3B5);

  // Status & Accents
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF150A2E),
      Color(0xFF24134B),
    ],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF4D65FF),
      Color(0xFF8B47FA),
    ],
  );

  static const LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF3EE7FF),
      Color(0xFF5367FF),
      Color(0xFF9E4BFA),
    ],
  );

  static const LinearGradient subtleCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF9F8FD),
      Color(0xFFF1EEFB),
    ],
  );
}
