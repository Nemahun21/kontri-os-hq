import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// TODO: point these at your real screens
// import 'package:kohntri_os_hq/screens/admin/admin_home.dart';
// import 'package:kohntri_os_hq/screens/admin/content_hub_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adminKeyController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureAdminKey = true;
  bool _googleReady = false;
  bool _awaitingAdminKey = false;
  String? _error;

  /// Mobile only — never initialize with serverClientId on web.
  GoogleSignIn? _googleSignIn;

  // ── Replace with your values (prefer --dart-define / env, not hardcode) ──
  static const String _webAppUrl = 'https://nemahun21.github.io/kontri-os-hq/';
  // Web client ID from Google Cloud (used as serverClientId on mobile for id token audience)
  static const String _googleServerClientId =
      'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  @override
  void initState() {
    super.initState();
    _initGoogle();
    _restoreSessionIfAny();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _adminKeyController.dispose();
    super.dispose();
  }

  Future<void> _restoreSessionIfAny() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && mounted) {
      setState(() => _awaitingAdminKey = true);
    }
  }

  Future<void> _initGoogle() async {
    if (kIsWeb) {
      // Web uses signInWithOAuth only — do not call GoogleSignIn.initialize here.
      if (mounted) setState(() => _googleReady = true);
      return;
    }

    try {
      _googleSignIn = GoogleSignIn.instance;
      await _googleSignIn!.initialize(
        // Required on mobile so the ID token audience matches Supabase Google provider
        serverClientId: _googleServerClientId,
      );
      if (mounted) setState(() => _googleReady = true);
    } catch (e) {
      debugPrint('GoogleSignIn init failed: $e');
      if (mounted) {
        setState(() {
          _googleReady = false;
          _error = 'Google Sign-In unavailable on this device.';
        });
      }
    }
  }

  // ─────────────────────────────────────────────
  // Email + password
  // ─────────────────────────────────────────────
  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (res.session == null) {
        throw Exception('No session returned');
      }

      if (mounted) {
        setState(() {
          _awaitingAdminKey = true;
          _isLoading = false;
        });
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────
  // Google — web = OAuth, mobile = idToken
  // ─────────────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (kIsWeb) {
        await _signInWithGoogleWeb();
        // Page will redirect; session restored on return via Supabase SDK
        return;
      }

      await _signInWithGoogleMobile();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Google sign-in failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogleWeb() async {
    final redirectTo = kDebugMode ? Uri.base.origin : _webAppUrl;

    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
      authScreenLaunchMode: LaunchMode.platformDefault,
    );
    // Do not setState loading false here — browser navigates away
  }

  Future<void> _signInWithGoogleMobile() async {
    final google = _googleSignIn;
    if (google == null) {
      throw Exception('Google Sign-In not initialized');
    }

    final account = await google.authenticate();
    final auth = account.authentication;
    final idToken = auth.idToken;

    if (idToken == null) {
      throw Exception('No ID token from Google');
    }

    final res = await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );

    if (res.session == null) {
      throw Exception('No session from Supabase');
    }

    if (mounted) {
      setState(() {
        _awaitingAdminKey = true;
        _isLoading = false;
      });
    }
  }

  // ─────────────────────────────────────────────
  // Admin key gate
  // ─────────────────────────────────────────────
  Future<void> _verifyAdminKey() async {
    final key = _adminKeyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Enter your assigned admin key');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('Not signed in');
      }

      // Example: verify against a table. Adapt to your schema.
      // e.g. admin_profiles: user_id, admin_key_hash, is_active
      final row = await Supabase.instance.client
          .from('admin_profiles')
          .select('id, admin_key')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (row == null) {
        throw Exception('No admin profile for this account');
      }

      final storedKey = row['admin_key']?.toString();
      // Prefer hashed keys in production; plain compare only if you already store plain.
      if (storedKey == null || storedKey != key) {
        throw Exception('Invalid admin key');
      }

      if (!mounted) return;
      // TODO: navigate to your admin home / content hub
      Navigator.of(context).pushReplacementNamed('/admin');
      // Or:
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (_) => const ContentHubScreen()),
      // );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!kIsWeb) {
      try {
        await _googleSignIn?.signOut();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _awaitingAdminKey = false;
        _adminKeyController.clear();
        _error = null;
      });
    }
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _awaitingAdminKey ? _buildAdminKeyStep() : _buildAuthStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Admin Login',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            kIsWeb
                ? 'Web: Google uses secure redirect · or email + password'
                : 'Sign in with Google or email',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email required';
              if (!v.contains('@')) return 'Invalid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password required';
              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isLoading ? null : _signInWithEmail,
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign in with email'),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR'),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: (_isLoading || !_googleReady) ? null : _handleGoogleSignIn,
            icon: const Icon(Icons.g_mobiledata, size: 28),
            label: Text(kIsWeb ? 'Continue with Google' : 'Sign in with Google'),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 12),
            Text(
              'After Google, you will return here to enter your admin key.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdminKeyStep() {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.verified_user, size: 48, color: Colors.green),
        const SizedBox(height: 12),
        const Text(
          'Admin verification',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          email.isEmpty ? 'Signed in' : 'Signed in as $email',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[700]),
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          _ErrorBanner(message: _error!),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _adminKeyController,
          obscureText: _obscureAdminKey,
          decoration: InputDecoration(
            labelText: 'Assigned admin key',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.key),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureAdminKey ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () =>
                  setState(() => _obscureAdminKey = !_obscureAdminKey),
            ),
          ),
          onSubmitted: (_) => _verifyAdminKey(),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _isLoading ? null : _verifyAdminKey,
          child: _isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continue'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading ? null : _signOut,
          child: const Text('Use a different account'),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(message, style: TextStyle(color: Colors.red.shade800)),
    );
  }
}