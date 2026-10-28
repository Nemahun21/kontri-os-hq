class AdminUserSummary {
  const AdminUserSummary({
    required this.userId,
    required this.email,
    this.displayName,
    required this.totalScore,
    required this.currentStreak,
    this.lastActiveAt,
    this.createdAt,
    required this.isAdmin,
    required this.isBanned,
    required this.attemptsCount,
    required this.submissionsCount,
    required this.reportsCount,
  });

  final String userId;
  final String email;
  final String? displayName;
  final int totalScore;
  final int currentStreak;
  final DateTime? lastActiveAt;
  final DateTime? createdAt;
  final bool isAdmin;
  final bool isBanned;
  final int attemptsCount;
  final int submissionsCount;
  final int reportsCount;

  factory AdminUserSummary.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['created_at'] ?? json['createdAt'];
    final rawLastActiveAt = json['last_active_at'] ?? json['lastActiveAt'];

    return AdminUserSummary(
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      displayName: json['display_name'] == null
          ? null
          : json['display_name'].toString(),
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      attemptsCount: (json['attempts_count'] as num?)?.toInt() ?? 0,
      submissionsCount: (json['submissions_count'] as num?)?.toInt() ?? 0,
      reportsCount: (json['reports_count'] as num?)?.toInt() ?? 0,
      lastActiveAt: rawLastActiveAt is String
          ? DateTime.tryParse(rawLastActiveAt)
          : null,
      createdAt: rawCreatedAt is String
          ? DateTime.tryParse(rawCreatedAt)
          : null,
      isAdmin: (json['is_admin'] ?? json['isAdmin'] ?? false) as bool? ?? false,
      isBanned:
          (json['is_banned'] ?? json['isBanned'] ?? false) as bool? ?? false,
    );
  }
}

class AdminUserDetail {
  const AdminUserDetail({
    required this.profile,
    required this.isAdmin,
    required this.recentAttempts,
    required this.submissions,
    required this.reports,
  });

  final Map<String, dynamic> profile;
  final bool isAdmin;
  final List<Map<String, dynamic>> recentAttempts;
  final List<Map<String, dynamic>> submissions;
  final List<Map<String, dynamic>> reports;

  factory AdminUserDetail.fromJson(Map<String, dynamic> json) {
    final baseProfile = json['profile'] is Map
        ? json['profile'] as Map
        : const <String, dynamic>{};
    return AdminUserDetail(
      profile: Map<String, dynamic>.from(baseProfile),
      isAdmin: (json['is_admin'] ?? json['isAdmin'] ?? false) as bool? ?? false,
      recentAttempts: _mapList(
        json['recent_attempts'] ?? json['recentAttempts'],
      ),
      submissions: _mapList(json['submissions']),
      reports: _mapList(json['reports']),
    );
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }
}

class AdminContentSummary {
  const AdminContentSummary({
    required this.kind,
    required this.contentId,
    required this.question,
    required this.category,
    required this.themeOrLevel,
    required this.reportsCount,
    required this.attemptsCount,
    required this.passRate,
  });

  final String kind;
  final String contentId;
  final String question;
  final String category;
  final String themeOrLevel;
  final int reportsCount;
  final int attemptsCount;
  final double passRate;

  factory AdminContentSummary.fromJson(Map<String, dynamic> json) {
    return AdminContentSummary(
      kind: (json['kind'] ?? '').toString(),
      contentId: (json['content_id'] ?? json['contentId'] ?? '').toString(),
      question: (json['question'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      themeOrLevel: (json['theme_or_level'] ?? json['themeOrLevel'] ?? '')
          .toString(),
      reportsCount:  (json['reports_count']  as num?)?.toInt() ?? 0,
attemptsCount: (json['attempts_count'] as num?)?.toInt() ?? 0, passRate: 0.0,
    );
  }
}

class AdminContentDetail {
  const AdminContentDetail({
    required this.question,
    required this.kind,
    required this.reports,
    required this.attemptsStats,
    required this.recentAttempts,
  });

  final Map<String, dynamic> question;
  final String kind;
  final List<Map<String, dynamic>> reports;
  final Map<String, dynamic> attemptsStats;
  final List<Map<String, dynamic>> recentAttempts;

  factory AdminContentDetail.fromJson(Map<String, dynamic> json) {
    final baseQuestion = json['question'] is Map
        ? json['question'] as Map
        : const <String, dynamic>{};
    final attemptsRaw = json['attempts_stats'] is Map
        ? json['attempts_stats'] as Map
        : const <String, dynamic>{};

    return AdminContentDetail(
      question: Map<String, dynamic>.from(baseQuestion),
      kind: (json['kind'] ?? '').toString(),
      reports: _mapList(json['reports']),
      attemptsStats: Map<String, dynamic>.from(attemptsRaw),
      recentAttempts: _mapList(
        json['recent_attempts'] ?? json['recentAttempts'],
      ),
    );
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }
}
