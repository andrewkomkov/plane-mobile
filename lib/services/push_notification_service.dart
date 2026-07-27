import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/secure_storage.dart';

/// Handles FCM push notification registration and message handling.
class PushNotificationService {
  static bool _initialized = false;

  /// Initialize Firebase and set up FCM listeners.
  /// Safe to call multiple times — only runs once.
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      developer.log('Firebase init failed: $e', name: 'push');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    // Request permission (Android 13+ requires runtime permission)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      developer.log('Push permission denied', name: 'push');
      return;
    }

    // Get FCM token and register with the microservice
    try {
      final token = await messaging.getToken();
      if (token != null) {
        await _registerDevice(token);
      }
    } catch (e) {
      developer.log('Failed to get FCM token: $e', name: 'push');
    }

    // Listen for token refresh
    messaging.onTokenRefresh.listen(_registerDevice);

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Tap on notification while app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Check if app was launched from a notification
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _handleMessageTap(initial);
    }

    _initialized = true;
    developer.log('Push notifications initialized', name: 'push');
  }

  /// Register FCM token with the mobile API microservice.
  static Future<void> _registerDevice(String token) async {
    developer.log('FCM token: $token', name: 'push');
    try {
      final baseUrl = await SecureStorage.getBaseUrl() ?? '';
      final apiKey = await SecureStorage.getApiKey() ?? '';
      if (baseUrl.isEmpty || apiKey.isEmpty) return;

      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {'X-Api-Key': apiKey, 'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      await dio.post('/auth/mobile/register-device/', data: {
        'fcm_token': token,
        'platform':
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
      developer.log('Device registered for push', name: 'push');
    } catch (e) {
      developer.log('Device registration failed: $e', name: 'push');
    }
  }

  /// Handle messages received while the app is in the foreground.
  static void _handleForegroundMessage(RemoteMessage message) {
    developer.log(
      'Foreground message: ${message.notification?.title}',
      name: 'push',
    );
    // The notification is automatically shown by the system on Android
    // when the message contains a notification payload. For data-only
    // messages, we could show a local notification here in the future.
  }

  /// Handle a tap on a notification (app was in background or terminated).
  static void _handleMessageTap(RemoteMessage message) {
    developer.log(
      'Notification tapped: ${message.data}',
      name: 'push',
    );
    // Deep-link navigation can be added here once a navigator key or
    // GoRouter is available globally. For now we just log.
    // Expected data keys: issue_id, project_id, workspace_slug.
  }
}
