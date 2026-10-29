import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kohntri_os_hq/screens/admin/admin_dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_request_access_screen.dart';

// import your HQ home:
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

  /// null | pending | rejected | suspended | need_key | ready
  String? _gate; // drives which panel to show after auth
  String? _statusMessage;
  String? _error;
  Map<String, dynamic>? _adminRow;

  GoogleSignIn? _googleSignIn;

  static const String _webAppUrl = 'https://nemahun21.github.io/kontri-os-hq/';
  static const String _googleServerClientId =
      '809978005987-8s4dji8d6agtm51iv4rd3a61t5riumb6.apps.googleusercontent.com';

  @override
  void initState() {
    super.initState();
    _initGoogle();
    _bootstrapSession();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _adminKeyController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await _evaluateAdminGate();
    }
  }

  Future<void> _initGoogle() async {
    if (kIsWeb) {
      if (mounted) setState(() => _googleReady = true);
      return;
    }
    try {
      _googleSignIn = GoogleSignIn.instance;
      await _googleSignIn!.initialize(serverClientId: _googleServerClientId);
      if (mounted) setState(() => _googleReady = true);
    } catch (e) {
      debugPrint('GoogleSignIn init failed: $e');
      if (mounted) setState(() => _googleReady = false);
    }
  }

  // ── After any successful auth ───────────────────────────
  Future<void> _evaluateAdminGate() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _gate = null;
        _adminRow = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final row = await Supabase.instance.client
          .from('admins')
          .select(
            'id, user_id, email, name, role, status, assigned_key, description',
          )
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (row == null) {
        setState(() {
          _gate = 'no_profile';
          _statusMessage =
              'No admin application found for this account. Request access first.';
          _adminRow = null;
          _isLoading = false;
        });
        return;
      }

      final status = row['status']?.toString() ?? 'pending';
      _adminRow = row;

      switch (status) {
        case 'pending':
          setState(() {
            _gate = 'pending';
            _statusMessage =
                'Your request is pending owner approval. You will receive an assigned key when approved.';
            _isLoading = false;
          });
          break;
        case 'rejected':
          setState(() {
            _gate = 'rejected';
            _statusMessage = 'Your admin request was rejected.';
            _isLoading = false;
          });
          break;
        case 'suspended':
          setState(() {
            _gate = 'suspended';
            _statusMessage = 'This admin account is suspended.';
            _isLoading = false;
          });
          break;
        case 'active':
          setState(() {
            _gate = 'need_key';
            _statusMessage = null;
            _isLoading = false;
          });
          break;
        default:
          setState(() {
            _gate = 'pending';
            _statusMessage = 'Unknown status: $status';
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
      if (res.session == null) throw Exception('No session returned');
      await _evaluateAdminGate();
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

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      if (kIsWeb) {
        final redirectTo = kDebugMode ? Uri.base.origin : _webAppUrl;
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectTo,
        );
        return;
      }
      final google = _googleSignIn;
      if (google == null) throw Exception('Google Sign-In not initialized');
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw Exception('No ID token from Google');
      final res = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      if (res.session == null) throw Exception('No session from Supabase');
      await _evaluateAdminGate();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Google sign-in failed: $e';
          _isLoading = false;
        });
      }
    }
  }

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
      final row = _adminRow;
      if (row == null) throw Exception('Admin profile missing');
      if (row['status']?.toString() != 'active') {
        throw Exception('Account is not active');
      }
      final stored = row['assigned_key']?.toString();
      if (stored == null || stored.isEmpty || stored != key) {
        throw Exception('Invalid admin key');
      }
      if (!mounted) return;
      // TODO: your HQ route
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const AdminDashboard(adminData: null),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
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
        _gate = null;
        _adminRow = null;
        _statusMessage = null;
        _error = null;
        _adminKeyController.clear();
      });
    }
  }

  Future<void> _sendPasswordReset() async {
  final email = _emailController.text.trim();
  if (email.isEmpty || !email.contains('@')) {
    setState(() => _error = 'Enter your email first, then tap Forgot password');
    return;
  }
  setState(() {
    _isLoading = true;
    _error = null;
  });
  try {
    await Supabase.instance.client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'https://nemahun21.github.io/kontri-os-hq/',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password reset link sent. Check your email.'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (mounted) setState(() => _error = e.toString());
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_gate == 'need_key') return _buildAdminKeyStep();
    if (_gate == 'pending' ||
        _gate == 'rejected' ||
        _gate == 'suspended' ||
        _gate == 'no_profile') {
      return _buildStatusStep();
    }
    return _buildAuthStep();
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
            'Sign in with email and password',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            _Banner(message: _error!, color: Colors.red),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
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
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Password required' : null,
          ),
          const SizedBox(height: 20),
          Align(
  alignment: Alignment.centerRight,
  child: TextButton(
    onPressed: _isLoading ? null : _sendPasswordReset,
    child: const Text('Forgot password?'),
  ),
),
const SizedBox(height: 8),
          FilledButton(
            onPressed: _isLoading ? null : _signInWithEmail,
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign in'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: (_isLoading || !_googleReady)
                ? null
                : _handleGoogleSignIn,
            icon: const Icon(Icons.g_mobiledata, size: 28),
            label: const Text('Google (optional)'),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminRequestAccessScreen(),
                      ),
                    );
                  },
            child: const Text('Request admin access'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStep() {
    final color = _gate == 'pending' ? Colors.orange : Colors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          _gate == 'pending' ? Icons.hourglass_top : Icons.block,
          size: 48,
          color: color,
        ),
        const SizedBox(height: 12),
        Text(
          _gate == 'pending'
              ? 'Awaiting approval'
              : _gate == 'no_profile'
              ? 'Not registered as admin'
              : 'Access denied',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _Banner(message: _statusMessage ?? '', color: color),
        const SizedBox(height: 20),
        if (_gate == 'no_profile')
          FilledButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminRequestAccessScreen(),
                ),
              );
            },
            child: const Text('Request admin access'),
          ),
        TextButton(onPressed: _signOut, child: const Text('Sign out')),
      ],
    );
  }

  Widget _buildAdminKeyStep() {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final name = _adminRow?['name']?.toString();
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
          name != null && name.isNotEmpty
              ? '$name · $email'
              : (email.isEmpty ? 'Signed in' : 'Signed in as $email'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[700]),
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          _Banner(message: _error!, color: Colors.red),
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
              : const Text('Enter HQ'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _signOut,
          child: const Text('Use a different account'),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final String message;
  final Color color;
  const _Banner({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: color == Colors.red
              ? Colors.red.shade700
              : color == Colors.orange
                  ? Colors.orange.shade800
                  : Colors.green.shade700,
        ),
      ),
    );
  }
}
extension on Color {
  Color get shade700 {
    final m = ColorScheme.fromSeed(seedColor: this);
    return m.primary;
  }
}
