import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class BattleService {
  static final _client = Supabase.instance.client;
  static String? get _uid => _client.auth.currentUser?.id;

  // ── Session CRUD ──────────────────────────────────────────────────────────

  /// Crear una sesión de reto/batalla con otro jugador online
  static Future<Map<String, dynamic>?> createChallenge(String challengedId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final seed = Random().nextInt(999999);
      final rows = await _client
          .from('battle_sessions')
          .insert({
            'challenger_id': uid,
            'challenged_id': challengedId,
            'status': 'pending',
            'word_seed': seed,
          })
          .select()
          .single();
      return rows;
    } catch (_) {
      return null;
    }
  }

  /// Aceptar el reto entrante de otro jugador
  static Future<void> acceptChallenge(String sessionId) async {
    try {
      await _client.from('battle_sessions').update({
        'status': 'active',
        'started_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
    } catch (_) {}
  }

  /// Cancelar o rechazar un reto
  static Future<void> cancelSession(String sessionId) async {
    try {
      await _client
          .from('battle_sessions')
          .update({'status': 'cancelled'})
          .eq('id', sessionId);
    } catch (_) {}
  }

  /// Obtener detalles de una sesión específica
  static Future<Map<String, dynamic>?> getSession(String sessionId) async {
    try {
      return await _client
          .from('battle_sessions')
          .select()
          .eq('id', sessionId)
          .single();
    } catch (_) {
      return null;
    }
  }

  // ── Results ───────────────────────────────────────────────────────────────

  /// Subir el resultado individual del jugador al finalizar la ronda de preguntas
  static Future<void> submitResult({
    required String sessionId,
    required int score,
    required int errors,
    required int timeTakenMs,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('battle_results').upsert({
        'session_id': sessionId,
        'user_id': uid,
        'score': score,
        'errors': errors,
        'time_taken_ms': timeTakenMs,
        'completed_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Obtener todos los resultados de una sesión (ambos jugadores)
  static Future<List<Map<String, dynamic>>> getResults(String sessionId) async {
    try {
      final rows = await _client
          .from('battle_results')
          .select()
          .eq('session_id', sessionId);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  /// Resolver el ganador una vez que ambos jugadores han completado el reto
  /// Retorna el id del ganador, o null en caso de empate
  static Future<String?> resolveWinner(String sessionId) async {
    final results = await getResults(sessionId);
    if (results.length < 2) return null;

    final uid = _uid;
    final mine = results.firstWhere((r) => r['user_id'] == uid, orElse: () => {});
    final theirs = results.firstWhere((r) => r['user_id'] != uid, orElse: () => {});
    if (mine.isEmpty || theirs.isEmpty) return null;

    final myScore = mine['score'] as int;
    final theirScore = theirs['score'] as int;
    final myErrors = mine['errors'] as int;
    final theirErrors = theirs['errors'] as int;
    final myTime = mine['time_taken_ms'] as int? ?? 30000;
    final theirTime = theirs['time_taken_ms'] as int? ?? 30000;

    String? winnerId;
    if (myScore != theirScore) {
      winnerId = myScore > theirScore ? uid : theirs['user_id'];
    } else if (myErrors != theirErrors) {
      winnerId = myErrors < theirErrors ? uid : theirs['user_id'];
    } else if (myTime != theirTime) {
      winnerId = myTime < theirTime ? uid : theirs['user_id'];
    }

    if (winnerId != null) {
      await _client.from('battle_sessions').update({
        'status': 'finished',
        'winner_id': winnerId,
        'finished_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
    } else {
      // Empate
      await _client.from('battle_sessions').update({
        'status': 'finished',
        'finished_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
    }
    return winnerId;
  }

  /// Registrar resultado propio en el contador personal de estadísticas
  static Future<void> recordMyOutcome(String outcome) async {
    final uid = _uid;
    if (uid == null) return;
    await _updateStats(uid, outcome);
  }

  /// Registrar abandono propio de la partida
  static Future<void> recordAbandon(String sessionId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('battle_sessions').update({
        'status': 'abandoned',
        'abandoned_by': uid,
        'finished_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
      await _updateStats(uid, 'abandon');
    } catch (_) {}
  }

  static Future<void> _updateStats(String userId, String outcome) async {
    try {
      final existing = await _client
          .from('battle_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        await _client.from('battle_stats').insert({
          'user_id': userId,
          'wins': outcome == 'win' ? 1 : 0,
          'losses': outcome == 'loss' ? 1 : 0,
          'ties': outcome == 'tie' ? 1 : 0,
          'abandons': outcome == 'abandon' ? 1 : 0,
          'total_games': 1,
        });
      } else {
        await _client.from('battle_stats').update({
          'wins': (existing['wins'] as int) + (outcome == 'win' ? 1 : 0),
          'losses': (existing['losses'] as int) + (outcome == 'loss' ? 1 : 0),
          'ties': (existing['ties'] as int) + (outcome == 'tie' ? 1 : 0),
          'abandons': (existing['abandons'] as int? ?? 0) + (outcome == 'abandon' ? 1 : 0),
          'total_games': (existing['total_games'] as int) + 1,
        }).eq('user_id', userId);
      }
    } catch (_) {}
  }

  /// Obtener estadísticas personales de batallas
  static Future<Map<String, dynamic>?> getMyStats() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      return await _client
          .from('battle_stats')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  /// Obtener el reto pendiente más reciente recibido por el usuario
  static Future<Map<String, dynamic>?> getPendingChallenge() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final rows = await _client
          .from('battle_sessions')
          .select()
          .eq('challenged_id', uid)
          .eq('status', 'pending')
          .limit(1);
      return (rows as List).isNotEmpty
          ? Map<String, dynamic>.from(rows.first)
          : null;
    } catch (_) {
      return null;
    }
  }

  // ── Realtime channels ─────────────────────────────────────────────────────

  /// Suscribirse a retos entrantes en tiempo real
  static RealtimeChannel subscribeIncomingChallenges(
      void Function(Map<String, dynamic>) onChallenge) {
    final uid = _uid;
    final channel = _client.channel('incoming-challenges-${uid ?? "anon"}');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'battle_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'challenged_id',
            value: uid ?? '',
          ),
          callback: (payload) => onChallenge(payload.newRecord),
        )
        .subscribe();
    return channel;
  }
}
