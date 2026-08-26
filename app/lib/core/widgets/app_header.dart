import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../utils/wave_clipper.dart';

/// Reusable brand header that unifies the previously divergent "hero" designs.
///
/// Two variants:
///  * [AppHeader.hero]  – gradient wave header (Home, Auth). Supports a logo,
///    title/subtitle, a leading action and trailing actions.
///  * [AppHeader.solid] – solid dark rounded header used by list screens
///    (Assets) with title, subtitle and trailing actions.
class AppHeader extends StatelessWidget {
  const AppHeader.hero({
    super.key,
    this.leading,
    this.logo,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.bottom,
  })  : variant = _Variant.hero,
        assert(logo == null || subtitle == null,
            'Provide either a logo block or a subtitle, not both');

  const AppHeader.solid({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.bottom,
  })  : variant = _Variant.solid,
        logo = null;

  final _Variant variant;
  final Widget? leading;
  final Widget? logo;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return variant == _Variant.hero ? _buildHero(context) : _buildSolid(context);
  }

  Widget _buildHero(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null || actions.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              leading ?? const SizedBox(width: 40),
              Row(children: actions),
            ],
          ),
        if (leading != null || actions.isNotEmpty) const SizedBox(height: 8),
        if (logo != null) logo!,
        if (logo != null) const SizedBox(height: 12),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: logo != null ? 22 : 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFFB3A8D2),
            ),
          ),
        ],
        if (bottom != null) ...[
          const SizedBox(height: 16),
          bottom!,
        ],
      ],
    );

    return ClipPath(
      clipper: WaveClipper(),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        padding: EdgeInsets.fromLTRB(
          20,
          topPad + (leading != null || actions.isNotEmpty ? 16 : 28),
          20,
          44,
        ),
        child: content,
      ),
    );
  }

  Widget _buildSolid(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.heroDarkBg,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        topPad + 16,
        12,
        bottom != null ? 16 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFFB8AED6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          if (bottom != null) ...[const SizedBox(height: 12), bottom!],
        ],
      ),
    );
  }
}

enum _Variant { hero, solid }

/// A circular, translucent icon button used inside dark hero headers.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: Colors.white.withAlpha(40),
        highlightColor: Colors.white.withAlpha(20),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white.withAlpha(40) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
