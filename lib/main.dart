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

String? supabaseInitError;

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

  // Initialize Supabase with SharedPreferencesLocalStorage to completely avoid iOS Keychain Sharing errors
  try {
    if (kDebugMode) {
      print('DEBUG: Initializing Supabase...');
    }
    await Supabase.initialize(
      url: 'https://forjhwlhjgadguxzhhqe.supabase.co',
      anonKey: 'sb_publishable_kMaTMXB0zJktSnERm8U6Fw_4jsU7Dip',
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        localStorage: SharedPreferencesLocalStorage(
          persistSessionKey: 'sb-persist-session-key',
        ),
      ),
    );
    if (kDebugMode) {
      print('DEBUG: Supabase initialized successfully.');
    }
  } catch (e, stackTrace) {
    supabaseInitError = e.toString();
    if (kDebugMode) {
      print('Failed to initialize Supabase: $e');
      print('Stack trace: $stackTrace');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuthState();
    
    // Initialize notifications asynchronously after the first frame is rendered to prevent blocking startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Proactively clear notifications/badges whenever the app enters the foreground
    if (state == AppLifecycleState.resumed) {
      NotificationService.clearBadgeAndNotifications();
    }
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
    
    // If we have an active session already cached synchronously, we are ready!
    if (client.auth.currentSession != null) {
      appReady.value = true;
    }

    // Listen to changes. As soon as the first authentication event fires,
    // we know the initial verification has completed!
    client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        appReady.value = true;
      }
    });

    // Failsafe: force appReady to true after a maximum of 1.5 seconds under any network latency or database stall
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && !appReady.value) {
        if (kDebugMode) {
          print('DEBUG: Auth check failsafe triggered.');
        }
        appReady.value = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (supabaseInitError != null) {
      return MaterialApp(
        title: 'Miriverbs - Error',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🛑', style: TextStyle(fontSize: 50)),
                  const SizedBox(height: 16),
                  Text(
                    'Error de Inicialización',
                    style: AppTheme.headlineMd,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    supabaseInitError!,
                    style: AppTheme.bodyMd.copyWith(color: AppTheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Miriverbs',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: appNavigatorKey,
      home: ValueListenableBuilder<bool>(
        valueListenable: appReady,
        builder: (context, ready, child) {
          if (!ready) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                ),
              ),
            );
          }
          final client = Supabase.instance.client;
          final hasSession = client.auth.currentSession != null;
          return hasSession ? const HomeScreen() : const OnboardingScreen();
        },
      ),
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
  }
}
