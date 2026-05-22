import 'package:supabase_flutter/supabase_flutter.dart';

class FriendService {
  static final _client = Supabase.instance.client;
  static String? get _uid => _client.auth.currentUser?.id;

  /// Enviar una solicitud de amistad o reintentar una cancelada.
  static Future<bool> sendFriendRequest(String receiverId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _client.from('friendships').upsert({
        'sender_id': uid,
        'receiver_id': receiverId,
        'status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'sender_id,receiver_id');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Aceptar una solicitud de amistad.
  static Future<bool> acceptFriendRequest(String friendshipId) async {
    try {
      await _client.from('friendships').update({
        'status': 'accepted',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', friendshipId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Rechazar o retirar una solicitud de amistad o eliminar un amigo.
  static Future<bool> removeFriendship(String friendshipId) async {
    try {
      await _client.from('friendships').delete().eq('id', friendshipId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Obtener todos los amigos (bidireccional, estado 'accepted').
  /// Retorna una lista con la información del perfil del amigo y el ID de la amistad.
  static Future<List<Map<String, dynamic>>> getFriends() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final res = await _client
          .from('friendships')
          .select('id, sender_id, receiver_id, sender:sender_id(id, full_name, avatar_url), receiver:receiver_id(id, full_name, avatar_url)')
          .eq('status', 'accepted')
          .or('sender_id.eq.$uid,receiver_id.eq.$uid');

      final list = List<Map<String, dynamic>>.from(res);
      final friends = <Map<String, dynamic>>[];

      for (final item in list) {
        final friendshipId = item['id'] as String;
        final senderId = item['sender_id'] as String;
        final isSenderMe = senderId == uid;
        
        final profile = isSenderMe
            ? item['receiver'] as Map<String, dynamic>?
            : item['sender'] as Map<String, dynamic>?;

        if (profile != null) {
          friends.add({
            'friendship_id': friendshipId,
            'user_id': profile['id'],
            'full_name': profile['full_name'] ?? 'Usuario Anónimo',
            'avatar_url': profile['avatar_url'] ?? '',
          });
        }
      }
      return friends;
    } catch (_) {
      return [];
    }
  }

  /// Obtener las solicitudes entrantes pendientes de aprobación (receiver_id = me).
  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final res = await _client
          .from('friendships')
          .select('id, sender_id, sender:sender_id(id, full_name, avatar_url)')
          .eq('receiver_id', uid)
          .eq('status', 'pending');

      final list = List<Map<String, dynamic>>.from(res);
      return list.map((item) {
        final profile = item['sender'] as Map<String, dynamic>? ?? {};
        return {
          'friendship_id': item['id'],
          'user_id': item['sender_id'],
          'full_name': profile['full_name'] ?? 'Usuario Anónimo',
          'avatar_url': profile['avatar_url'] ?? '',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Obtener todas las relaciones de amistad (tanto pendientes como aceptadas)
  /// del usuario actual para mapear estados de amistad.
  static Future<List<Map<String, dynamic>>> getAllMyFriendships() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final res = await _client
          .from('friendships')
          .select('id, sender_id, receiver_id, status')
          .or('sender_id.eq.$uid,receiver_id.eq.$uid');
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  /// Buscar usuarios por su nombre y retornar el perfil asociado con el estado
  /// de la amistad con respecto al usuario logueado.
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final uid = _uid;
    if (uid == null) return [];
    if (query.trim().isEmpty) return [];
    try {
      // 1. Buscar perfiles
      final profilesRes = await _client
          .from('profiles')
          .select('id, full_name, avatar_url')
          .neq('id', uid)
          .ilike('full_name', '%$query%')
          .limit(20);

      final profiles = List<Map<String, dynamic>>.from(profilesRes);

      // 2. Obtener todas mis relaciones de amistad
      final myFriendships = await getAllMyFriendships();

      // 3. Cruzar datos
      return profiles.map((p) {
        final pid = p['id'] as String;
        
        // Buscar si existe relación de amistad con este perfil
        final friendship = myFriendships.firstWhere(
          (f) => (f['sender_id'] == pid || f['receiver_id'] == pid),
          orElse: () => {},
        );

        String friendshipStatus = 'none'; // none, pending_sent, pending_received, accepted
        String friendshipId = '';

        if (friendship.isNotEmpty) {
          friendshipId = friendship['id'] as String;
          final status = friendship['status'] as String;
          if (status == 'accepted') {
            friendshipStatus = 'accepted';
          } else if (status == 'pending') {
            final senderId = friendship['sender_id'] as String;
            friendshipStatus = senderId == uid ? 'pending_sent' : 'pending_received';
          }
        }

        return {
          'user_id': pid,
          'full_name': p['full_name'] ?? 'Usuario Anónimo',
          'avatar_url': p['avatar_url'] ?? '',
          'friendship_status': friendshipStatus,
          'friendship_id': friendshipId,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
