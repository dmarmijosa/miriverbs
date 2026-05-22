import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tactile_button.dart';
import 'battle_screen.dart';
import '../../../core/services/battle_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Show cancel button after 5 seconds to avoid locking screen
    _cancelTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showCancel = true);
    });
    
    _channel = _subscribeToSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_navigated && !_rejected) {
      _checkSessionStatus();
    }
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
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _rejected ? _buildRejected() : _buildWaiting(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaiting() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Squishy Battle Icon carrier
        Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFAD6),
            borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
            border: Border.all(color: AppTheme.secondary, width: 2),
          ),
          child: const Center(
            child: Text('⚔️', style: TextStyle(fontSize: 52)),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Esperando rival...',
          style: AppTheme.displayLg.copyWith(fontSize: 26),
        ),
        const SizedBox(height: 12),
        Text(
          'Enviamos un desafío de verbo a ${widget.opponentName}. Esperemos a que acepte el duelo.',
          textAlign: TextAlign.center,
          style: AppTheme.bodyLg.copyWith(color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 48),
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            color: AppTheme.primary,
            strokeWidth: 4,
          ),
        ),
        const SizedBox(height: 48),
        if (_showCancel)
          SizedBox(
            width: 200,
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

  Widget _buildRejected() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFFFECEF),
            borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
            border: Border.all(color: AppTheme.error, width: 2),
          ),
          child: const Center(
            child: Text('❌', style: TextStyle(fontSize: 52)),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Reto rechazado',
          style: AppTheme.displayLg.copyWith(fontSize: 26, color: AppTheme.error),
        ),
        const SizedBox(height: 12),
        Text(
          '${widget.opponentName} ha declinado o cancelado el desafío por esta vez.',
          textAlign: TextAlign.center,
          style: AppTheme.bodyLg.copyWith(color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: 160,
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
