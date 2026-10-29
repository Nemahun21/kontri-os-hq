import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:kohntri_os_hq/utils/splash_screen.dart';
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
      autoRefreshToken: true),
  );

  if (!kIsWeb) {
    await SyncService().syncPendingOperations();
  } else {
    // Handle OAuth callback on web
    final code = Uri.base.queryParameters['code'];
    if (code != null) {
      try {
        await Supabase.instance.client.auth.exchangeCodeForSession(code);
      } catch (e) {
        debugPrint('exchangeCodeForSession failed: $e');
      }
    }
  }
   // Handle OAuth callback on web
 

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Also skip connectivity sync on web
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
      home: const SplashScreen(),
    );
  }
}
