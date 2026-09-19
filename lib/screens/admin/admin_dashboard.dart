import 'package:flutter/material.dart';
import 'package:kohntri_os_hq/screens/admin/content_bank_screen.dart';
import 'package:kohntri_os_hq/screens/admin/daily_content_overview.dart';
import 'package:kohntri_os_hq/screens/auth/login_screen.dart';
import 'package:kohntri_os_hq/screens/languages_management_screen.dart';
import 'package:kohntri_os_hq/screens/quiz_category_selection_screen.dart';
import 'package:kohntri_os_hq/services/cache_service.dart';
import 'package:kohntri_os_hq/services/daily_challenge_service.dart';
import 'package:kohntri_os_hq/services/language_question_service.dart';
import 'package:kohntri_os_hq/services/question_service.dart';
import 'package:kohntri_os_hq/utils/connectivity_helper.dart';
import 'package:kohntri_os_hq/widgets/loading_overlay.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic>? adminData;
  const AdminDashboard({super.key, this.adminData});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _adminData;

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
        child: _isLoading
            ? const LoadingOverlay(message: 'Loading...')
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // Admin info (unchanged)
                    _buildAdminHeader(context),

                    const SizedBox(height: 8),

                    // Compact stats row
                    _buildStatsRow(),

                    const SizedBox(height: 24),

                    // Perform actions title
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

                    // Compact list of actions
                    _buildPerformActions(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  // =====================================================
  // STATS ROW (compact 3-across)
  // =====================================================
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _statTile(
              icon: Icons.quiz_outlined,
              value: '$_totalQuestions',
              label: 'Questions',
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statTile(
              icon: Icons.category_outlined,
              value: '${_categoryCounts.length}',
              label: 'Categories',
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statTile(
              icon: Icons.people_outline,
              value: '$_totalUsers',
              label: 'Users',
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // PERFORM ACTIONS (compact list)
  // =====================================================
  Widget _buildPerformActions() {
    final dailyChallengeCount = _categoryCounts['Daily Challenge'] ?? 0;
    const quizSubs = ['History', 'Sports', 'Places', 'Food'];
    final quizCount = quizSubs.fold<int>(
      0,
      (sum, cat) => sum + (_categoryCounts[cat] ?? 0),
    );

    final actions = [
      _ActionItem(
        title: 'Daily Content',
        subtitle: '$dailyChallengeCount items • rotation',
        icon: Icons.calendar_today_outlined,
        color: Colors.orange,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DailyContentOverview()),
        ),
      ),
      _ActionItem(
        title: 'Quiz Category',
        subtitle: '$quizCount questions • History / Sports / Places / Food',
        icon: Icons.quiz_outlined,
        color: Colors.green,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const QuizCategorySelectionScreen(
                parentCategory: 'Quiz Category',
                subCategories: ['History', 'Sports', 'Places', 'Food'],
              ),
            ),
          );
        },
      ),
      _ActionItem(
        title: 'Languages',
        subtitle: '$_totalLangQuestions questions',
        icon: Icons.language_outlined,
        color: Colors.red,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LanguagesManagementScreen(),
          ),
        ),
      ),
      _ActionItem(
        title: 'Question Bank',
        subtitle: '$_totalQuestions total across all categories',
        icon: Icons.list_alt_outlined,
        color: Colors.blue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ContentBankScreen()),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: actions
            .map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _actionRow(a),
                ))
            .toList(),
      ),
    );
  }

  Widget _actionRow(_ActionItem action) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: action.color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: action.color.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: action.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, color: action.color, size: 22),
              ),
              const SizedBox(width: 14),

              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(Icons.chevron_right,
                  color: Colors.grey[400], size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// Action item helper class
// =====================================================
class _ActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}