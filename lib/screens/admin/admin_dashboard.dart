import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/screens/admin/admin_metrics_screen.dart';
import 'package:kohntri_os_hq/screens/admin/content_hub_screen.dart';
import 'package:kohntri_os_hq/screens/admin/content_lookup_screen.dart';
import 'package:kohntri_os_hq/screens/admin/user_lookup_screen.dart';
import 'package:kohntri_os_hq/screens/admin/widgets/live_feed.dart';
import 'package:kohntri_os_hq/screens/admin/widgets/top_players_card.dart';
import 'package:kohntri_os_hq/screens/auth/admin_approvals_screen.dart';
import 'package:kohntri_os_hq/screens/auth/login_screen.dart';
import 'package:kohntri_os_hq/screens/categories_list_screen.dart';
import 'package:kohntri_os_hq/screens/languages_list_screen.dart';
import 'package:kohntri_os_hq/services/admin_stats_service.dart';
import 'package:kohntri_os_hq/services/cache_service.dart';
import 'package:kohntri_os_hq/services/language_question_service.dart';
import 'package:kohntri_os_hq/services/question_service.dart';
import 'package:kohntri_os_hq/utils/connectivity_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin_theme.dart';
import '../../models/admin_stats.dart';
import '../../widgets/admin_card.dart';
import '../../widgets/categories_bar_card.dart';
import '../../widgets/dashboard_header.dart';
import '../../widgets/signin_donut_card.dart';

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic>? adminData;

  const AdminDashboard({super.key, this.adminData});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _adminData;
  AdminStats? _stats;
  String? _statsError;
  Timer? _refreshTimer;
  bool _isLoading = true;
  bool _refreshing = false;

  final QuestionService _questionService = QuestionService();
  final LanguageQuestionService _langService = LanguageQuestionService();

  // Fail safely while Test1 contains only the V2 language vertical slice.
  // Production dashboard logic remains intact for non-staging builds.
  bool get _isV2Staging =>
      const String.fromEnvironment('V2_SUPABASE_URL') ==
      'https://eeeusvsefoxbgshouqjb.supabase.co';
  int _stagingVocabularyCount = 0;
  int _stagingThemeCount = 0;
  String? _stagingLanguageError;

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
    if (_isV2Staging) {
      _loadStagingLanguageStats();
    } else {
      _loadCommandCentre();
      _loadStats();
    }
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refreshDashboard(),
    );
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

  Future<void> _loadStagingLanguageStats() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final results = await Future.wait<List<dynamic>>([
        Supabase.instance.client.from('language_type').select('id'),
        Supabase.instance.client.from('language_themes').select('id'),
        Supabase.instance.client.from('lesson_vocabulary').select('id')
            .eq('content_type', 'language'),
        Supabase.instance.client.from('language_questions').select('id'),
      ]);
      if (!mounted) return;
      setState(() {
        _categoryCounts = {'Languages': results[0].length};
        _stagingThemeCount = results[1].length;
        _stagingVocabularyCount = results[2].length;
        _totalLangQuestions = results[3].length;
        _stagingLanguageError = null;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('V2 staging language stats unavailable: $error');
      if (!mounted) return;
      setState(() {
        _stagingLanguageError = 'Language metrics temporarily unavailable';
        _isLoading = false;
      });
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
        _totalQuestions = counts.values.fold<int>(
          0,
          (sum, count) => sum + count,
        );
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
      if (_isV2Staging) {
        await _loadStagingLanguageStats();
      } else {
        await Future.wait([_loadCommandCentre(), _loadStats()]);
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _openMetrics(String metric, String title) {
    _push(AdminMetricsScreen(metric: metric, title: title));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $error')));
    }
  }

  // Lays tiles out in equal-width rows of `columns`.
  Widget _grid(List<Widget> tiles, int columns) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += columns) {
      final end = i + columns > tiles.length ? tiles.length : i + columns;
      final chunk = tiles.sublist(i, end);
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: 12),
                Expanded(
                  child: j < chunk.length ? chunk[j] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          rows[i],
        ],
      ],
    );
  }

  List<Widget> _stagingSections() {
    return [
      const AdminSectionTitle('V2 staging · Languages'),
      const SizedBox(height: 12),
      if (_stagingLanguageError != null)
        AdminCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_stagingLanguageError!),
                TextButton(
                  onPressed: _loadStagingLanguageStats,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      _grid([
        _DashTile(
          icon: Icons.translate_rounded,
          color: AdminColors.amber,
          title: 'Languages',
          subtitle: 'Open language and vocabulary management',
          value: '${_categoryCounts['Languages'] ?? 0}',
          valueLabel: 'languages',
          onTap: () => _push(const LanguagesListScreen()),
        ),
        _DashTile(
          icon: Icons.auto_stories_rounded,
          color: AdminColors.blue2,
          title: 'Themes',
          subtitle: 'Across languages in Test1',
          value: '$_stagingThemeCount',
          valueLabel: 'themes',
          onTap: () => _push(const LanguagesListScreen()),
        ),
        _DashTile(
          icon: Icons.style_rounded,
          color: AdminColors.green,
          title: 'Vocabulary',
          subtitle: 'Beginner · Intermediate · Advanced',
          value: '$_stagingVocabularyCount',
          valueLabel: 'words',
          onTap: () => _push(const LanguagesListScreen()),
        ),
        _DashTile(
          icon: Icons.quiz_rounded,
          color: AdminColors.red,
          title: 'Language quizzes',
          subtitle: 'Staging language questions',
          value: '$_totalLangQuestions',
          valueLabel: 'questions',
          onTap: () => _push(const LanguagesListScreen()),
        ),
      ], 2),
      const SizedBox(height: 16),
      const Text(
        'Adventure, Daily and advanced analytics are not yet connected '
        'to this staging database. Production metrics are not shown.',
      ),
      const SizedBox(height: 20),
      if (_adminData?['role'] == 'super_admin')
        OutlinedButton.icon(
          onPressed: () => _push(const AdminApprovalsScreen()),
          icon: const Icon(Icons.admin_panel_settings_outlined),
          label: const Text('Admin requests'),
        ),
    ];
  }

  List<Widget> _sections({required bool desktop, required bool mobile}) {
    final pulse = _stats!.pulse;
    final queues = _stats!.queues;
    final cols3 = mobile ? 1 : 3;
    final cols4 = desktop ? 4 : (mobile ? 1 : 2);
    const gap = SizedBox(height: 12);
    const sectionGap = SizedBox(height: 24);

    return [
      // 1. Overview metrics
      AdminSectionTitle('Overview'),
      gap,
      _grid([
        _DashTile(
          icon: Icons.bolt_rounded,
          color: AdminColors.blue2,
          title: 'DAU',
          subtitle: 'Weekly active: ${pulse.wau}',
          value: '${pulse.dau}',
          valueLabel: 'today',
          onTap: () => _openMetrics('dau', 'Active Today'),
        ),
        _DashTile(
          icon: Icons.person_add_alt_1_rounded,
          color: AdminColors.green,
          title: 'New users',
          subtitle: '${pulse.newWeek} joined this week',
          value: '${pulse.newToday}',
          valueLabel: 'today',
          onTap: () => _openMetrics('signups', 'New Today'),
        ),
        _DashTile(
          icon: Icons.groups_rounded,
          color: AdminColors.amber,
          title: 'Total users',
          subtitle: 'All registered accounts',
          value: '${pulse.totalUsers}',
          valueLabel: 'accounts',
          onTap: () => _openMetrics('total_users', 'Total Users'),
        ),
      ], cols3),
      sectionGap,

      // 2. Operations
      AdminSectionTitle('Operations'),
      gap,
      _grid([
        _DashTile(
          icon: Icons.report_problem_rounded,
          color: AdminColors.red,
          title: 'Reports',
          subtitle: 'Flagged content · ${queues.reportsWeek} this week',
          value: '${queues.reportsNew}',
          valueLabel: 'pending',
          onTap: () => _push(const ReportsManagementScreen()),
        ),
        _DashTile(
          icon: Icons.touch_app_rounded,
          color: AdminColors.blue2,
          title: 'Attempts',
          subtitle: 'Quiz activity · ${pulse.attemptsWeek} this week',
          value: '${pulse.attemptsToday}',
          valueLabel: 'today',
          onTap: () => _openMetrics('attempts', 'Attempts'),
        ),
        _DashTile(
          icon: Icons.volunteer_activism_rounded,
          color: AdminColors.amber,
          title: 'Contributions',
          subtitle: 'Community submissions · ${queues.contribsWeek} this week',
          value: '${queues.contribsNew}',
          valueLabel: 'new',
          onTap: () => _push(const ContributionsManagementScreen()),
        ),
      ], cols3),
      sectionGap,

      // 3. Content management
      AdminSectionTitle('Content management'),
      gap,
      _grid([
        _DashTile(
          icon: Icons.today_rounded,
          color: AdminColors.blue2,
          title: 'Daily',
          subtitle: 'Daily challenge and rotating content',
          value: '${_categoryCounts['Daily Challenge'] ?? 0}',
          valueLabel: 'questions',
          onTap: () => _push(const DailyManagementScreen()),
        ),
        _DashTile(
          icon: Icons.category_rounded,
          color: AdminColors.green,
          title: 'Categories',
          subtitle: 'Questions by category',
          value: '${_categoryCounts.length}',
          valueLabel: 'categories',
          onTap: () => _push(
            CategoriesListScreen(categoryCounts: _categoryCounts),
          ),
        ),
        _DashTile(
          icon: Icons.translate_rounded,
          color: AdminColors.amber,
          title: 'Languages',
          subtitle: 'Language questions by language',
          value: '$_totalLangQuestions',
          valueLabel: 'questions',
          onTap: () => _push(const LanguagesListScreen()),
        ),
        _DashTile(
          icon: Icons.fact_check_rounded,
          color: AdminColors.red,
          title: 'Audit content',
          subtitle: 'Inspect reports and attempts per question',
          onTap: () => _push(const ContentLookupScreen()),
        ),
      ], cols4),
      sectionGap,

      // 4. Analytics
      AdminSectionTitle('Analytics'),
      gap,
      if (desktop)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: LiveFeed(events: _stats!.recent)),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: CategoriesBarCard(categories: _stats!.categoriesToday),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: SignInDonutCard(signIn: _stats!.signIn),
            ),
          ],
        )
      else if (!mobile)
        Column(
          children: [
            LiveFeed(events: _stats!.recent),
            gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CategoriesBarCard(categories: _stats!.categoriesToday),
                ),
                const SizedBox(width: 12),
                Expanded(child: SignInDonutCard(signIn: _stats!.signIn)),
              ],
            ),
          ],
        )
      else
        Column(
          children: [
            LiveFeed(events: _stats!.recent),
            gap,
            CategoriesBarCard(categories: _stats!.categoriesToday),
            gap,
            SignInDonutCard(signIn: _stats!.signIn),
          ],
        ),
      sectionGap,

      // 5. Top players
      AdminSectionTitle('Top players'),
      gap,
      TopPlayersCard(players: _stats!.topPlayers),

      // 6. Admin requests (super admin only, as before)
      if (_adminData?['role'] == 'super_admin') ...[
        sectionGap,
        AdminSectionTitle('Admin requests'),
        gap,
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
            label: const Text('Admin requests'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.blue,
              side: BorderSide(
                color: AdminColors.blue.withValues(alpha: 0.4),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _push(const AdminApprovalsScreen()),
          ),
        ),
      ],
      const SizedBox(height: 16),
    ];
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
                    onUsers: () => _push(const UserLookupScreen()),
                    onContent: () => _push(const UserLookupScreen()),
                    onRefresh: _loadCommandCentre,
                    onLogout: _logout,
                    loading: _isLoading,
                  ),
                  const SizedBox(height: 12),
                  if (_isV2Staging)
                    ..._stagingSections()
                  else if (_stats == null && _statsError != null)
                    AdminCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AdminColors.red,
                            ),
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
                  else
                    ..._sections(desktop: desktop, mobile: mobile),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashTile extends StatelessWidget {
  const _DashTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.value,
    this.valueLabel,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? value;
  final String? valueLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isZero = value == '0';
    return AdminCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AdminText.small,
                ),
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value!,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isZero ? AdminColors.textSecondary : color,
                  ),
                ),
                if (valueLabel != null)
                  Text(valueLabel!, style: AdminText.small),
              ],
            ),
          ] else ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AdminColors.textSecondary,
            ),
          ],
        ],
      ),
    );
  }
}