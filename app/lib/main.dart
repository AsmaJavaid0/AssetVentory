import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/auth_wrapper.dart';
import 'core/di/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize the service locator
  await setupServiceLocator();
  await serviceLocator.preferences.init();

  // Initialize local notifications & FCM asynchronously (non-blocking)
  // This runs in the background so the UI renders immediately.
  _initNotifications();

  runApp(const AssetVentoryApp());
}

Future<void> _initNotifications() async {
  try {
    await serviceLocator.taskNotificationService.initialize();
    await serviceLocator.taskNotificationService.requestPermissions();
  } catch (e) {
    debugPrint('Local notification init warning: $e');
  }
  try {
    await serviceLocator.fcmService.initialize()
        .timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('FCM initialization warning: $e');
  }
}

class AssetVentoryApp extends StatelessWidget {
  const AssetVentoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: serviceLocator.preferences.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'AssetVentory',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: const AuthWrapper(),
        );
      },
    );
  }
}
