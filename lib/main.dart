import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/multiplayer/widgets/online_friends_fab.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final appReady = ValueNotifier<bool>(false);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
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
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Initialize Notification Service listeners
    await NotificationService.initialize();
    
    // Request permission dynamically on launch
    await NotificationService.requestPermissions();
  } catch (e) {
    if (kDebugMode) {
      print('Failed to initialize Firebase Messaging: $e');
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
