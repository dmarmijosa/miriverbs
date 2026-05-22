import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tactile_button.dart';
import '../../../core/widgets/feedback_toast.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/services/battle_service.dart';
import '../../../core/services/friend_service.dart';
import '../../../main.dart' show appNavigatorKey, appReady;
import '../screens/battle_screen.dart';
import '../screens/waiting_challenge_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnlineFriendsFab extends StatefulWidget {
  const OnlineFriendsFab({super.key});

  static final ValueNotifier<bool> isVisible = ValueNotifier<bool>(true);

  @override
  State<OnlineFriendsFab> createState() => _OnlineFriendsFabState();
}

class _OnlineFriendsFabState extends State<OnlineFriendsFab>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _onlinePlayers = [];
  bool _loggedIn = false;
  Timer? _refreshTimer;
  RealtimeChannel? _challengeChannel;
  RealtimeChannel? _presenceChannel;
  RealtimeChannel? _friendsChannel; // Listen to friend changes
  late AnimationController _pulseAnim;
  final Set<String> _shownChallengeIds = {};

  // Debouncing / Modal protection flag
  bool _isSheetOpen = false;

  // Social Hub state variables
  int _activeTab = 0; // 0 = Arena, 1 = Amigos, 2 = Social (Buscar / Solicitudes)
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _myFriends = [];
  List<Map<String, dynamic>> _myFriendships = [];
  bool _loadingSearch = false;
  bool _loadingSocial = false;

  BuildContext? get _navCtx => appNavigatorKey.currentContext;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _setupStateListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseAnim.dispose();
    _refreshTimer?.cancel();
    _challengeChannel?.unsubscribe();
    _presenceChannel?.unsubscribe();
    _friendsChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_loggedIn) return;
    if (state == AppLifecycleState.resumed) {
      PresenceService.goOnline();
      _fetchPlayers();
    } else if (state == AppLifecycleState.paused) {
      PresenceService.goOffline();
    }
  }

  void _setupStateListener() {
    final client = Supabase.instance.client;
    
    // Check initial state
    if (client.auth.currentSession != null) {
      _onLogin();
    }

    client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        _onLogin();
      } else {
        _onLogout();
      }
    });
  }

  void _onLogin() {
    if (_loggedIn) return;
    setState(() => _loggedIn = true);

    PresenceService.goOnline();
    _fetchPlayers();
    _loadSocialData();

    // Refresh player list every 30 seconds
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchPlayers();
      if (_isSheetOpen) _loadSocialData();
    });

    // Listen for changes in presence table
    _presenceChannel?.unsubscribe();
    _presenceChannel = PresenceService.subscribePresences((_) {
      _fetchPlayers();
    });

    // Listen for incoming challenges
    _challengeChannel?.unsubscribe();
    _challengeChannel = BattleService.subscribeIncomingChallenges((payload) {
      final sessionId = payload['id'] as String;
      if (_shownChallengeIds.contains(sessionId)) return;
      _shownChallengeIds.add(sessionId);

      final challengerId = payload['challenger_id'] as String;
      
      // Fetch challenger details
      Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', challengerId)
          .single()
          .then((profile) {
            final challengerName = profile['full_name'] as String? ?? 'Un estudiante';
            _showChallengeDialog(sessionId, challengerId, challengerName);
          });
    });

    // Realtime channel for friendship changes
    final uid = Supabase.instance.client.auth.currentUser?.id;
    _friendsChannel?.unsubscribe();
    _friendsChannel = Supabase.instance.client.channel('friendship-changes-${uid ?? "anon"}');
    _friendsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          callback: (payload) {
            _loadSocialData();
          },
        )
        .subscribe();
  }

  void _onLogout() {
    _loggedIn = false;
    _onlinePlayers = [];
    _myFriends = [];
    _pendingRequests = [];
    _myFriendships = [];
    _refreshTimer?.cancel();
    _challengeChannel?.unsubscribe();
    _presenceChannel?.unsubscribe();
    _friendsChannel?.unsubscribe();
    if (mounted) setState(() {});
  }

  Future<void> _fetchPlayers() async {
    if (!_loggedIn) return;
    final players = await PresenceService.getOnlinePlayers();
    if (mounted) {
      setState(() {
        _onlinePlayers = players;
      });
    }
  }

  Future<void> _loadSocialData() async {
    if (!_loggedIn) return;
    try {
      final friends = await FriendService.getFriends();
      final pending = await FriendService.getPendingRequests();
      final friendships = await FriendService.getAllMyFriendships();
      if (mounted) {
        setState(() {
          _myFriends = friends;
          _pendingRequests = pending;
          _myFriendships = friendships;
        });
      }
    } catch (_) {}
  }

  void _showChallengeDialog(String sessionId, String challengerId, String name) {
    final context = _navCtx;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _IncomingChallengeAlert(
        sessionId: sessionId,
        challengerId: challengerId,
        challengerName: name,
      ),
    );
  }

  /// Trigger debounced modal opening
  void _openPlayersSheet() {
    if (_isSheetOpen) return;
    
    final context = _navCtx;
    if (context == null) return;

    setState(() => _isSheetOpen = true);

    _fetchPlayers();
    _loadSocialData();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            // Helper function to load data internally inside sheet
            Future<void> refreshSocialSheet() async {
              setSheetState(() => _loadingSocial = true);
              await _loadSocialData();
              await _fetchPlayers();
              if (_searchQuery.trim().isNotEmpty) {
                final searchRes = await FriendService.searchUsers(_searchQuery);
                setSheetState(() {
                  _searchResults = searchRes;
                  _loadingSocial = false;
                });
              } else {
                setSheetState(() => _loadingSocial = false);
              }
            }

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.70,
              decoration: const BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusExtraLarge),
                  topRight: Radius.circular(AppTheme.radiusExtraLarge),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pull indicator
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppTheme.outline.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Arena y Amigos ⚔️',
                          style: AppTheme.headlineMd.copyWith(fontSize: 22),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: AppTheme.onBackground),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Custom Premium Sliding Tab Bar
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.08), width: 1.5),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _buildTabItem(0, '⚔️ Arena', setSheetState, refreshSocialSheet),
                          _buildTabItem(1, '👥 Amigos', setSheetState, refreshSocialSheet),
                          _buildTabItem(2, '🔍 Social', setSheetState, refreshSocialSheet),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Active Tab Contents
                    Expanded(
                      child: _loadingSocial
                          ? const Center(
                              child: CircularProgressIndicator(color: AppTheme.primary),
                            )
                          : _buildActiveTabContent(sheetCtx, setSheetState, refreshSocialSheet),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _isSheetOpen = false;
        });
        _fetchPlayers();
      }
    });
  }

  Widget _buildTabItem(int index, String label, StateSetter setSheetState, Future<void> Function() refresh) {
    final active = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setSheetState(() {
            _activeTab = index;
          });
          refresh();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTheme.labelLg.copyWith(
              color: active ? Colors.white : AppTheme.onSurfaceVariant,
              fontWeight: active ? FontWeight.w900 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(BuildContext sheetCtx, StateSetter setSheetState, Future<void> Function() refresh) {
    switch (_activeTab) {
      case 0:
        return _buildArenaTab(sheetCtx, setSheetState, refresh);
      case 1:
        return _buildFriendsTab(sheetCtx, setSheetState, refresh);
      case 2:
        return _buildSocialTab(sheetCtx, setSheetState, refresh);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── ARENA TAB ──────────────────────────────────────────────────────────────
  Widget _buildArenaTab(BuildContext sheetCtx, StateSetter setSheetState, Future<void> Function() refresh) {
    if (_onlinePlayers.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('☕', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'No hay otros jugadores online',
            textAlign: TextAlign.center,
            style: AppTheme.headlineMd.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Invita a un amigo a abrir la aplicación para competir en tiempo real.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Desafía a cualquier usuario conectado a un reto de verbos en tiempo real:',
          style: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: _onlinePlayers.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (sheetCtx, index) {
              final player = _onlinePlayers[index];
              final name = player['full_name'] as String;
              final pid = player['user_id'] as String;
              final avatarUrl = player['avatar_url'] as String;

              // Check friendship status
              final friendship = _myFriendships.firstWhere(
                (f) => (f['sender_id'] == pid || f['receiver_id'] == pid),
                orElse: () => {},
              );

              final isFriend = friendship.isNotEmpty && friendship['status'] == 'accepted';
              final isPending = friendship.isNotEmpty && friendship['status'] == 'pending';
              final isPendingSent = isPending && friendship['sender_id'] == Supabase.instance.client.auth.currentUser?.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(color: AppTheme.surfaceContainer, width: 1.5),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl.isEmpty
                          ? Text(
                              name.substring(0, 1).toUpperCase(),
                              style: AppTheme.labelLg.copyWith(color: AppTheme.primary),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: AppTheme.labelLg.copyWith(fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isFriend) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.people_alt_rounded, size: 14, color: AppTheme.primary),
                              ]
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'En línea',
                                style: AppTheme.bodyMd.copyWith(
                                  color: AppTheme.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    
                    // Friend action icon if not friends yet
                    if (!isFriend && !isPending)
                      IconButton(
                        tooltip: 'Agregar amigo',
                        icon: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary, size: 20),
                        onPressed: () async {
                          final ok = await FriendService.sendFriendRequest(pid);
                          if (!sheetCtx.mounted) return;
                          if (ok) {
                            FeedbackToast.showSuccess(
                              sheetCtx,
                              title: 'Solicitud enviada',
                              message: 'Se envió una solicitud de amistad a $name.',
                            );
                            await refresh();
                          }
                        },
                      )
                    else if (isPending && !isPendingSent)
                      IconButton(
                        tooltip: 'Aceptar solicitud',
                        icon: const Icon(Icons.how_to_reg_rounded, color: AppTheme.success, size: 20),
                        onPressed: () async {
                          final ok = await FriendService.acceptFriendRequest(friendship['id']);
                          if (!sheetCtx.mounted) return;
                          if (ok) {
                            FeedbackToast.showSuccess(
                              sheetCtx,
                              title: '¡Amigos agregados!',
                              message: 'Ahora eres amigo de $name.',
                            );
                            await refresh();
                          }
                        },
                      )
                    else if (isPendingSent)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Pendiente',
                          style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),

                    const SizedBox(width: 6),
                    SizedBox(
                      width: 90,
                      height: 36,
                      child: TactileButton(
                        text: 'Retar ⚔️',
                        backgroundColor: AppTheme.secondary,
                        darkColor: AppTheme.secondaryDark,
                        textColor: AppTheme.onBackground,
                        fontSize: 12,
                        onTap: () async {
                          Navigator.pop(sheetCtx); // Close sheet
                          FeedbackToast.showSuccess(
                            sheetCtx,
                            title: 'Enviando desafío',
                            message: 'Preparando reto para $name...',
                          );
                          final session = await BattleService.createChallenge(pid);
                          final context = appNavigatorKey.currentContext;
                          if (context == null || !context.mounted) return;
                          if (session != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WaitingChallengeScreen(
                                  sessionId: session['id'] as String,
                                  opponentId: pid,
                                  opponentName: name,
                                ),
                              ),
                            );
                          } else {
                            FeedbackToast.showError(
                              context,
                              title: 'Error de conexión',
                              message: 'No se pudo crear la sesión de reto.',
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── FRIENDS TAB ────────────────────────────────────────────────────────────
  Widget _buildFriendsTab(BuildContext sheetCtx, StateSetter setSheetState, Future<void> Function() refresh) {
    if (_myFriends.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👥', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'Aún no tienes amigos',
            textAlign: TextAlign.center,
            style: AppTheme.headlineMd.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Ve a la pestaña Social para buscar a otros estudiantes por nombre y agregarlos.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tus amigos agregados en Miriverbs (${_myFriends.length}):',
          style: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: _myFriends.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (sheetCtx, index) {
              final friend = _myFriends[index];
              final name = friend['full_name'] as String;
              final fid = friend['user_id'] as String;
              final avatarUrl = friend['avatar_url'] as String;
              final friendshipId = friend['friendship_id'] as String;

              // Check if friend is currently online
              final isOnline = _onlinePlayers.any((p) => p['user_id'] == fid);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(color: AppTheme.surfaceContainer, width: 1.5),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl.isEmpty
                          ? Text(
                              name.substring(0, 1).toUpperCase(),
                              style: AppTheme.labelLg.copyWith(color: AppTheme.primary),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTheme.labelLg.copyWith(fontSize: 15),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isOnline ? AppTheme.success : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isOnline ? 'En línea' : 'Desconectado',
                                style: AppTheme.bodyMd.copyWith(
                                  color: isOnline ? AppTheme.success : Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    
                    // Unfriend action
                    IconButton(
                      tooltip: 'Eliminar amigo',
                      icon: const Icon(Icons.person_remove_rounded, color: Colors.grey, size: 20),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: sheetCtx,
                          builder: (c) => AlertDialog(
                            title: const Text('Eliminar Amigo 👥'),
                            content: Text('¿Seguro que quieres eliminar a $name de tus amigos?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                              )
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final ok = await FriendService.removeFriendship(friendshipId);
                          if (!sheetCtx.mounted) return;
                          if (ok) {
                            FeedbackToast.showSuccess(
                              sheetCtx,
                              title: 'Amigo eliminado',
                              message: '$name ya no es tu amigo.',
                            );
                            await refresh();
                          }
                        }
                      },
                    ),

                    if (isOnline) ...[
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 90,
                        height: 36,
                        child: TactileButton(
                          text: 'Retar ⚔️',
                          backgroundColor: AppTheme.secondary,
                          darkColor: AppTheme.secondaryDark,
                          textColor: AppTheme.onBackground,
                          fontSize: 12,
                          onTap: () async {
                            Navigator.pop(sheetCtx); // Close sheet
                            FeedbackToast.showSuccess(
                              sheetCtx,
                              title: 'Enviando desafío',
                              message: 'Preparando reto para $name...',
                            );
                            final session = await BattleService.createChallenge(fid);
                            final context = appNavigatorKey.currentContext;
                            if (context == null || !context.mounted) return;
                            if (session != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WaitingChallengeScreen(
                                    sessionId: session['id'] as String,
                                    opponentId: fid,
                                    opponentName: name,
                                  ),
                                ),
                              );
                            } else {
                              FeedbackToast.showError(
                                context,
                                title: 'Error de conexión',
                                message: 'No se pudo crear la sesión de reto.',
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── SOCIAL / SEARCH TAB ────────────────────────────────────────────────────
  Widget _buildSocialTab(BuildContext sheetCtx, StateSetter setSheetState, Future<void> Function() refresh) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Input
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.outline.withValues(alpha: 0.1), width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            style: AppTheme.bodyMd.copyWith(color: AppTheme.onBackground),
            decoration: InputDecoration(
              icon: const Icon(Icons.search_rounded, color: AppTheme.onSurfaceVariant),
              hintText: 'Buscar estudiantes en Miriverbs...',
              hintStyle: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6)),
              border: InputBorder.none,
            ),
            onChanged: (val) {
              setSheetState(() {
                _searchQuery = val;
              });
              
              if (val.trim().isEmpty) {
                setSheetState(() {
                  _searchResults = [];
                  _loadingSearch = false;
                });
                return;
              }

              setSheetState(() => _loadingSearch = true);
              FriendService.searchUsers(val).then((res) {
                setSheetState(() {
                  _searchResults = res;
                  _loadingSearch = false;
                });
              });
            },
          ),
        ),
        const SizedBox(height: 16),

        // Display results or pending requests
        Expanded(
          child: _searchQuery.trim().isNotEmpty
              ? _buildSearchResults(sheetCtx, setSheetState, refresh)
              : _buildPendingRequests(sheetCtx, setSheetState, refresh),
        ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext sheetCtx, StateSetter setSheetState, Future<void> Function() refresh) {
    if (_loadingSearch) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_searchResults.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            'Sin resultados',
            style: AppTheme.headlineMd.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'No se encontraron usuarios con el nombre "$_searchQuery".',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (sheetCtx, index) {
        final result = _searchResults[index];
        final name = result['full_name'] as String;
        final pid = result['user_id'] as String;
        final avatarUrl = result['avatar_url'] as String;
        final status = result['friendship_status'] as String; // none, pending_sent, pending_received, accepted
        final friendshipId = result['friendship_id'] as String;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.surfaceContainer, width: 1.5),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        name.substring(0, 1).toUpperCase(),
                        style: AppTheme.labelLg.copyWith(color: AppTheme.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: AppTheme.labelLg.copyWith(fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              
              // friendship actions
              if (status == 'none')
                SizedBox(
                  width: 100,
                  height: 34,
                  child: TactileButton(
                    text: '+ Amigo',
                    backgroundColor: AppTheme.primary,
                    textColor: Colors.white,
                    darkColor: AppTheme.primaryDark,
                    fontSize: 12,
                    onTap: () async {
                      final ok = await FriendService.sendFriendRequest(pid);
                      if (!sheetCtx.mounted) return;
                      if (ok) {
                        FeedbackToast.showSuccess(
                          sheetCtx,
                          title: 'Solicitud enviada',
                          message: 'Has enviado una solicitud a $name.',
                        );
                        await refresh();
                      }
                    },
                  ),
                )
              else if (status == 'pending_sent')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Enviada',
                        style: AppTheme.labelLg.copyWith(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else if (status == 'pending_received')
                SizedBox(
                  width: 100,
                  height: 34,
                  child: TactileButton(
                    text: 'Aceptar 👍',
                    backgroundColor: AppTheme.success,
                    textColor: Colors.white,
                    darkColor: AppTheme.successDark,
                    fontSize: 12,
                    onTap: () async {
                      final ok = await FriendService.acceptFriendRequest(friendshipId);
                      if (!sheetCtx.mounted) return;
                      if (ok) {
                        FeedbackToast.showSuccess(
                          sheetCtx,
                          title: '¡Amigos agregados!',
                          message: 'Ahora eres amigo de $name.',
                        );
                        await refresh();
                      }
                    },
                  ),
                )
              else if (status == 'accepted')
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: Text(
                        'Amigos ✅',
                        style: AppTheme.labelLg.copyWith(fontSize: 12, color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.person_remove_rounded, color: Colors.grey, size: 18),
                      onPressed: () async {
                        final ok = await FriendService.removeFriendship(friendshipId);
                        if (!sheetCtx.mounted) return;
                        if (ok) {
                          FeedbackToast.showSuccess(
                            sheetCtx,
                            title: 'Amigo eliminado',
                            message: '$name ya no es tu amigo.',
                          );
                          await refresh();
                        }
                      },
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingRequests(BuildContext sheetCtx, StateSetter setSheetState, Future<void> Function() refresh) {
    if (_pendingRequests.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📬', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'Sin solicitudes pendientes',
            style: AppTheme.headlineMd.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Busca a otros estudiantes por nombre en el buscador de arriba para enviarles una solicitud de amistad.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Solicitudes de amistad recibidas (${_pendingRequests.length}):',
          style: AppTheme.labelLg.copyWith(fontSize: 14, color: AppTheme.onBackground),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: _pendingRequests.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (sheetCtx, index) {
              final request = _pendingRequests[index];
              final name = request['full_name'] as String;
              final avatarUrl = request['avatar_url'] as String;
              final friendshipId = request['friendship_id'] as String;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(color: AppTheme.surfaceContainer, width: 1.5),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl.isEmpty
                          ? Text(
                              name.substring(0, 1).toUpperCase(),
                              style: AppTheme.labelLg.copyWith(color: AppTheme.primary),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        name,
                        style: AppTheme.labelLg.copyWith(fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // decline button
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.error, size: 20),
                        onPressed: () async {
                          final ok = await FriendService.removeFriendship(friendshipId);
                          if (!sheetCtx.mounted) return;
                          if (ok) {
                            FeedbackToast.showSuccess(
                              sheetCtx,
                              title: 'Solicitud rechazada',
                              message: 'Has rechazado la solicitud de $name.',
                            );
                            await refresh();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // accept button
                    SizedBox(
                      width: 90,
                      height: 34,
                      child: TactileButton(
                        text: 'Aceptar 👍',
                        backgroundColor: AppTheme.success,
                        textColor: Colors.white,
                        darkColor: AppTheme.successDark,
                        fontSize: 12,
                        onTap: () async {
                          final ok = await FriendService.acceptFriendRequest(friendshipId);
                          if (!sheetCtx.mounted) return;
                          if (ok) {
                            FeedbackToast.showSuccess(
                              sheetCtx,
                              title: '¡Amigos agregados!',
                              message: 'Ahora eres amigo de $name.',
                            );
                            await refresh();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: OnlineFriendsFab.isVisible,
      builder: (context, visible, child) {
        // Hide button if not logged in, or if onboarding is active, or if sheet is open, or if explicitly hidden
        if (!visible || _isSheetOpen || !_loggedIn || !appReady.value) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 24,
          right: 20,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              final scale = 1.0 + (_pulseAnim.value * 0.05);
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: FloatingActionButton.extended(
              onPressed: _openPlayersSheet,
              elevation: 6,
              backgroundColor: AppTheme.primary,
              label: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: AppTheme.secondary, size: 24),
                  const SizedBox(width: 6),
                  Text(
                    'Arena ${_onlinePlayers.isNotEmpty ? '(${_onlinePlayers.length})' : ''}',
                    style: AppTheme.labelLg.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IncomingChallengeAlert extends StatelessWidget {
  final String sessionId;
  final String challengerId;
  final String challengerName;

  const _IncomingChallengeAlert({
    required this.sessionId,
    required this.challengerId,
    required this.challengerName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
        side: const BorderSide(color: AppTheme.primary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text('⚔️', style: TextStyle(fontSize: 52)),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Desafío Recibido!',
              textAlign: TextAlign.center,
              style: AppTheme.headlineMd.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 10),
            Text(
              '$challengerName te reta a un duelo de verbos en tiempo real. ¿Aceptas el combate?',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TactileButton(
                    text: 'Declinar',
                    backgroundColor: Colors.white,
                    textColor: AppTheme.error,
                    darkColor: AppTheme.surfaceContainer,
                    isSecondary: true,
                    onTap: () {
                      Navigator.pop(context);
                      BattleService.cancelSession(sessionId);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TactileButton(
                    text: '¡Pelear!',
                    backgroundColor: AppTheme.primary,
                    textColor: Colors.white,
                    darkColor: AppTheme.primaryDark,
                    onTap: () async {
                      Navigator.pop(context);
                      await BattleService.acceptChallenge(sessionId);
                      final navCtx = appNavigatorKey.currentContext;
                      if (navCtx == null || !navCtx.mounted) return;
                      Navigator.push(
                        navCtx,
                        MaterialPageRoute(
                          builder: (_) => BattleScreen(
                            sessionId: sessionId,
                            opponentId: challengerId,
                            opponentName: challengerName,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
