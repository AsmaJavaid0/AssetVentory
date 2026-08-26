import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_settings.dart';
import 'features/auth/screens/auth_wrapper.dart';
import 'core/di/service_locator.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize the service locator
  await setupServiceLocator();

  final settings = await AppSettings.load();
  runApp(AssetVentoryApp(settings: settings));
}

class AssetVentoryApp extends StatelessWidget {
  final AppSettings settings;
  const AssetVentoryApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'AssetVentory',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: settings.mode,
        home: AuthWrapper(settings: settings),
      ),
    );
  }
}

