import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

class AssetLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool isDarkBackground;
  final bool showTagline;

  const AssetLogo({
    super.key,
    this.size = 80,
    this.showText = true,
    this.isDarkBackground = false,
    this.showTagline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: _LogoPainter(),
        ),
        if (showText) ...[
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Asset',
                  style: GoogleFonts.outfit(
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w800,
                    color: isDarkBackground ? Colors.white : AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: 'Ventory',
                  style: GoogleFonts.outfit(
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w800,
                    color: isDarkBackground ? const Color(0xFF8B9FFF) : AppColors.primaryPurple,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            AppStrings.appTagline,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: isDarkBackground ? AppColors.textWhite70 : AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Glowing subtle shadow beneath logo
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7E43F8).withAlpha(100),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.65), radius: w * 0.45));
    canvas.drawCircle(Offset(w * 0.5, h * 0.65), w * 0.4, glowPaint);

    // Tag (Floating upward)
    final tagPath = Path();
    tagPath.moveTo(w * 0.52, h * 0.12);
    tagPath.lineTo(w * 0.76, h * 0.28);
    tagPath.lineTo(w * 0.56, h * 0.56);
    tagPath.lineTo(w * 0.34, h * 0.42);
    tagPath.close();

    final tagGradient = const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        Color(0xFF38E1FF),
        Color(0xFF5560FF),
        Color(0xFF9E4BFA),
      ],
    ).createShader(Rect.fromLTWH(w * 0.3, h * 0.1, w * 0.5, h * 0.5));

    final tagPaint = Paint()
      ..shader = tagGradient
      ..style = PaintingStyle.fill;
    canvas.drawPath(tagPath, tagPaint);

    // Tag Hole
    final holePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.62, h * 0.23), w * 0.038, holePaint);

    // Isometric 3D Box - Front Left Panel
    final leftPanel = Path();
    leftPanel.moveTo(w * 0.50, h * 0.52);
    leftPanel.lineTo(w * 0.22, h * 0.40);
    leftPanel.lineTo(w * 0.22, h * 0.68);
    leftPanel.lineTo(w * 0.50, h * 0.84);
    leftPanel.close();

    final leftPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6B72FF), Color(0xFF432CB8)],
      ).createShader(Rect.fromLTWH(w * 0.2, h * 0.4, w * 0.3, h * 0.45));
    canvas.drawPath(leftPanel, leftPaint);

    // Isometric 3D Box - Front Right Panel
    final rightPanel = Path();
    rightPanel.moveTo(w * 0.50, h * 0.52);
    rightPanel.lineTo(w * 0.78, h * 0.40);
    rightPanel.lineTo(w * 0.78, h * 0.68);
    rightPanel.lineTo(w * 0.50, h * 0.84);
    rightPanel.close();

    final rightPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFA660FF), Color(0xFF652CB8)],
      ).createShader(Rect.fromLTWH(w * 0.5, h * 0.4, w * 0.3, h * 0.45));
    canvas.drawPath(rightPanel, rightPaint);

    // Flaps (Left flap)
    final leftFlap = Path();
    leftFlap.moveTo(w * 0.22, h * 0.40);
    leftFlap.lineTo(w * 0.12, h * 0.34);
    leftFlap.lineTo(w * 0.36, h * 0.30);
    leftFlap.lineTo(w * 0.48, h * 0.38);
    leftFlap.close();

    final flapPaintLeft = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF7585FF), Color(0xFF5662E8)],
      ).createShader(Rect.fromLTWH(w * 0.1, h * 0.3, w * 0.4, h * 0.15));
    canvas.drawPath(leftFlap, flapPaintLeft);

    // Flaps (Right flap)
    final rightFlap = Path();
    rightFlap.moveTo(w * 0.78, h * 0.40);
    rightFlap.lineTo(w * 0.88, h * 0.34);
    rightFlap.lineTo(w * 0.64, h * 0.30);
    rightFlap.lineTo(w * 0.52, h * 0.38);
    rightFlap.close();

    final flapPaintRight = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFB472FF), Color(0xFF8643E8)],
      ).createShader(Rect.fromLTWH(w * 0.5, h * 0.3, w * 0.4, h * 0.15));
    canvas.drawPath(rightFlap, flapPaintRight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
