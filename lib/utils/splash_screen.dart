// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kohntri_os_hq/screens/admin/admin_dashboard.dart';
import 'package:kohntri_os_hq/screens/auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  Future<void> _startInitialization() async {
    // Race: either init completes or 10 seconds pass
    await Future.any([
      _initializeApp(),
      Future.delayed(const Duration(seconds: 10), () {
        setState(() => _timedOut = true);
      }),
    ]);

    // After timeout or completion, navigate
    _navigateToAppropriateScreen();
  }

  Future<void> _initializeApp() async {
    // Check connectivity with timeout
    final hasInternet = await _checkConnectivityWithTimeout();

    // Check for existing session
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // No session – we'll navigate to login later
      return;
    }

    // Session exists – try to refresh token (only if online)
    if (hasInternet) {
      try {
        await Supabase.instance.client.auth.refreshSession();
      } catch (e) {
        print('Token refresh failed, using cached session: $e');
      }
    }
    // If we reach here, we have a session or the refresh failed.
    // The navigation will happen after the timeout or immediately if _initializeApp finishes early.
  }

  Future<bool> _checkConnectivityWithTimeout() async {
    try {
      final result = await Connectivity().checkConnectivity().timeout(
        const Duration(seconds: 3),
        onTimeout: () => [ConnectivityResult.none],
      );
      return result.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  void _navigateToAppropriateScreen() {
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A5276), Color(0xFF2E86C1)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school,
                  size: 60,
                  color: Color(0xFF1A5276),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Kontri-Os HQ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The Cultural Companion',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              if (_timedOut) ...[
                const SizedBox(height: 20),
                const Text(
                  'Taking longer than expected... loading from cache.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}