import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _keyController.dispose();
    super.dispose();
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
   //print('✅ User: ${user?.email} (ID: ${user?.id})');

      
    } catch (authError) {
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
