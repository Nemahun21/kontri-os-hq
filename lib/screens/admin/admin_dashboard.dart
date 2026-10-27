import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/screens/admin/admin_metrics_screen.dart';
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

  void _openMetrics(BuildContext context, String title, String metric) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminMetricsScreen(metric: metric, title: title),
      ),
    );
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
  // ADMIN HEADER
  // =====================================================
  Widget _buildAdminHeader(BuildContext context) {
    final adminData = _adminData;
    final name = adminData?['name'] ?? 'Admin';
    final email = adminData?['email'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blue.shade100,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'A',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, size: 20, color: Colors.redAccent),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
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
                        child: PulseStrip(
                          stats: _stats!.pulse,
                          onDauTap: () => _openMetrics(context, 'Active Today', 'dau'),
                          onNewTodayTap: () => _openMetrics(context, 'New Today', 'signups'),
                          onAttemptsTap: () => _openMetrics(context, 'Attempts', 'attempts'),
                          onTotalUsersTap: () => _openMetrics(context, 'Total Users', 'total_users'),
                        ),
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