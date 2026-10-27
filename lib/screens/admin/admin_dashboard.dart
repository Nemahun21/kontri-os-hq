import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/screens/admin/content_bank_screen.dart';
import 'package:kohntri_os_hq/screens/admin/content_hub_screen.dart';
import 'package:kohntri_os_hq/screens/admin/daily_content_overview.dart';
import 'package:kohntri_os_hq/screens/admin/widgets/action_needed_card.dart';
import 'package:kohntri_os_hq/screens/admin/widgets/live_feed.dart';
import 'package:kohntri_os_hq/screens/admin/widgets/pulse_strip.dart';
import 'package:kohntri_os_hq/screens/admin/widgets/signin_categories_row.dart';
import 'package:kohntri_os_hq/screens/admin/widgets/top_players_card.dart';
import 'package:kohntri_os_hq/screens/auth/login_screen.dart';
import 'package:kohntri_os_hq/screens/languages_management_screen.dart';
import 'package:kohntri_os_hq/screens/quiz_category_selection_screen.dart';
import 'package:kohntri_os_hq/services/admin_stats_service.dart';
import 'package:kohntri_os_hq/services/cache_service.dart';
import 'package:kohntri_os_hq/services/daily_challenge_service.dart';
import 'package:kohntri_os_hq/services/language_question_service.dart';
import 'package:kohntri_os_hq/services/question_service.dart';
import 'package:kohntri_os_hq/utils/connectivity_helper.dart';
import 'package:kohntri_os_hq/widgets/loading_overlay.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/admin_stats.dart';

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic>? adminData;
  const AdminDashboard({super.key, this.adminData});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _adminData;
  AdminStats? _stats;
  Timer? _refreshTimer;

  final QuestionService _questionService = QuestionService();
  final LanguageQuestionService _langService = LanguageQuestionService();
  final DailyChallengeService _dailyService = DailyChallengeService();

  Map<String, int> _categoryCounts = {};
  int _totalQuestions = 0;
  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalLangQuestions = 0;

  @override
  void initState() {
    super.initState();
    if (widget.adminData != null) {
      _adminData = widget.adminData;
    } else {
      _loadAdminData();
    }
    _loadStats();
    _loadCommandCentre();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _loadCommandCentre(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCommandCentre() async {
    try {
      final stats = await AdminStatsService.fetch();
      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (error) {
      debugPrint('command centre load failed: $error');
    }
  }

  Future<void> _loadAdminData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final cacheKey = 'admin_data_${user.id}';
    final online = await ConnectivityHelper.isOnline();
    if (online) {
      try {
        final response = await Supabase.instance.client
            .from('admins')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
        if (response != null) {
          await CacheService().set(cacheKey, response);
          if (mounted) setState(() => _adminData = response);
        }
      } catch (_) {
        final cached = await CacheService().get(cacheKey);
        if (cached != null && mounted)
          setState(() => _adminData = cached as Map<String, dynamic>);
      }
    } else {
      final cached = await CacheService().get(cacheKey);
      if (cached != null && mounted)
        setState(() => _adminData = cached as Map<String, dynamic>);
    }
  }

  Future<int> _fetchUserCount() async {
    try {
      final response = await Supabase.instance.client
          .from('leaderboard')
          .select('display_name, total_score, photo_url')
          .order('total_score', ascending: false);
      return response.length;
    } catch (e) {
      print('Error fetching user count: $e');
      return 0;
    }
  }

  Future<int> _getDailyChallengeCount() async {
    try {
      final response = await Supabase.instance.client
          .from('daily_challenge_questions')
          .select('id')
          .eq('daily_challenge_id', 'active');
      return response.length;
    } catch (e) {
      print('Error fetching daily challenge count: $e');
      return 0;
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final counts = await _questionService.getQuestionCountByCategory();
      final dailyChallengeCount = await _getDailyChallengeCount();
      final langTotal = await _langService.getTotalLanguageQuestions();
      final userCount = await _fetchUserCount();

      counts.remove('Languages');
      counts['Daily Challenge'] = dailyChallengeCount;

      setState(() {
        _totalLangQuestions = langTotal;
        _categoryCounts = counts;
        _totalQuestions = counts.values.fold<int>(
          0,
          (sum, count) => sum + count,
        );
        _totalUsers = userCount;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading stats: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshDashboard() async {
    await _loadStats();
    await _loadCommandCentre();
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  // =====================================================
  // ADMIN HEADER (unchanged)
  // =====================================================
  Widget _buildAdminHeader(BuildContext context) {
    final adminData = _adminData;
    final name = adminData?['name'] ?? 'Admin';
    final email = adminData?['email'] ?? '';
    final role = adminData?['role'] ?? '';
    final description = adminData?['description'] ?? '';
    final createdAt = adminData?['created_at'];

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.white],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    size: 28,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: IconButton(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      tooltip: 'Logout',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (adminData != null) ...[
                const Divider(),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _buildInfoItem(Icons.badge, 'Role', role),
                    _buildInfoItem(Icons.key, 'Assigned Key', '*****'),
                    if (description.isNotEmpty)
                      _buildInfoItem(
                        Icons.description,
                        'Description',
                        description,
                      ),
                    if (createdAt != null)
                      _buildInfoItem(
                        Icons.calendar_today,
                        'Created',
                        _formatDate(createdAt),
                      ),
                  ],
                ),
              ] else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No admin data available'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.blue),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}-${date.day}-${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  // =====================================================
  // BUILD
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: _isLoading && _stats == null
            ? const LoadingOverlay(message: 'Please wait...')
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _buildAdminHeader(context),
                    const SizedBox(height: 8),
                    if (_stats != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: PulseStrip(stats: _stats!.pulse),
                      ),
                    if (_stats != null)
                      ActionNeededCard(
                        queues: _stats!.queues,
                        onReportsTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContentHubScreen(initialTab: 2),
                          ),
                        ),
                        onContribsTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContentHubScreen(initialTab: 3),
                          ),
                        ),
                      ),
                    if (_stats != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: LiveFeed(events: _stats!.recent),
                      ),
                    if (_stats != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: SignInCategoriesRow(
                          signIn: _stats!.signIn,
                          categories: _stats!.categoriesToday,
                        ),
                      ),
                    if (_stats != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: TopPlayersCard(players: _stats!.topPlayers),
                      ),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Manage',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContentHubScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.dashboard_customize),
                        label: const Text('Open Content Hub'),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }
}