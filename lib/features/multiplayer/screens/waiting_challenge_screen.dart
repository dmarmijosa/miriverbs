import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tactile_button.dart';
import 'battle_screen.dart';
import '../../../core/services/battle_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WaitingPulse extends StatefulWidget {
  final String status;
  const WaitingPulse({super.key, required this.status});

  @override
  State<WaitingPulse> createState() => _WaitingPulseState();
}

class _WaitingPulseState extends State<WaitingPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.95, end: 1.15).animate(
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
    final isAway = widget.status == 'away';
    final isOffline = widget.status == 'offline';
    final glowColor = isOffline
        ? Colors.grey[400]!
        : (isAway ? Colors.amber[600]! : AppTheme.primary);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer glowing pulsing ring
            Container(
              height: 140 * _pulse.value,
              width: 140 * _pulse.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glowColor.withValues(alpha: 0.08),
                border: Border.all(
                  color: glowColor.withValues(alpha: 0.18),
                  width: 2,
                ),
              ),
            ),
            // Middle ring
            Container(
              height: 110,
              width: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glowColor.withValues(alpha: 0.12),
                border: Border.all(
                  color: glowColor.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
            ),
            // Core
            Container(
              height: 86,
              width: 86,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.22),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Text('⚔️', style: TextStyle(fontSize: 42)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class WaitingChallengeScreen extends StatefulWidget {
  final String sessionId;
  final String opponentId;
  final String opponentName;

  const WaitingChallengeScreen({
    super.key,
    required this.sessionId,
    required this.opponentId,
    required this.opponentName,
  });

  @override
  State<WaitingChallengeScreen> createState() => _WaitingChallengeScreenState();
}

class _WaitingChallengeScreenState extends State<WaitingChallengeScreen>
    with WidgetsBindingObserver {
  bool _showCancel = false;
  bool _rejected = false;
  bool _navigated = false;
  Timer? _cancelTimer;
  RealtimeChannel? _channel;
  RealtimeChannel? _presenceChannel;

  String _opponentStatus = 'offline';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Show cancel button after 5 seconds to avoid locking screen
    _cancelTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showCancel = true);
    });

    _channel = _subscribeToSession();
    _fetchOpponentDetails();
    _subscribeToOpponentPresence();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_navigated && !_rejected) {
      _checkSessionStatus();
      _fetchOpponentPresence();
    }
  }

  Future<void> _fetchOpponentDetails() async {
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('avatar_url')
          .eq('id', widget.opponentId)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          _avatarUrl = res['avatar_url'] as String?;
        });
      }
    } catch (_) {}
    await _fetchOpponentPresence();
  }

  Future<void> _fetchOpponentPresence() async {
    try {
      final res = await Supabase.instance.client
          .from('user_presences')
          .select('presence_status, last_seen')
          .eq('user_id', widget.opponentId)
          .maybeSingle();

      if (res != null && mounted) {
        final lastSeenStr = res['last_seen'] as String?;
        var status = res['presence_status'] as String? ?? 'offline';

        if (lastSeenStr != null) {
          final lastSeen = DateTime.tryParse(lastSeenStr);
          if (lastSeen == null || DateTime.now().difference(lastSeen).inMinutes >= 2) {
            status = 'offline';
          }
        }
        setState(() {
          _opponentStatus = status;
        });
      }
    } catch (_) {}
  }

  void _subscribeToOpponentPresence() {
    _presenceChannel = Supabase.instance.client
        .channel('opponent-presence-${widget.opponentId}');

    _presenceChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_presences',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: widget.opponentId,
      ),
      callback: (payload) {
        if (!mounted) return;
        final rec = payload.newRecord;
        if (rec.isNotEmpty) {
          final lastSeenStr = rec['last_seen'] as String?;
          var status = rec['presence_status'] as String? ?? 'offline';
          if (lastSeenStr != null) {
            final lastSeen = DateTime.tryParse(lastSeenStr);
            if (lastSeen == null || DateTime.now().difference(lastSeen).inMinutes >= 2) {
              status = 'offline';
            }
          }
          setState(() {
            _opponentStatus = status;
          });
        }
      },
    ).subscribe();
  }

  Future<void> _checkSessionStatus() async {
    final session = await BattleService.getSession(widget.sessionId);
    if (!mounted || session == null) return;

    final status = session['status'] as String?;
    if (status == 'active' && !_navigated) {
      _navigated = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BattleScreen(
            sessionId: widget.sessionId,
            opponentId: widget.opponentId,
            opponentName: widget.opponentName,
          ),
        ),
      );
    } else if (status == 'cancelled') {
      setState(() => _rejected = true);
    }
  }

  RealtimeChannel _subscribeToSession() {
    final channel = Supabase.instance.client
        .channel('waiting-${widget.sessionId}');
    channel
        .onPostgresChanges(
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
            if (status == 'active' && !_navigated) {
              _navigated = true;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BattleScreen(
                    sessionId: widget.sessionId,
                    opponentId: widget.opponentId,
                    opponentName: widget.opponentName,
                  ),
                ),
              );
            } else if (status == 'cancelled') {
              setState(() => _rejected = true);
            }
          },
        )
        .subscribe();
    return channel;
  }

  Future<void> _cancelChallenge() async {
    await BattleService.cancelSession(widget.sessionId);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimer?.cancel();
    _channel?.unsubscribe();
    _presenceChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
                side: const BorderSide(color: AppTheme.outline, width: 1.5),
              ),
              title: Text(
                '¿Cancelar reto?',
                style: AppTheme.headlineMd.copyWith(fontSize: 18),
              ),
              content: Text(
                '¿Estás seguro de que quieres cancelar el reto enviado a ${widget.opponentName}?',
                style: AppTheme.bodyMd,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'No, esperar',
                    style: AppTheme.labelLg.copyWith(color: AppTheme.onSurfaceVariant),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    'Sí, cancelar',
                    style: AppTheme.labelLg.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
          if (confirm == true) _cancelChallenge();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primary.withValues(alpha: 0.06),
                AppTheme.background,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: _rejected ? _buildRejected() : _buildWaiting(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaiting() {
    final isAway = _opponentStatus == 'away';
    final isOffline = _opponentStatus == 'offline';
    
    final statusColor = isOffline
        ? Colors.grey
        : (isAway ? Colors.amber[800]! : AppTheme.success);
    
    final statusText = isOffline
        ? 'Fuera de línea (Le llegará Push)'
        : (isAway ? 'Ausente' : 'En línea');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WaitingPulse(status: _opponentStatus),
        const SizedBox(height: 40),
        Text(
          'Desafiando rival...',
          style: AppTheme.displayLg.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        
        // High fidelity glassmorphic card for opponent status
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15), width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildOpponentAvatar(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.opponentName,
                              style: AppTheme.labelLg.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppTheme.surfaceContainer, height: 1),
                  const SizedBox(height: 12),
                  Text(
                    'Esperando a que acepte el combate de verbos en tiempo real...',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMd.copyWith(
                      color: AppTheme.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 48),
        if (_showCancel)
          SizedBox(
            width: 220,
            child: TactileButton(
              text: 'Cancelar reto',
              backgroundColor: Colors.white,
              textColor: AppTheme.error,
              darkColor: AppTheme.surfaceContainer,
              isSecondary: true,
              onTap: _cancelChallenge,
            ),
          ),
      ],
    );
  }

  Widget _buildOpponentAvatar() {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(_avatarUrl!),
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primaryLight.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primary, width: 1.5),
      ),
      child: Center(
        child: Text(
          widget.opponentName.isNotEmpty ? widget.opponentName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildRejected() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 110,
          width: 110,
          decoration: BoxDecoration(
            color: const Color(0xFFFFECEF),
            borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
            border: Border.all(color: AppTheme.error, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.error.withValues(alpha: 0.12),
                blurRadius: 16,
                spreadRadius: 2,
              )
            ],
          ),
          child: const Center(
            child: Text('❌', style: TextStyle(fontSize: 48)),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Reto rechazado',
          style: AppTheme.displayLg.copyWith(
            fontSize: 28,
            color: AppTheme.error,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${widget.opponentName} ha declinado o cancelado el desafío por esta vez.',
          textAlign: TextAlign.center,
          style: AppTheme.bodyLg.copyWith(color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: 180,
          child: TactileButton(
            text: 'Volver',
            backgroundColor: AppTheme.primary,
            textColor: Colors.white,
            darkColor: AppTheme.primaryDark,
            onTap: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }
}
