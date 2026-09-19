import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAdminProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isAdmin = false;
  bool _isLoading = true;
   bool _isKeyVerified = false; 
  Map<String, dynamic>? _adminInfo;
  List<Map<String, dynamic>> _allAdmins = [];
  
  bool get isAdmin => _isAdmin;
  bool get isLoading => _isLoading;
  bool get isKeyVerified => _isKeyVerified;
  Map<String, dynamic>? get adminInfo => _adminInfo;
  List<Map<String, dynamic>> get allAdmins => _allAdmins;
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  SupabaseAdminProvider() {
    _checkAdminStatus();
    
    // Listen to auth changes
    _supabase.auth.onAuthStateChange.listen((data) {
      _checkAdminStatus();
    });
  }

   void setKeyVerified(bool value) {
    if (_isKeyVerified != value) {
      _isKeyVerified = value;
      notifyListeners();
    }
  }

 Future<void> _checkAdminStatus() async {
  _isLoading = true;
  notifyListeners();

  try {
    final user = _supabase.auth.currentUser;
    
    print('🔐 Checking admin status - Current user:');
    print('   User exists: ${user != null}');
    
    if (user == null) {
      print('   ❌ No user logged in');
      _isAdmin = false;
      _adminInfo = null;
      _isKeyVerified = false;
      _isLoading = false;
      notifyListeners();
      return;
    }

    print('   ✅ User logged in');
    print('   Email: ${user.email}');
    print('   ID: ${user.id}');

    // Direct query to check if user is admin
    print('📡 Querying admins table for user_id: ${user.id}');
    
    final response = await _supabase
        .from('admins')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    print('📊 Admin query response: $response');

    if (response != null) {
      _isAdmin = true;
      _adminInfo = Map<String, dynamic>.from(response);
      print('✅✅✅ User IS admin: ${user.email}');
      print('   Role: ${response['role']}');
    } else {
      _isAdmin = false;
      _adminInfo = null;
      _isKeyVerified = false;
      print('❌❌❌ User is NOT admin: ${user.email}');
    }
  } catch (e) {
    print('❌ Error admin status: $e');
    _isAdmin = false;
    _isKeyVerified = false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
  Future<void> _loadAllAdmins() async {
    try {
      final response = await _supabase
          .from('admins')
          .select()
          .order('created_at');
      
      _allAdmins = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error loading admins: $e');
    }
  }

  // Add new admin (requires current user to be admin)
  Future<bool> addAdmin(String email, {String? role = 'admin'}) async {
    if (!_isAdmin) return false;

    try {
      // First, get the user from auth.users by email
      // Note: This requires admin privileges - you might need a edge function
      
      final response = await _supabase
          .from('admins')
          .insert({
            'email': email,
            'role': role,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      await _loadAllAdmins();
      return true;
    } catch (e) {
      print('❌ Error adding admin: $e');
      return false;
    }
  }

  // Remove admin
  Future<bool> removeAdmin(String adminId) async {
    if (!_isAdmin) return false;

    try {
      await _supabase
          .from('admins')
          .delete()
          .eq('id', adminId);
      
      await _loadAllAdmins();
      return true;
    } catch (e) {
      print('❌ Error removing admin: $e');
      return false;
    }
  }

  // Check if current user is admin by email
  Future<bool> isAdminByEmail(String email) async {
    try {
      final response = await _supabase
          .from('admins')
          .select()
          .eq('email', email)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      print('❌ Error checking admin by email: $e');
      return false;
    }
  }

  // Refresh admin list
  Future<void> refreshAdmins() async {
    await _loadAllAdmins();
    notifyListeners();
  }
}