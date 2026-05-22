import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/multiplayer/widgets/online_friends_fab.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final appReady = ValueNotifier<bool>(false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Strict portrait lock
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
