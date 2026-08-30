import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../home/screens/main_navigation_screen.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import 'login_signup_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> _hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_seen_onboarding') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasSeenOnboarding(),
      builder: (context, onboardingSnapshot) {
        if (onboardingSnapshot.connectionState != ConnectionState.done) {
          return const _LoadingScreen();
        }

        if (onboardingSnapshot.hasError) {
          return _ErrorScreen(
            message: 'Unable to load app settings. Please restart the app.',
          );
        }

        if (!(onboardingSnapshot.data ?? false)) {
          return const OnboardingScreen();
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            final user = authSnapshot.data;
            if (user == null) {
              return const LoginSignupScreen();
            }

            return const MainNavigationScreen();
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
