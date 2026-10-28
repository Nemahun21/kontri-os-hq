import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kohntri_os_hq/screens/admin/admin_dashboard.dart';
import 'package:kohntri_os_hq/widgets/loading_overlay.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _keyController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static const _webClientId =
      '809978005987-8s4dji8d6agtm51iv4rd3a61t5riumb6.apps.googleusercontent.com';
  static const _iosClientId = '';
  bool _googleReady = false;

  @override
  void initState() {
    super.initState();
    _initGoogle();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _initGoogle() async {
    try {
      await _googleSignIn.initialize(
  clientId: kIsWeb
      ? _webClientId  // ← add this for web
      : (defaultTargetPlatform == TargetPlatform.iOS ? _iosClientId : null),
  serverClientId: _webClientId,
);
      if (mounted) setState(() => _googleReady = true);
    } catch (e) {
      if (kDebugMode) print('❌ GoogleSignIn init failed: $e');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kIsWeb) {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
      } else {
        if (!_googleReady) {
          await _initGoogle();
          if (!_googleReady) {
            if (mounted) {
              setState(() => _errorMessage = 'Google sign-in not ready. Try again.');
            }
            return;
          }
        }

        final account = await _googleSignIn.authenticate();
        if (account == null) return;

        final idToken = account.authentication.idToken;
        if (idToken == null) throw Exception('No ID token received.');

        await Supabase.instance.client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
        );
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('Google sign-in failed.');
      }

      final adminResponse = await Supabase.instance.client
          .from('admins')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();

      if (adminResponse == null) {
        throw Exception('Not an authorized admin');
      }

      if (!mounted) return;

      final assignedKey = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final keyController = TextEditingController();
          return AlertDialog(
            title: const Text('Enter assigned key'),
            content: TextField(
              controller: keyController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Assigned key',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (!mounted) return;
                  Navigator.of(dialogContext).pop(null);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(keyController.text),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );

      if (assignedKey == null) {
        await Supabase.instance.client.auth.signOut();
        return;
      }

      if (adminResponse['assigned_key'] != assignedKey) {
        await Supabase.instance.client.auth.signOut();
        throw Exception('Invalid assigned key');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminDashboard(adminData: adminResponse),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

Future<void> _handleLogin() async {
  // Validate form fields
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final assignedKey = _keyController.text;

    // 1. Authenticate with Supabase Auth – this will throw on failure
    final AuthResponse authResponse;
    try {
      authResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = authResponse.user;
   print('✅ User: ${user?.email} (ID: ${user?.id})');

      
    } catch (authError) {
            print(authError);

      // Handle authentication errors (wrong email/password, etc.)
      throw Exception('Invalid email or password');
    }

    // Ensure we have a user (should exist if no exception)
    final user = authResponse.user;
    if (user == null) {
      throw Exception('Authentication failed. Please try again.');
    }

    // 2. Verify admin status and assigned key in the admin table
   final adminResponse = await Supabase.instance.client
    .from('admins')
    .select('*', )   // or select('*') to see all fields
    .eq('user_id', user.id)   // 🔑 Match using user_id, not the primary id
    .maybeSingle();

    print(adminResponse);


     if (adminResponse == null) {
      
      throw Exception('Not an authorized admin');
    
    }

  // print('✅ Admin primary ID: ${adminResponse['id']}');
  // print('✅ Auth user ID: ${user.id}');
  // print('✅ Assigned key: ${adminResponse['assigned_key']}');

   

   // Compare the provided assigned key with the stored one
    if (adminResponse['assigned_key'] != assignedKey) {
      throw Exception('Invalid assigned key.');
    }

    // 3. Success – navigate to admin dashboard
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) =>  AdminDashboard(adminData: adminResponse)),
    );
  } catch (e) {
    if (!mounted) return;
    setState(() {
      // Display a clean error message
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    });
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
 
  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // Logo
        Container(
          height: 100,
          width: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A5276), Color(0xFF2E86C1)],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.key_sharp,
            size: 50,
            color: Colors.greenAccent,
          ),
        ),
        const Text(
          'Kontri-Os HQ',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Admin Login',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }


Widget _buildEmailItem(BuildContext context){
  return 
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                );
                
}
  
  Widget _buildPasswordItem(BuildContext context){
    return                 TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                );

  }
 
   Widget _buildAssignedKeyItem(BuildContext context){
    return  TextFormField(
                  controller: _keyController,
                  obscureText: true, // hide the key as it's secret
                  decoration: InputDecoration(
                    labelText: 'Assigned Key',
                    hintText: 'Enter your secret key',
                    prefixIcon: const Icon(Icons.vpn_key),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value)  => value?.isEmpty ?? true ? 'Please enter your assigned key' : null, 
                );
 
   }
  
  Widget _buildLoginButton(BuildContext context){
    return    SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A5276),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'LOGIN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                );
             
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading ? const LoadingOverlay(message: "Authenticating...")
      :
       SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                SizedBox(height: 10,),
                 if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 25),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  icon: const Text(
                    'G',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4285F4),
                    ),
                  ),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2C3E50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildEmailItem(context),
                const SizedBox(height: 25),
                _buildPasswordItem(context),
                const SizedBox(height: 25),
                _buildAssignedKeyItem(context),
                const SizedBox(height: 25),
                _buildLoginButton(context),

               

                const SizedBox(height: 16),

                const SizedBox(height: 24),
                // Assigned Key field (new)
               
                SizedBox(height: 20),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
