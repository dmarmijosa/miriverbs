import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/multiplayer/widgets/online_friends_fab.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final appReady = ValueNotifier<bool>(false);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kDebugMode) {
    print("Handling background message: ${message.messageId}");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Strict portrait lock
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase Cloud Messaging
  try {
    if (kDebugMode) {
      print('DEBUG: Initializing Firebase with options...');
    }
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      print('DEBUG: Firebase.initializeApp completed successfully.');
    }
    
    if (kDebugMode) {
      print('DEBUG: Setting onBackgroundMessage handler...');
    }
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    if (kDebugMode) {
      print('DEBUG: onBackgroundMessage handler set successfully.');
    }
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('Failed to initialize Firebase Messaging: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Initialize Supabase using client credentials
  await Supabase.initialize(
    url: 'https://forjhwlhjgadguxzhhqe.supabase.co',
    anonKey: 'sb_publishable_kMaTMXB0zJktSnERm8U6Fw_4jsU7Dip',
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
    
    // Initialize notifications asynchronously after the first frame is rendered to prevent blocking startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNotifications();
    });
  }

  Future<void> _initNotifications() async {
    try {
      if (kDebugMode) {
        print('DEBUG: Initializing NotificationService asynchronously...');
      }
      await NotificationService.initialize();
      if (kDebugMode) {
        print('DEBUG: NotificationService initialized successfully.');
      }
      
      // Request permission dynamically after rendering the first frame
      if (kDebugMode) {
        print('DEBUG: Requesting NotificationService permissions...');
      }
      await NotificationService.requestPermissions();
      if (kDebugMode) {
        print('DEBUG: NotificationService permissions requested.');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Failed to initialize Notification Service: $e');
        print('Stack trace: $stackTrace');
      }
    }
  }

  void _checkAuthState() {
    final client = Supabase.instance.client;
    
    // Set initial value based on active session
    if (client.auth.currentSession != null) {
      appReady.value = true;
    }

    client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        appReady.value = true;
      } else {
        appReady.value = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final hasSession = client.auth.currentSession != null;

    return ValueListenableBuilder<bool>(
      valueListenable: appReady,
      builder: (context, ready, child) {
        return MaterialApp(
          title: 'Miriverbs',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          navigatorKey: appNavigatorKey,
          home: hasSession ? const HomeScreen() : const OnboardingScreen(),
          builder: (context, child) {
            return Stack(
              children: [
                // ignore: use_null_aware_elements
                if (child != null) child,
                // Mounted globally to listen for incoming challenges on all screens
                const OnlineFriendsFab(),
              ],
            );
          },
        );
      },
    );
  }
}
