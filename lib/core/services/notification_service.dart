import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;

  /// Initialize Firebase Messaging configurations and stream listeners.
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Set foreground notification options (iOS only by default, but nice to specify)
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Listen to foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Received foreground push notification:');
          print('Title: ${message.notification?.title}');
          print('Body: ${message.notification?.body}');
          print('Data: ${message.data}');
        }
        // Handle foreground notifications (e.g. show dialog, toast, or trigger dynamic in-app reactions)
      });

      // Listen to interaction when the app is opened from a notification background state
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('App opened from push notification:');
          print('Data: ${message.data}');
        }
        _handleNotificationClick(message);
      });

      // Check if the app was launched by clicking a notification when it was closed
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) {
          print('App launched from terminated state via push notification:');
          print('Data: ${initialMessage.data}');
        }
        _handleNotificationClick(initialMessage);
      }

      // Listen to token refresh
      _messaging.onTokenRefresh.listen((token) async {
        if (kDebugMode) {
          print('FCM Token refreshed: $token');
        }
        await syncTokenToDatabase(token: token);
      });

      _initialized = true;
      if (kDebugMode) {
        print('NotificationService successfully initialized.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing NotificationService: $e');
      }
    }
  }

  /// Request permissions for iOS and Android 13+ devices.
  static Future<bool> requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('Notification permission status: ${settings.authorizationStatus}');
      }

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (granted) {
        // Fetch token and sync to database if already logged in
        await syncTokenToDatabase();
      }

      return granted;
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting notification permissions: $e');
      }
      return false;
    }
  }

  /// Get the current device push token.
  static Future<String?> getToken() async {
    try {
      // In iOS, retrieve the APNs token first to prevent FCM token fetching errors.
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          if (kDebugMode) {
            print('APNs token is not available yet.');
          }
        }
      }

      final fcmToken = await _messaging.getToken();
      return fcmToken;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
      return null;
    }
  }

  /// Synchronize the active FCM device token to the Supabase profiles table.
  static Future<void> syncTokenToDatabase({String? token}) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('Cannot sync push token: No user is currently authenticated.');
        }
        return;
      }

      final activeToken = token ?? await getToken();
      if (activeToken == null) {
        if (kDebugMode) {
          print('Cannot sync push token: Token is null.');
        }
        return;
      }

      await Supabase.instance.client.from('profiles').update({
        'push_token': activeToken,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (kDebugMode) {
        print('FCM Token synced to Supabase profile for user: ${user.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error syncing push token to Supabase: $e');
      }
    }
  }

  /// Remove the FCM device token from Supabase profile on user logout.
  static Future<void> clearTokenFromDatabase() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('profiles').update({
        'push_token': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (kDebugMode) {
        print('FCM Token cleared from Supabase profile for user: ${user.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing push token from Supabase: $e');
      }
    }
  }

  /// Private router helper to process tapped notifications (e.g., deep links, battles, etc.)
  static void _handleNotificationClick(RemoteMessage message) {
    if (kDebugMode) {
      print('Handling click for notification payload: ${message.data}');
    }
  }
}
