import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart' show appNavigatorKey;
import '../../features/multiplayer/widgets/incoming_challenge_alert.dart';

class NotificationService {
  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;
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

  /// Get the current device push token with automatic retries for APNs on iOS.
  static Future<String?> getToken() async {
    try {
      if (Platform.isIOS) {
        int retries = 0;
        String? apnsToken;
        while (retries < 5) {
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) {
            if (kDebugMode) {
              print('DEBUG: APNs token successfully retrieved.');
            }
            break;
          }
          retries++;
          if (kDebugMode) {
            print('DEBUG: APNs token is not available yet. Retrying in 1 second (attempt $retries/5)...');
          }
          await Future.delayed(const Duration(seconds: 1));
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

  /// Get the current device push token with step-by-step logging for diagnostics.
  static Future<String?> getTokenDetailed({required Function(String) onLog}) async {
    try {
      onLog('Iniciando obtención de token...');
      if (Platform.isIOS) {
        onLog('Plataforma iOS detectada. Verificando APNs...');
        int retries = 0;
        String? apnsToken;
        while (retries < 8) {
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) {
            onLog('APNs Token obtenido con éxito: $apnsToken');
            break;
          }
          retries++;
          onLog('APNs no disponible aún. Reintento $retries/8...');
          await Future.delayed(const Duration(seconds: 1));
        }
        if (apnsToken == null) {
          onLog('Advertencia: APNs Token sigue siendo NULL después de 8 reintentos.');
        }
      }

      onLog('Solicitando FCM Token de Firebase...');
      final fcmToken = await _messaging.getToken();
      if (fcmToken != null) {
        onLog('FCM Token obtenido con éxito.');
      } else {
        onLog('Error: El FCM Token devuelto por Firebase es NULL.');
      }
      return fcmToken;
    } catch (e) {
      onLog('Excepción al obtener token: $e');
      return null;
    }
  }

  /// Synchronize the active FCM device token with detailed step-by-step logging.
  static Future<void> syncTokenToDatabaseDetailed({
    required Function(String) onLog,
    String? token,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        onLog('Error: No hay usuario autenticado en Supabase.');
        return;
      }
      onLog('Usuario autenticado encontrado: ${user.email ?? user.id}');

      final activeToken = token ?? await getTokenDetailed(onLog: onLog);
      if (activeToken == null) {
        onLog('Error crítico: El token es NULL. Abortando actualización en Supabase.');
        return;
      }

      onLog('Actualizando tabla profiles en Supabase...');
      await Supabase.instance.client.from('profiles').update({
        'push_token': activeToken,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      onLog('¡Sincronización en Supabase completada con éxito!');
    } catch (e) {
      onLog('Excepción al sincronizar con Supabase: $e');
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
    try {
      final data = message.data;
      if (data['type'] == 'battle_challenge') {
        final sessionId = data['session_id'] as String?;
        final context = appNavigatorKey.currentContext;
        if (context != null && sessionId != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => IncomingChallengeAlert(
              sessionId: sessionId,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling notification click: $e');
      }
    }
  }
}
