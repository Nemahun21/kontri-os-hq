import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/screens/admin/admin_metrics_screen.dart';
import 'package:kohntri_os_hq/screens/admin/content_hub_screen.dart';
import 'package:kohntri_os_hq/screens/admin/user_lookup_screen.dart';
import 'package:kohntri_os_hq/screens/admin/widgets/action_needed_card.dart';
import 'package:kohntri_os_hq/screens/admin/widgets/live_feed.dart';
import 'package:kohntri_os_hq/screens/admin/widgets/pulse_strip.dart';
import 'package:kohntri_os_hq/screens/admin/widgets/top_players_card.dart';
import 'package:kohntri_os_hq/screens/auth/login_screen.dart';
import 'package:kohntri_os_hq/services/admin_stats_service.dart';
import 'package:kohntri_os_hq/services/cache_service.dart';
import 'package:kohntri_os_hq/services/daily_challenge_service.dart';
import 'package:kohntri_os_hq/services/language_question_service.dart';
import 'package:kohntri_os_hq/services/question_service.dart';
import 'package:kohntri_os_hq/utils/connectivity_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin_theme.dart';
import '../../models/admin_series.dart';
import '../../models/admin_stats.dart';
import '../../widgets/admin_card.dart';
import '../../widgets/categories_bar_card.dart';
import '../../widgets/content_health_strip.dart';
import '../../widgets/dashboard_header.dart';
import '../../widgets/manage_actions_row.dart';
import '../../widgets/signin_donut_card.dart';
import '../../widgets/trend_chart_card.dart';

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic>? adminData;

  const AdminDashboard({super.key, this.adminData});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _adminData;
  AdminStats? _stats;
  PulseSeries? _series;
  String? _statsError;
  Timer? _refreshTimer;
  bool _isLoading = true;
  bool _refreshing = false;

  final QuestionService _questionService = QuestionService();
  final LanguageQuestionService _langService = LanguageQuestionService();
  final DailyChallengeService _dailyService = DailyChallengeService();

  Map<String, int> _categoryCounts = {};
  int _totalQuestions = 0;
  int _totalLangQuestions = 0;

  @override
  void initState() {
    super.initState();
    if (widget.adminData != null) {
      _adminData = widget.adminData;
    } else {
      _loadAdminData();
    }
    _loadCommandCentre();
    _loadSeries();
    _loadStats();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refreshDashboard());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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
        if (cached != null && mounted) {
          setState(() => _adminData = cached as Map<String, dynamic>);
        }
      }
    } else {
      final cached = await CacheService().get(cacheKey);
      if (cached != null && mounted) {
        setState(() => _adminData = cached as Map<String, dynamic>);
      }
    }
  }

  Future<void> _loadCommandCentre() async {
    try {
      final stats = await AdminStatsService.fetch();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _statsError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('command centre load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _statsError = error.toString());
    }
  }

  Future<void> _loadSeries() async {
    try {
      final series = await AdminStatsService.fetchPulseSeries();
      if (!mounted) return;
      setState(() => _series = series);
    } catch (error, stackTrace) {
      debugPrint('series load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<int> _getDailyChallengeCount() async {
    try {
      final response = await Supabase.instance.client
          .from('daily_challenge_questions')
          .select('id')
          .eq('daily_challenge_id', 'active');
      return response.length;
    } catch (error) {
      debugPrint('Error fetching daily challenge count: $error');
      return 0;
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final counts = await _questionService.getQuestionCountByCategory();
      final dailyChallengeCount = await _getDailyChallengeCount();
      final langTotal = await _langService.getTotalLanguageQuestions();

      counts.remove('Languages');
      counts['Daily Challenge'] = dailyChallengeCount;

      setState(() {
        _totalLangQuestions = langTotal;
        _categoryCounts = counts;
        _totalQuestions = counts.values.fold<int>(0, (sum, count) => sum + count);
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Error loading stats: $error');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshDashboard() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await Future.wait([_loadCommandCentre(), _loadStats(), _loadSeries()]);
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  void _openMetrics(String metric, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminMetricsScreen(metric: metric, title: title)),
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width > 900;
    final mobile = width < 600;

    return Scaffold(
      backgroundColor: AdminColors.bg,
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminHeader(
                    name: _adminData?['name'] ?? 'Admin',
                    email: _adminData?['email'] ?? '',
                    showEmail: width >= 400,
                    onUsers: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UserLookupScreen()),
                    ),
                    onContent: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UserLookupScreen()),
                    ),
                    onRefresh: _loadCommandCentre,
                    onLogout: _logout,
                    loading: _isLoading,
                  ),
                  const SizedBox(height: 12),
                  if (_stats == null && _statsError != null)
                    AdminCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: AdminColors.red),
                            const SizedBox(height: 8),
                            Text(_statsError!, style: AdminText.body),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _loadCommandCentre,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_stats == null)
                    const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    PulseStrip(
                      stats: _stats!.pulse,
                      series: _series,
                      columns: desktop ? 4 : 2,
                      onDauTap: () => _openMetrics('dau', 'Active Today'),
                      onNewTodayTap: () => _openMetrics('signups', 'New Today'),
                      onAttemptsTap: () => _openMetrics('attempts', 'Attempts'),
                      onTotalUsersTap: () => _openMetrics('total_users', 'Total Users'),
                    ),
                    const SizedBox(height: 12),
                    if (_stats!.queues.reportsNew > 0 || _stats!.queues.contribsNew > 0) ...[
                      ActionNeededCard(
                        queues: _stats!.queues,
                        onReportsTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ContentHubScreen(initialTab: 2)),
                        ),
                        onContribsTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ContentHubScreen(initialTab: 3)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TrendChartCard(series: _series),
                    const SizedBox(height: 20),
                    if (desktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: LiveFeed(events: _stats!.recent)),
                          const SizedBox(width: 12),
                          Expanded(flex: 3, child: SignInDonutCard(signIn: _stats!.signIn)),
                          const SizedBox(width: 12),
                          Expanded(flex: 4, child: CategoriesBarCard(categories: _stats!.categoriesToday)),
                        ],
                      )
                    else if (!mobile)
                      Column(
                        children: [
                          LiveFeed(events: _stats!.recent),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: SignInDonutCard(signIn: _stats!.signIn)),
                              const SizedBox(width: 12),
                              Expanded(child: CategoriesBarCard(categories: _stats!.categoriesToday)),
                            ],
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          LiveFeed(events: _stats!.recent),
                          const SizedBox(height: 12),
                          SignInDonutCard(signIn: _stats!.signIn),
                          const SizedBox(height: 12),
                          CategoriesBarCard(categories: _stats!.categoriesToday),
                        ],
                      ),
                    const SizedBox(height: 12),
                    TopPlayersCard(players: _stats!.topPlayers),
                    const SizedBox(height: 12),
                    ContentHealthStrip(
                      adventure: _totalQuestions,
                      language: _totalLangQuestions,
                      categories: _categoryCounts.length,
                      users: _stats!.pulse.totalUsers,
                    ),
                    const SizedBox(height: 20),
                    AdminSectionTitle('Manage'),
                    const SizedBox(height: 12),
                    ManageActionsRow(
                      onHub: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ContentHubScreen()),
                      ),
                      onUsers: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UserLookupScreen()),
                      ),
                      onContent: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UserLookupScreen()),
                      ),
                    ),
                  
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
