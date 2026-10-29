import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRequestAccessScreen extends StatefulWidget {
  const AdminRequestAccessScreen({super.key});

  @override
  State<AdminRequestAccessScreen> createState() =>
      _AdminRequestAccessScreenState();
}

class _AdminRequestAccessScreenState extends State<AdminRequestAccessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() { _loading = true; _error = null; });

  final name = _nameController.text.trim();
  final email = _emailController.text.trim().toLowerCase();
  final password = _passwordController.text;
  final description = _descriptionController.text.trim();

  try {
    final existing = await Supabase.instance.client
        .rpc('check_admin_email', params: {'p_email': email}) as String;
    if (existing != 'none') {
      setState(() { _loading = false; _error = _existingEmailMessage(existing); });
      return;
    }

    final auth = await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': name},
    );

    final user = auth.user;
    if (user == null) {
      throw Exception('Sign-up did not return a user.');
    }

    await Supabase.instance.client.rpc(
  'request_admin_access',
  params: {
    'p_name': name,
    'p_email': email,
    'p_description': description.isEmpty ? null : description,
  },
);

    await Supabase.instance.client.auth.signOut();
    if (mounted) setState(() => _submitted = true);
  } on AuthException catch (e) {
    if (!mounted) return;
    if (e.message.toLowerCase().contains('already registered')) {
      setState(() => _error =
          'An account already exists for this email. Sign in instead — '
          'or reset your password if you don\'t remember it.');
    } else {
      setState(() => _error = e.message);
    }
  } on PostgrestException catch (e) {
    if (!mounted) return;
    if (e.code == '23505') {
      setState(() => _error =
          'This email already has an admin request. Contact the owner.');
    } else {
      setState(() => _error = e.message);
    }
  } catch (e) {
    if (mounted) setState(() => _error = e.toString());
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

String _existingEmailMessage(String status) {
  switch (status) {
    case 'pending':
      return 'This email already has a pending admin request. '
          'An owner will review it soon.';
    case 'active':
      return 'This email is already an active admin. '
          'Go back and sign in instead.';
    case 'rejected':
      return 'This email\'s previous admin request was rejected. '
          'Contact the owner to reapply.';
    case 'suspended':
      return 'This email\'s admin account is suspended. Contact the owner.';
    default:
      return 'This email cannot be used for a new request.';
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request admin access')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _submitted ? _success() : _form(),
          ),
        ),
      ),
    );
  }

  Widget _success() {
    return Column(
      children: [
        const Icon(Icons.mark_email_read, size: 56, color: Colors.green),
        const SizedBox(height: 16),
        const Text(
          'Request submitted',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'An owner must approve your account and send you an assigned key before you can enter HQ.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[700]),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to login'),
        ),
      ],
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create an account. Access stays locked until a super admin approves you.',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
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
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password (min 8 characters)',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 8) return 'Min 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Why do you need access? (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit request'),
          ),
        ],
      ),
    );
  }
}