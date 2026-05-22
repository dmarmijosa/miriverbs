import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tactile_button.dart';
import '../../../core/widgets/feedback_toast.dart';
import '../../../core/services/battle_service.dart';
import '../screens/battle_screen.dart';
import '../../../main.dart' show appNavigatorKey;

class ClashingSwords extends StatefulWidget {
  const ClashingSwords({super.key});

  @override
  State<ClashingSwords> createState() => _ClashingSwordsState();
}

class _ClashingSwordsState extends State<ClashingSwords>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.92, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _rotation = Tween<double>(begin: -0.12, end: 0.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Transform.rotate(
            angle: _rotation.value,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.secondary, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondary.withValues(alpha: 0.25),
                    blurRadius: 18,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const Text(
                '⚔️',
                style: TextStyle(fontSize: 52),
              ),
            ),
          ),
        );
      },
    );
  }
}

class IncomingChallengeAlert extends StatefulWidget {
  final String sessionId;
  final String? challengerId;
  final String? challengerName;

  const IncomingChallengeAlert({
    super.key,
    required this.sessionId,
    this.challengerId,
    this.challengerName,
  });

  @override
  State<IncomingChallengeAlert> createState() => _IncomingChallengeAlertState();
}

class _IncomingChallengeAlertState extends State<IncomingChallengeAlert> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  RealtimeChannel? _sessionSubscription;

  String? _challengerName;
  String? _challengerId;
  String? _avatarUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _challengerName = widget.challengerName;
    _challengerId = widget.challengerId;

    _playClashSound();
    _subscribeToSessionChanges();

    if (_challengerName == null || _challengerName!.isEmpty || _challengerId == null || _challengerId!.isEmpty) {
      _loadDetails();
    } else {
      _isLoading = false;
      _loadAvatarOnly();
    }
  }

  @override
  void dispose() {
    _sessionSubscription?.unsubscribe();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playClashSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/sword_clash.wav'));
    } catch (e) {
      debugPrint('Error playing sword clash sound: $e');
    }
  }

  void _subscribeToSessionChanges() {
    _sessionSubscription = Supabase.instance.client
        .channel('incoming-alert-${widget.sessionId}');

    _sessionSubscription!.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'battle_sessions',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: widget.sessionId,
      ),
      callback: (payload) {
        final status = payload.newRecord['status'] as String?;
        if (!mounted) return;
        if (status == 'cancelled') {
          Navigator.of(context, rootNavigator: true).pop();
          FeedbackToast.showError(
            context,
            title: 'Reto Cancelado',
            message: 'El retador ha cancelado la invitación.',
          );
        }
      },
    ).subscribe();
  }

  Future<void> _loadDetails() async {
    try {
      final session = await BattleService.getSession(widget.sessionId);
      if (session == null || !mounted) return;

      final challengerId = session['challenger_id'] as String;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', challengerId)
          .maybeSingle();

      if (profile != null && mounted) {
        setState(() {
          _challengerId = challengerId;
          _challengerName = profile['full_name'] as String? ?? 'Un contrincante';
          _avatarUrl = profile['avatar_url'] as String?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _challengerName = 'Un estudiante';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAvatarOnly() async {
    if (_challengerId == null) return;
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('avatar_url')
          .eq('id', _challengerId!)
          .maybeSingle();
      if (profile != null && mounted) {
        setState(() {
          _avatarUrl = profile['avatar_url'] as String?;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.background.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: _isLoading
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary),
                      SizedBox(height: 16),
                      Text(
                        'Cargando desafío...',
                        style: TextStyle(color: AppTheme.onSurfaceVariant),
                      )
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: ClashingSwords(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '¡Desafío Recibido!',
                        textAlign: TextAlign.center,
                        style: AppTheme.headlineMd.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildAvatar(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _challengerName ?? 'Desafiante',
                                  style: AppTheme.labelLg.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Text(
                                  'Listo para el combate',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.tertiary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Te reta a un duelo de verbos en tiempo real. ¿Aceptas el combate?',
                        textAlign: TextAlign.center,
                        style: AppTheme.bodyMd.copyWith(
                          color: AppTheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
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
                                BattleService.cancelSession(widget.sessionId);
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TactileButton(
                              text: '¡Pelear!',
                              backgroundColor: AppTheme.primary,
                              textColor: Colors.white,
                              darkColor: AppTheme.primaryDark,
                              onTap: () async {
                                Navigator.pop(context);
                                await BattleService.acceptChallenge(widget.sessionId);
                                final navCtx = appNavigatorKey.currentContext;
                                if (navCtx == null || !navCtx.mounted) return;
                                Navigator.push(
                                  navCtx,
                                  MaterialPageRoute(
                                    builder: (_) => BattleScreen(
                                      sessionId: widget.sessionId,
                                      opponentId: _challengerId ?? '',
                                      opponentName: _challengerName ?? 'Contrincante',
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
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(_avatarUrl!),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.primaryLight.withValues(alpha: 0.4),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primary, width: 1.5),
      ),
      child: Center(
        child: Text(
          _challengerName != null && _challengerName!.isNotEmpty
              ? _challengerName![0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
