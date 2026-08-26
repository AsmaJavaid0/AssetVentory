import 'package:flutter/material.dart';
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

  // Initialize the service locator
  await setupServiceLocator();

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
