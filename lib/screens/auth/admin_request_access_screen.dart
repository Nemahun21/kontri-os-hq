import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test1 admin requests use the existing authenticated account.
/// Never create a second Auth user or let a client choose another user's ID.
class AdminRequestAccessScreen extends StatefulWidget {
  const AdminRequestAccessScreen({super.key});

  @override
  State<AdminRequestAccessScreen> createState() =>
      _AdminRequestAccessScreenState();
}

class _AdminRequestAccessScreenState extends State<AdminRequestAccessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _loading = false;
  bool _submitted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _nameController.text =
        (user?.userMetadata?['display_name'] as String?) ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.email == null) {
      setState(() => _error = 'Sign in to your Test1 account first.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await Supabase.instance.client.rpc(
        'check_admin_email',
        params: {'p_email': user.email!.trim().toLowerCase()},
      ) as String;
      if (status != 'none' && status != 'rejected') {
        setState(() => _error =
            'An admin request already exists for this account ($status).');
        return;
      }
      await Supabase.instance.client.rpc('request_admin_access', params: {
        'p_name': _nameController.text.trim(),
        'p_email': user.email!.trim().toLowerCase(),
        'p_description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      });
      if (mounted) setState(() => _submitted = true);
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Request admin access')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _submitted
                ? Column(
                    children: [
                      const Icon(Icons.mark_email_read, size: 56,
                          color: Colors.green),
                      const SizedBox(height: 16),
                      const Text('Request submitted',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text(
                        'Your staging account is pending admin approval. '
                        'An assigned admin key is required for HQ access.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back to login'),
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Request access using your signed-in Test1 account. '
                          'No new password or second account is needed.',
                        ),
                        const SizedBox(height: 16),
                        Text('Account: ${user?.email ?? 'Not signed in'}'),
                        const SizedBox(height: 20),
                        if (_error != null) ...[
                          Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Name required'
                                  : null,
                        ),
                        const SizedBox(height: 16),
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
                          onPressed: _loading || user == null ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  height: 22, width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Submit request'),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
