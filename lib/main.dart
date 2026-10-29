import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:kohntri_os_hq/utils/splash_screen.dart';
import 'package:kohntri_os_hq/screens/auth/set_new_password_screen.dart';
import 'package:kohntri_os_hq/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ibofeppwhmyxaychgcjq.supabase.co',
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlib2ZlcHB3aG15eGF5Y2hnY2pxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxODUxODMsImV4cCI6MjA4Nzc2MTE4M30.Q6FeUQzdMbN5wheyLzEkumUussrMa1C0CV4J6LsjB70",
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );

  bool isRecoveryLink = false;

  if (!kIsWeb) {
    await SyncService().syncPendingOperations();
  } else {
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
    if (!kIsWeb) {
      Connectivity().onConnectivityChanged.listen((
        List<ConnectivityResult> result,
      ) {
        if (result.any((r) => r != ConnectivityResult.none)) {
          SyncService().syncPendingOperations();
        }
      });
    }

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