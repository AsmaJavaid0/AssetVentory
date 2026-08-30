import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/screens/login_signup_screen.dart';

class FamilyAuthPrompt extends StatelessWidget {
  final VoidCallback? onSignedIn;
  final bool isModal;

  const FamilyAuthPrompt({
    super.key,
    this.onSignedIn,
    this.isModal = false,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onSignedIn}) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => FamilyAuthPrompt(
          onSignedIn: onSignedIn,
          isModal: true,
        ),
      );

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isModal) ...[
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.lightLavenderBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_rounded,
                color: AppColors.primaryPurple,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Sign In for Family Sharing',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your personal assets remain local and private on this device. Sign in to create a private family circle, invite members, and selectively share assets.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (isModal) {
                    Navigator.of(context).pop();
                  }
                  final signedIn = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const LoginSignupScreen(returnToCaller: true),
                    ),
                  );
                  if (signedIn == true) {
                    onSignedIn?.call();
                  }
                },
                icon: const Icon(Icons.login_rounded, size: 20),
                label: Text(
                  'Sign In / Create Account',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            if (isModal) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Continue Exploring Offline',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}
