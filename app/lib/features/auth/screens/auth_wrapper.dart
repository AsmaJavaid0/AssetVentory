import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../onboarding/screens/onboarding_screen.dart';

import '../../home/screens/main_navigation_screen.dart';
import '../../../core/theme/app_settings.dart';

class AuthWrapper extends StatelessWidget {
  final AppSettings settings;
  const AuthWrapper({super.key, required this.settings});

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
          return OnboardingScreen(settings: settings);
        }

        return MainNavigationScreen(settings: settings);
      },
    );
  }
}
