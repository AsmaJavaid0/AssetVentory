import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

typedef FcmNotificationTapCallback = void Function(Map<String, dynamic> data);

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FcmNotificationTapCallback? _onNotificationTap;

  void setNotificationTapCallback(FcmNotificationTapCallback callback) {
    _onNotificationTap = callback;
  }

  Future<void> initialize() async {
    // Request permission for push notifications
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Register token if user is signed in
      await registerDeviceToken();

      // Token refresh listener
      _messaging.onTokenRefresh.listen((newToken) async {
        await _saveTokenToFirestore(newToken);
      });

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM Foreground message received: ${message.notification?.title}');
        // Foreground messages can trigger local notifications or state refresh
      });

      // Background notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM Message opened app: ${message.data}');
        _onNotificationTap?.call(message.data);
      });

      // Check if app was launched from terminated state via notification tap
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM Initial message: ${initialMessage.data}');
        _onNotificationTap?.call(initialMessage.data);
      }
    }
  }

  Future<void> registerDeviceToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('Error fetching FCM token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final deviceRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(token);

      await deviceRef.set({
        'token': token,
        'platform': kIsWeb ? 'web' : (defaultTargetPlatform.name),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error saving FCM token to Firestore: $e');
    }
  }

  Future<void> unregisterDeviceToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .doc(token)
            .delete();
      }
    } catch (e) {
      debugPrint('Error unregistering FCM token: $e');
    }
  }
}
