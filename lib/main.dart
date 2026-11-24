import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:kohntri_os_hq/utils/splash_screen.dart';
import 'package:kohntri_os_hq/screens/auth/set_new_password_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // V2 HQ must never use the live Kontrios backend.
  const supabaseUrl = String.fromEnvironment('V2_SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('V2_SUPABASE_PUBLISHABLE_KEY');
  if (supabaseUrl != 'https://eeeusvsefoxbgshouqjb.supabase.co' ||
      supabaseKey.isEmpty) {
    throw StateError('HQ V2 requires explicit Test1 staging credentials.');
  }
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );

  bool isRecoveryLink = false;

  if (kIsWeb) {
    // Detect recovery marker BEFORE exchangeCodeForSession consumes the code
    isRecoveryLink = Uri.base.queryParameters['action'] == 'reset';

    // Handle OAuth callback + recovery callback on web
    final code = Uri.base.queryParameters['code'];
    if (code != null) {
      try {
        await Supabase.instance.client.auth.exchangeCodeForSession(code);
      } catch (e) {
        debugPrint('exchangeCodeForSession failed: $e');
      }
    }
  }

  runApp(MyApp(showPasswordReset: isRecoveryLink));
}

class MyApp extends StatelessWidget {
  final bool showPasswordReset;
  const MyApp({super.key, this.showPasswordReset = false});

  @override
  Widget build(BuildContext context) {
    // Offline sync is disabled in V2 staging until staging-only local
    // storage is isolated; never replay pending production operations.

    return MaterialApp(
      title: 'Kontri OS Admin',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      debugShowCheckedModeBanner: false,
      home: showPasswordReset
          ? const SetNewPasswordScreen()
          : const SplashScreen(),
    );
  }
}