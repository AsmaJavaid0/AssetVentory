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

  // Initialize local notifications & FCM asynchronously
  try {
    await serviceLocator.taskNotificationService.initialize();
    await serviceLocator.taskNotificationService.requestPermissions();
    await serviceLocator.fcmService.initialize();
  } catch (e) {
    debugPrint('Notification initialization warning: $e');
  }

  runApp(const AssetVentoryApp());
}

class AssetVentoryApp extends StatelessWidget {
  const AssetVentoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AssetVentory',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}
