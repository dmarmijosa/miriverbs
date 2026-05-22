import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService {
  static final _client = Supabase.instance.client;
  static String? get _uid => _client.auth.currentUser?.id;

  /// Marcar al usuario actual como "Online" en Supabase.
  static Future<void> goOnline() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('user_presences').upsert({
        'user_id': uid,
        'is_online': true,
        'presence_status': 'online',
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Marcar al usuario actual como "Away" (Ausente) en Supabase.
  static Future<void> goAway() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('user_presences').upsert({
        'user_id': uid,
        'is_online': true,
        'presence_status': 'away',
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Marcar al usuario actual como "Offline" en Supabase.
  static Future<void> goOffline() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('user_presences').upsert({
        'user_id': uid,
        'is_online': false,
        'presence_status': 'offline',
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Heartbeat para mantener el estado online vivo cada minuto.
  static Future<void> heartbeat() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client.from('user_presences').upsert({
        'user_id': uid,
        'is_online': true,
        'presence_status': 'online',
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Obtener la lista de todos los usuarios registrados que están online o away.
  /// Se considera online/away si su último 'last_seen' es de hace menos de 2 minutos.
  static Future<List<Map<String, dynamic>>> getOnlinePlayers() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      // 1. Obtener todas las presencias que estén marcadas como online
      final presencesRes = await _client
          .from('user_presences')
          .select('user_id, is_online, last_seen, presence_status')
          .eq('is_online', true);

      final onlinePresences = List<Map<String, dynamic>>.from(presencesRes);
      if (onlinePresences.isEmpty) return [];

      final activeUserPresences = <String, String>{};
      for (final p in onlinePresences) {
        final userId = p['user_id'] as String;
        if (userId == uid) continue; // Omitir el usuario actual

        final lastSeenStr = p['last_seen'] as String?;
        if (lastSeenStr != null) {
          final lastSeen = DateTime.tryParse(lastSeenStr);
          if (lastSeen != null &&
              DateTime.now().difference(lastSeen).inMinutes < 2) {
            final status = p['presence_status'] as String? ?? 'online';
            if (status == 'online' || status == 'away') {
              activeUserPresences[userId] = status;
            }
          }
        }
      }

      if (activeUserPresences.isEmpty) return [];

      // 2. Obtener los perfiles correspondientes a los usuarios activos
      final profilesRes = await _client
          .from('profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', activeUserPresences.keys.toList());

      final profiles = List<Map<String, dynamic>>.from(profilesRes);
      return profiles.map((profile) {
        final userId = profile['id'] as String;
        final status = activeUserPresences[userId] ?? 'online';
        return {
          'user_id': userId,
          'full_name': profile['full_name'] ?? 'Usuario Anónimo',
          'avatar_url': profile['avatar_url'] ?? '',
          'is_online': status == 'online',
          'presence_status': status,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Suscribirse a cambios en tiempo real en la tabla de presencias.
  static RealtimeChannel subscribePresences(void Function(Map<String, dynamic>) onChange) {
    final channel = _client.channel('global-presences');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_presences',
          callback: (payload) {
            final rec = payload.newRecord;
            if (rec.isNotEmpty && rec['user_id'] != _uid) {
              onChange(rec);
            }
          },
        )
        .subscribe();
    return channel;
  }
}
