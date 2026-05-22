import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class ProgressService {
  static final _supabase = Supabase.instance.client;

  /// Fetches all completed sublevels for the currently logged-in user.
  /// Returns a list of maps, each containing level_code, sub_level, is_completed, score.
  static Future<List<Map<String, dynamic>>> fetchSublevelProgress() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('user_sublevel_progress')
          .select('level_code, sub_level, is_completed, score')
          .eq('user_id', user.id);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Return empty list on failure, gracefully falling back
      return [];
    }
  }

  /// Marks a sublevel as completed and updates/recalculates user study streak atomically.
  /// Uses the `complete_practice_session` RPC function in Supabase.
  static Future<bool> completePractice({
    required String levelCode,
    required int subLevel,
    required int score,
    required bool isCompleted,
  }) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return false;

      // Invoke RPC complete_practice_session
      await _supabase.rpc('complete_practice_session', params: {
        'p_user_id': user.id,
        'p_level_code': levelCode.toLowerCase(),
        'p_sub_level': subLevel,
        'p_score': score,
        'p_is_completed': isCompleted,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Calculates the completion percentage (0.0 to 1.0) for a given level (A1-C2).
  /// A level is completed when all 6 sublevels are marked is_completed = true.
  static double getLevelCompletionPercentage({
    required String levelCode,
    required List<Map<String, dynamic>> completedSublevels,
  }) {
    if (completedSublevels.isEmpty) return 0.0;

    final targetLevel = levelCode.toLowerCase();
    final completedCount = completedSublevels
        .where((progress) =>
            progress['level_code'].toString().toLowerCase() == targetLevel &&
            progress['is_completed'] == true)
        .map((progress) => progress['sub_level'] as int)
        .toSet() // Deduplicate just in case
        .length;

    // Symmetrical 6 sublevels per difficulty level
    final percentage = completedCount / 6.0;
    return percentage > 1.0 ? 1.0 : percentage;
  }

  /// Determines if a difficulty level (a1-c2) is unlocked for the user.
  /// 'a1' is unlocked by default. Subsequent levels unlock once the previous
  /// level is 100% completed (all 6 sublevels is_completed = true).
  static bool isLevelUnlocked({
    required String levelCode,
    required List<Map<String, dynamic>> completedSublevels,
  }) {
    final levelOrder = ['a1', 'a2', 'b1', 'b2', 'c1', 'c2'];
    final index = levelOrder.indexOf(levelCode.toLowerCase());

    // If level is not in the list, or is A1 (index <= 0), it's unlocked by default.
    if (index <= 0) return true;

    // Check completion of the preceding level
    final prevLevel = levelOrder[index - 1];
    final prevProgress = getLevelCompletionPercentage(
      levelCode: prevLevel,
      completedSublevels: completedSublevels,
    );

    // Fully completed means progress is 1.0 (all 6 sublevels finished)
    return prevProgress >= 1.0;
  }

  /// Determines if a specific sublevel (1-6) within a level is unlocked.
  /// The parent level must be unlocked.
  /// Sublevel 1 is always unlocked.
  /// Sublevel N (>= 2) requires Sublevel N-1 to be completed.
  static bool isSublevelUnlocked({
    required String levelCode,
    required int subLevel,
    required List<Map<String, dynamic>> completedSublevels,
  }) {
    // First, check if the parent level itself is unlocked
    if (!isLevelUnlocked(levelCode: levelCode, completedSublevels: completedSublevels)) {
      return false;
    }

    // Sublevel 1 is unlocked by default within an unlocked level
    if (subLevel <= 1) return true;

    // Sublevel N requires Sublevel N-1 to be completed
    final targetLevel = levelCode.toLowerCase();
    return completedSublevels.any((p) =>
        p['level_code'].toString().toLowerCase() == targetLevel &&
        p['sub_level'] == subLevel - 1 &&
        p['is_completed'] == true);
  }
}

