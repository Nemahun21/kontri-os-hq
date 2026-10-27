import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kohntri_os_hq/models/daily_challenge_question.dart';
import 'package:kohntri_os_hq/services/cache_service.dart';
import 'package:kohntri_os_hq/utils/connectivity_helper.dart';

class DailyChallengeService {
  final supabase = Supabase.instance.client;
  final _cache = CacheService();
  static const String activeDailyChallengeId = 'active';
Future<int> getNextPosition() async {
  // Always return the first unused position for this challenge.
  // Works the same online and offline so the caller doesn't need to know.
  final online = await ConnectivityHelper.isOnline();

  Set<int> used = <int>{};

  if (online) {
    try {
      final response = await supabase
          .from('daily_challenge_questions')
          .select('position')
          .eq('daily_challenge_id', activeDailyChallengeId)
          .order('position', ascending: true);

      for (final row in response) {
        final p = (row['position'] as num?)?.toInt();
        if (p != null) used.add(p);
      }
    } catch (_) {
      final cached = await _cache.getList<DailyChallengeQuestion>(
        'daily_challenge_list',
        DailyChallengeQuestion.fromSupabase,
      );
      used = cached.map((q) => q.position).toSet();
    }
  } else {
    final cached = await _cache.getList<DailyChallengeQuestion>(
      'daily_challenge_list',
      DailyChallengeQuestion.fromSupabase,
    );
    used = cached.map((q) => q.position).toSet();
  }

  // First free slot starting at 1.
  int next = 1;
  while (used.contains(next)) {
    next++;
  }
  return next;
}
  Future<List<DailyChallengeQuestion>> getDailyChallengeQuestions() async {
    const cacheKey = 'daily_challenge_list';
    final online = await ConnectivityHelper.isOnline();

    if (online) {
      try {
        final response = await supabase
            .from('daily_challenge_questions')
            .select()
            .eq('daily_challenge_id', activeDailyChallengeId)
           .order('position');
        final questions = (response as List)
            .map((json) => DailyChallengeQuestion.fromSupabase(json))
            .toList();
        await _cache.set(cacheKey, questions.map((q) => q.toSupabase()).toList());
        return questions;
      } catch (_) {
        final cached = await _cache.getList<DailyChallengeQuestion>(cacheKey, DailyChallengeQuestion.fromSupabase);
        if (cached.isNotEmpty) return cached;
        rethrow;
      }
    } else {
      final cached = await _cache.getList<DailyChallengeQuestion>(cacheKey, DailyChallengeQuestion.fromSupabase);
      return cached;
    }
  }

  // Write operations: add, update, delete – they will invalidate cache.
  Future<DailyChallengeQuestion> addQuestion(DailyChallengeQuestion question) async {
    final data = question.toSupabase()..remove('id');
    try {
      final response = await supabase
          .from('daily_challenge_questions')
          .insert(data)
          .select()
          .single();
      // Invalidate cache
      await _cache.set('daily_challenge_list', null);
      return DailyChallengeQuestion.fromSupabase(response);
    } catch (e) {
      // If offline, the screen should enqueue; but this method is only called when online in our pattern.
      rethrow;
    }
  }

  Future<DailyChallengeQuestion> updateQuestion(DailyChallengeQuestion question) async {
    await supabase
        .from('daily_challenge_questions')
        .update(question.toSupabase())
        .eq('id', question.id);
    await _cache.set('daily_challenge_list', null);
    return question;
  }

  Future<bool> deleteQuestion(String id) async {
    try {
      await supabase.from('daily_challenge_questions').delete().eq('id', id);
      await _cache.set('daily_challenge_list', null);
      return true;
    } catch (e) {
      return false;
    }
  }
}