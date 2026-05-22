import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tactile_button.dart';
import '../../../core/widgets/feedback_toast.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/services/battle_service.dart';
import '../../../main.dart' show appNavigatorKey, appReady;
import '../screens/battle_screen.dart';
import '../screens/waiting_challenge_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnlineFriendsFab extends StatefulWidget {
  const OnlineFriendsFab({super.key});

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
  late AnimationController _pulseAnim;
  final Set<String> _shownChallengeIds = {};

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

    // Refresh player list every 30 seconds
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchPlayers());

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
  }

  void _onLogout() {
    _loggedIn = false;
    _onlinePlayers = [];
    _refreshTimer?.cancel();
    _challengeChannel?.unsubscribe();
    _presenceChannel?.unsubscribe();
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

  void _openPlayersSheet() {
    final context = _navCtx;
    if (context == null) return;

    _fetchPlayers();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.65,
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
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Arena de Batalla ⚔️',
                          style: AppTheme.headlineMd.copyWith(fontSize: 22),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _fetchPlayers();
                          },
                          icon: const Icon(Icons.close_rounded, color: AppTheme.onBackground),
                        )
                      ],
                    ),
                    Text(
                      'Desafía a cualquier usuario conectado a un reto de verbos en tiempo real.',
                      style: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    Expanded(
                      child: _onlinePlayers.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              itemCount: _onlinePlayers.length,
                              physics: const BouncingScrollPhysics(),
                              itemBuilder: (sheetCtx, index) {
                                final player = _onlinePlayers[index];
                                final name = player['full_name'] as String;
                                final pid = player['user_id'] as String;
                                final avatarUrl = player['avatar_url'] as String;

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
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 110,
                                        height: 38,
                                        child: TactileButton(
                                          text: 'Retar ⚔️',
                                          backgroundColor: AppTheme.secondary,
                                          darkColor: AppTheme.secondaryDark,
                                          textColor: AppTheme.onBackground,
                                          fontSize: 13,
                                          onTap: () async {
                                            Navigator.pop(ctx); // Close sheet
                                            FeedbackToast.showSuccess(
                                              context,
                                              title: 'Enviando desafío',
                                              message: 'Preparando reto para $name...',
                                            );
                                            final session = await BattleService.createChallenge(pid);
                                            if (!context.mounted) return;
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
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _fetchPlayers();
    });
  }

  Widget _buildEmptyState() {
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

  @override
  Widget build(BuildContext context) {
    // Hide button if not logged in, or if the onboarding / splash is active
    if (!_loggedIn || !appReady.value) return const SizedBox.shrink();

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
