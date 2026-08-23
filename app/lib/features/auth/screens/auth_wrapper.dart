import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import 'login_signup_screen.dart';
import '../../home/screens/main_navigation_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> _hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_seen_onboarding') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user is already authenticated
        if (snapshot.hasData && snapshot.data != null) {
          return const MainNavigationScreen();
        }

        // If not authenticated, check onboarding status
        return FutureBuilder<bool>(
          future: _hasSeenOnboarding(),
          builder: (context, onboardingSnapshot) {
            if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final hasSeenOnboarding = onboardingSnapshot.data ?? false;
            if (!hasSeenOnboarding) {
              return const OnboardingScreen();
            }

            return const LoginSignupScreen();
          },
        );
      },
    );
  }
}
