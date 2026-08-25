import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../onboarding/screens/onboarding_screen.dart';

import '../../home/screens/main_navigation_screen.dart';

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
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final hasSeenOnboarding = snapshot.data ?? false;

        if (!hasSeenOnboarding) {
          return const OnboardingScreen();
        }

        return const MainNavigationScreen();
      },
    );
  }
}