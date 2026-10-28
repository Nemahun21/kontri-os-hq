class PulseSeries {
  const PulseSeries({
    this.dau = const [],
    this.signups = const [],
    this.attempts = const [],
    this.totalUsers = const [],
  });

  final List<({DateTime day, int value})> dau;
  final List<({DateTime day, int value})> signups;
  final List<({DateTime day, int value})> attempts;
  final List<({DateTime day, int value})> totalUsers;

  List<({DateTime day, int value})> last(int n, List<({DateTime day, int value})> values) {
    if (n <= 0 || values.isEmpty) {
      return const [];
    }
    final start = values.length > n ? values.length - n : 0;
    return values.sublist(start);
  }

  List<({DateTime day, int value})> previous(int n, List<({DateTime day, int value})> values) {
    if (n <= 0 || values.length <= n) {
      return const [];
    }
    final end = values.length - n;
    return values.sublist(0, end);
  }

  double? deltaPct(int n, List<({DateTime day, int value})> values) {
    if (values.isEmpty || n <= 0) {
      return null;
    }

    final current = last(n, values);
    final prev = previous(n, values);
    if (current.isEmpty || prev.isEmpty) {
      return null;
    }

    final currentTotal = current.fold<int>(0, (sum, item) => sum + item.value);
    final previousTotal = prev.fold<int>(0, (sum, item) => sum + item.value);
    if (previousTotal == 0) {
      return null;
    }

    return ((currentTotal - previousTotal) / previousTotal) * 100;
  }
}
