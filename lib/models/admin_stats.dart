class AdminStats {
  final AdminPulse pulse;
  final List<SignInStat> signIn;
  final List<ActivityEvent> recent;
  final List<TopPlayer> topPlayers;
  final AdminQueues queues;
  final List<CategoryStat> categoriesToday;

  const AdminStats({
    this.pulse = const AdminPulse(),
    this.signIn = const <SignInStat>[],
    this.recent = const <ActivityEvent>[],
    this.topPlayers = const <TopPlayer>[],
    this.queues = const AdminQueues(),
    this.categoriesToday = const <CategoryStat>[],
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    final pulseJson = json['pulse'] is Map ? json['pulse'] as Map : const <String, dynamic>{};
    final signInJson = json['sign_in'] is List ? json['sign_in'] as List : const <dynamic>[];
    final recentJson = json['recent'] is List ? json['recent'] as List : const <dynamic>[];
    final topPlayersJson = json['top_players'] is List ? json['top_players'] as List : const <dynamic>[];
    final queuesJson = json['queues'] is Map ? json['queues'] as Map : const <String, dynamic>{};
    final categoriesJson = json['categories_today'] is List ? json['categories_today'] as List : const <dynamic>[];

    return AdminStats(
      pulse: AdminPulse.fromJson(Map<String, dynamic>.from(pulseJson)),
      signIn: signInJson
          .map((e) => SignInStat.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      recent: recentJson
          .map((e) => ActivityEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      topPlayers: topPlayersJson
          .map((e) => TopPlayer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      queues: AdminQueues.fromJson(Map<String, dynamic>.from(queuesJson)),
      categoriesToday: categoriesJson
          .map((e) => CategoryStat.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class AdminPulse {
  final int totalUsers;
  final int dau;
  final int wau;
  final int newToday;
  final int newWeek;
  final int attemptsToday;
  final int attemptsWeek;

  const AdminPulse({
    this.totalUsers = 0,
    this.dau = 0,
    this.wau = 0,
    this.newToday = 0,
    this.newWeek = 0,
    this.attemptsToday = 0,
    this.attemptsWeek = 0,
  });

  factory AdminPulse.fromJson(Map<String, dynamic> json) {
    return AdminPulse(
      totalUsers: (json['total_users'] as num?)?.toInt() ?? 0,
      dau: (json['dau'] as num?)?.toInt() ?? 0,
      wau: (json['wau'] as num?)?.toInt() ?? 0,
      newToday: (json['new_today'] as num?)?.toInt() ?? 0,
      newWeek: (json['new_week'] as num?)?.toInt() ?? 0,
      attemptsToday: (json['attempts_today'] as num?)?.toInt() ?? 0,
      attemptsWeek: (json['attempts_week'] as num?)?.toInt() ?? 0,
    );
  }
}

class SignInStat {
  final String provider;
  final int n;

  const SignInStat({this.provider = 'email', this.n = 0});

  factory SignInStat.fromJson(Map<String, dynamic> json) {
    return SignInStat(
      provider: (json['provider'] ?? 'email').toString(),
      n: (json['n'] as num?)?.toInt() ?? 0,
    );
  }
}

class ActivityEvent {
  final String email;
  final String? displayName;
  final String event;
  final DateTime? at;

  const ActivityEvent({
    this.email = '',
    this.displayName,
    this.event = 'signin',
    this.at,
  });

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    final rawAt = json['at'];
    return ActivityEvent(
      email: (json['email'] ?? '').toString(),
      displayName: json['display_name']?.toString(),
      event: (json['event'] ?? 'signin').toString(),
      at: rawAt is String ? DateTime.tryParse(rawAt) : null,
    );
  }
}

class TopPlayer {
  final String displayName;
  final int totalScore;
  final int currentStreak;

  const TopPlayer({
    this.displayName = '',
    this.totalScore = 0,
    this.currentStreak = 0,
  });

  factory TopPlayer.fromJson(Map<String, dynamic> json) {
    return TopPlayer(
      displayName: (json['display_name'] ?? '').toString(),
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminQueues {
  final int reportsNew;
  final int reportsWeek;
  final int contribsNew;
  final int contribsWeek;

  const AdminQueues({
    this.reportsNew = 0,
    this.reportsWeek = 0,
    this.contribsNew = 0,
    this.contribsWeek = 0,
  });

  factory AdminQueues.fromJson(Map<String, dynamic> json) {
    return AdminQueues(
      reportsNew: (json['reports_new'] as num?)?.toInt() ?? 0,
      reportsWeek: (json['reports_week'] as num?)?.toInt() ?? 0,
      contribsNew: (json['contribs_new'] as num?)?.toInt() ?? 0,
      contribsWeek: (json['contribs_week'] as num?)?.toInt() ?? 0,
    );
  }
}

class CategoryStat {
  final String category;
  final int attempts;

  const CategoryStat({this.category = '', this.attempts = 0});

  factory CategoryStat.fromJson(Map<String, dynamic> json) {
    return CategoryStat(
      category: (json['category'] ?? '').toString(),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    );
  }
}
