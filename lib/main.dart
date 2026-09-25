import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:kohntri_os_hq/screens/splash_screen.dart';
import 'package:kohntri_os_hq/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
  );

  if (!kIsWeb) {
    await SyncService().syncPendingOperations();
  }

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
      title: 'Kontri OS HQ',
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
