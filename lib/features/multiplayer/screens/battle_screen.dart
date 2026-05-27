import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/data/syllabus_data.dart';
import '../../../core/widgets/tactile_button.dart';
import '../../../core/widgets/squishy_progress_bar.dart';
import '../../../core/widgets/feedback_toast.dart';
import '../../../core/services/battle_service.dart';

class BattleScreen extends StatefulWidget {
  final String sessionId;
  final String opponentId;
  final String opponentName;

  const BattleScreen({
    super.key,
    required this.sessionId,
    required this.opponentId,
    required this.opponentName,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> with SingleTickerProviderStateMixin {
  // Game states
  bool _isLoading = true;
  int _wordSeed = 0;
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int _errors = 0;
  String? _selectedOption;
  bool _isAnswered = false;

  // Timers
  int _timeLeft = 45; // 45 seconds total for the battle
  Timer? _gameTimer;
  DateTime? _startTime;
  int _timeTakenMs = 0;

  // Post-game states
  bool _hasFinishedSelf = false;
  bool _hasFinishedOpponent = false;
  Map<String, dynamic>? _myResult;
  Map<String, dynamic>? _opponentResult;
  String? _winnerId;
  bool _resolvingWinner = false;
  
  // Realtime channel for observing opponent finish
  RealtimeChannel? _resultsChannel;
  Timer? _pollingTimer;

  // Micro-animation controllers
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _loadSessionAndStart();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _pollingTimer?.cancel();
    _resultsChannel?.unsubscribe();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionAndStart() async {
    final session = await BattleService.getSession(widget.sessionId);
    if (!mounted) return;
    
    if (session != null) {
      _wordSeed = session['word_seed'] as int? ?? 0;
    } else {
      _wordSeed = Random().nextInt(999999);
    }
    
    _generateQuiz();
    _startTime = DateTime.now();
    _startTimer();
    
    setState(() {
      _isLoading = false;
    });
  }

  void _generateQuiz() {
    final rand = Random(_wordSeed);
    _questions = [];

    // Filter to obtain basic and intermediate verbs for fair duels
    final pool = SyllabusData.verbs;
    
    // Seeded shuffle of the pool
    final shuffledPool = List<VerbModel>.from(pool);
    final tempPool = <VerbModel>[];
    final copyPool = List<VerbModel>.from(shuffledPool);
    while (copyPool.isNotEmpty) {
      final idx = rand.nextInt(copyPool.length);
      tempPool.add(copyPool.removeAt(idx));
    }

    final quizLength = min(10, tempPool.length);

    for (int i = 0; i < quizLength; i++) {
      final verb = tempPool[i];
      final type = rand.nextInt(3); // 0: Meaning, 1: Past Simple, 2: Fill in blank

      String questionText = '';
      String correctAnswer = '';
      List<String> options = [];

      if (type == 0) {
        questionText = '¿Cuál es el significado de "${verb.infinitive}"?';
        correctAnswer = verb.spanish;
        final uniqueOptions = <String>{correctAnswer};

        final decoys = pool
            .where((v) => v.spanish != correctAnswer)
            .map((v) => v.spanish)
            .toList()
          ..shuffle();
        
        for (final decoy in decoys) {
          if (uniqueOptions.length >= 4) break;
          uniqueOptions.add(decoy);
        }

        while (uniqueOptions.length < 4) {
          final fallbackDecoy = SyllabusData.verbs[rand.nextInt(SyllabusData.verbs.length)].spanish;
          uniqueOptions.add(fallbackDecoy);
        }
        options = uniqueOptions.toList();
      } else if (type == 1) {
        questionText = '¿Cuál es el pasado simple de "${verb.infinitive}"?';
        correctAnswer = verb.pastSimple;
        final uniqueOptions = <String>{correctAnswer};

        final decoys = pool
            .where((v) => v.pastSimple != correctAnswer)
            .map((v) => v.pastSimple)
            .toList()
          ..shuffle();
        
        for (final decoy in decoys) {
          if (uniqueOptions.length >= 4) break;
          uniqueOptions.add(decoy);
        }

        while (uniqueOptions.length < 4) {
          final fallbackDecoy = SyllabusData.verbs[rand.nextInt(SyllabusData.verbs.length)].pastSimple;
          uniqueOptions.add(fallbackDecoy);
        }
        options = uniqueOptions.toList();
      } else {
        // Fill in the blank
        final blankEn = verb.exampleEn.replaceAll(
          RegExp(
            '\\b(${verb.infinitive.replaceAll("to ", "")}|${verb.pastSimple}|${verb.pastParticiple}|${verb.gerund})\\b',
            caseSensitive: false,
          ),
          '_______',
        );
        questionText = 'Completa la frase:\n"$blankEn"\n\n(${verb.exampleEs})';
        
        final parts = verb.exampleEn.toLowerCase().split(' ');
        final base = verb.infinitive.replaceAll("to ", "").toLowerCase();
        
        if (parts.contains(verb.pastSimple.toLowerCase())) {
          correctAnswer = verb.pastSimple;
        } else if (parts.contains(verb.pastParticiple.toLowerCase())) {
          correctAnswer = verb.pastParticiple;
        } else if (parts.contains(verb.gerund.toLowerCase())) {
          correctAnswer = verb.gerund;
        } else {
          correctAnswer = base;
        }

        final uniqueOptions = <String>{correctAnswer};
        final decoys = [
          verb.infinitive.replaceAll("to ", ""),
          verb.pastSimple,
          verb.pastParticiple,
          verb.gerund,
        ]..remove(correctAnswer);

        for (final decoy in decoys) {
          if (uniqueOptions.length >= 4) break;
          uniqueOptions.add(decoy);
        }

        while (uniqueOptions.length < 4) {
          final randomVerb = SyllabusData.verbs[rand.nextInt(SyllabusData.verbs.length)];
          final formIndex = rand.nextInt(4);
          String fallbackDecoy;
          if (formIndex == 0) {
            fallbackDecoy = randomVerb.infinitive.replaceAll("to ", "");
          } else if (formIndex == 1) {
            fallbackDecoy = randomVerb.pastSimple;
          } else if (formIndex == 2) {
            fallbackDecoy = randomVerb.pastParticiple;
          } else {
            fallbackDecoy = randomVerb.gerund;
          }
          uniqueOptions.add(fallbackDecoy);
        }
        options = uniqueOptions.toList();
      }

      // Seeded shuffle of options
      final shuffledOptions = <String>[];
      final copyOptions = List<String>.from(options);
      while (copyOptions.isNotEmpty) {
        final idx = rand.nextInt(copyOptions.length);
        shuffledOptions.add(copyOptions.removeAt(idx));
      }

      _questions.add({
        'question': questionText,
        'correct': correctAnswer,
        'options': shuffledOptions,
        'verb': verb,
      });
    }
  }

  void _startTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
          if (_timeLeft == 5) {
            // Heartbeat vibration alert or subtle chime could be played
          }
        } else {
          _gameTimer?.cancel();
          _onTimeOut();
        }
      });
    });
  }

  void _onTimeOut() {
    FeedbackToast.showError(
      context,
      title: '¡Tiempo agotado! ⏰',
      message: 'La ronda ha finalizado automáticamente.',
    );
    _currentIndex = _questions.length; // Force finish
    _finishGame();
  }

  void _verifyAnswer() {
    if (_selectedOption == null) return;

    final question = _questions[_currentIndex];
    final isCorrect = _selectedOption == question['correct'];

    setState(() {
      _isAnswered = true;
      if (isCorrect) {
        _score++;
      } else {
        _errors++;
      }
    });
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _isAnswered = false;
      });
    } else {
      _finishGame();
    }
  }

  Future<void> _finishGame() async {
    _gameTimer?.cancel();
    if (_startTime != null) {
      _timeTakenMs = DateTime.now().difference(_startTime!).inMilliseconds;
    }
    
    setState(() {
      _hasFinishedSelf = true;
      _isLoading = true;
    });

    // Upload individual result to battle_results
    await BattleService.submitResult(
      sessionId: widget.sessionId,
      score: _score,
      errors: _errors,
      timeTakenMs: _timeTakenMs,
    );

    // Fetch both results to see if the opponent has already finished
    await _checkOpponentStatus();

    if (!_hasFinishedOpponent) {
      // Set up realtime listener and periodic polling fallback
      _setupRealtimeResults();
      _startResultsPolling();
    }
  }

  Future<void> _checkOpponentStatus() async {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;

    final session = await BattleService.getSession(widget.sessionId);
    if (!mounted) return;

    if (session != null) {
      final status = session['status'] as String?;
      final startedAtStr = session['started_at'] as String?;

      // 1. Explicit abandonment check
      if (status == 'abandoned') {
        _pollingTimer?.cancel();
        _resultsChannel?.unsubscribe();
        setState(() {
          _isLoading = false;
          _opponentResult = {
            'score': 0,
            'errors': 10,
            'time_taken_ms': 45000,
            'completed_at': DateTime.now().toIso8601String(),
            'abandoned': true,
          };
          _winnerId = myId;
          _hasFinishedOpponent = true;
        });
        if (mounted) {
          FeedbackToast.showWarning(
            context,
            title: '¡Victoria por abandono! 🏳️',
            message: 'El oponente ha abandonado la batalla.',
          );
        }
        await BattleService.recordMyOutcome('win');
        return;
      }

      // 2. Absolute time limit check (55 seconds max since game start)
      if (startedAtStr != null) {
        final startedAt = DateTime.tryParse(startedAtStr);
        if (startedAt != null) {
          final elapsed = DateTime.now().difference(startedAt);
          if (elapsed.inSeconds > 55) {
            _pollingTimer?.cancel();
            _resultsChannel?.unsubscribe();
            setState(() {
              _isLoading = false;
              _opponentResult = {
                'score': 0,
                'errors': 10,
                'time_taken_ms': 45000,
                'completed_at': DateTime.now().toIso8601String(),
                'timeout': true,
              };
              _winnerId = myId;
              _hasFinishedOpponent = true;
            });
            if (mounted) {
              FeedbackToast.showWarning(
                context,
                title: 'Límite de tiempo superado ⏰',
                message: 'El oponente ha tardado demasiado o se desconectó. ¡Victoria por defecto!',
              );
            }
            await BattleService.recordMyOutcome('win');
            return;
          }
        }
      }
    }

    final results = await BattleService.getResults(widget.sessionId);
    if (!mounted) return;

    final mine = results.firstWhere((r) => r['user_id'] == myId, orElse: () => {});
    final theirs = results.firstWhere((r) => r['user_id'] == widget.opponentId, orElse: () => {});

    setState(() {
      if (mine.isNotEmpty) _myResult = mine;
      if (theirs.isNotEmpty) {
        _opponentResult = theirs;
        _hasFinishedOpponent = true;
        _isLoading = false;
      }
    });

    if (_hasFinishedOpponent) {
      _pollingTimer?.cancel();
      _resultsChannel?.unsubscribe();
      _resolveAndShowWinner();
    }
  }

  void _setupRealtimeResults() {
    _resultsChannel = Supabase.instance.client
        .channel('results-${widget.sessionId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'battle_results',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: widget.sessionId,
          ),
          callback: (payload) {
            _checkOpponentStatus();
          },
        )
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
            _checkOpponentStatus();
          },
        )
        .subscribe();
  }

  void _startResultsPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkOpponentStatus();
    });
  }

  Future<void> _resolveAndShowWinner() async {
    if (_resolvingWinner) return;
    _resolvingWinner = true;

    final winner = await BattleService.resolveWinner(widget.sessionId);
    if (!mounted) return;

    setState(() {
      _winnerId = winner;
      _isLoading = false;
    });

    // Record personal stats based on final outcome
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (_winnerId == null) {
      await BattleService.recordMyOutcome('tie');
    } else if (_winnerId == myId) {
      await BattleService.recordMyOutcome('win');
    } else {
      await BattleService.recordMyOutcome('loss');
    }
  }

  Future<void> _abandonGame() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusExtraLarge),
          side: const BorderSide(color: AppTheme.outline, width: 1.5),
        ),
        title: Text('¿Abandonar batalla? 🏳️', style: AppTheme.headlineMd.copyWith(fontSize: 18)),
        content: Text(
          'Si abandonas ahora, se registrará una derrota y se cancelará la partida para ambos.',
          style: AppTheme.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Seguir luchando', style: AppTheme.labelLg.copyWith(color: AppTheme.primary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Abandonar', style: AppTheme.labelLg.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await BattleService.recordAbandon(widget.sessionId);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rotating squircle 3D key indicator
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.08),
                    child: child,
                  );
                },
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(color: AppTheme.primary, width: 2),
                  ),
                  child: const Center(
                    child: Text('⚔️', style: TextStyle(fontSize: 48)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _hasFinishedSelf ? 'Esperando rival...' : 'Preparando campo de batalla...',
                style: AppTheme.headlineMd.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _hasFinishedSelf
                      ? 'Has terminado tu ronda con $_score aciertos. Esperemos a que ${widget.opponentName} complete sus preguntas.'
                      : 'Cargando preguntas sincronizadas de verbos...',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3),
              ),
              if (_hasFinishedSelf) ...[
                const SizedBox(height: 48),
                SizedBox(
                  width: 160,
                  child: TactileButton(
                    text: 'Abandonar',
                    backgroundColor: Colors.white,
                    textColor: AppTheme.error,
                    darkColor: AppTheme.surfaceContainer,
                    isSecondary: true,
                    onTap: _abandonGame,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_winnerId != null || _hasFinishedOpponent) {
      return _buildResolutionScreen();
    }

    // Standard playing screen
    final question = _questions[_currentIndex];
    final String questionText = question['question'];
    final List<String> options = List<String>.from(question['options']);
    final double progress = (_currentIndex + 1) / _questions.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _abandonGame();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            'Duelo de Verbos ⚔️',
            style: AppTheme.headlineMd.copyWith(fontSize: 18),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.onBackground),
            onPressed: _abandonGame,
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _timeLeft <= 10 ? const Color(0xFFFFECEF) : AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                border: Border.all(
                  color: _timeLeft <= 10 ? AppTheme.error : AppTheme.outline.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: _timeLeft <= 10 ? AppTheme.error : AppTheme.onBackground,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_timeLeft s',
                    style: AppTheme.labelLg.copyWith(
                      color: _timeLeft <= 10 ? AppTheme.error : AppTheme.onBackground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                // Realtime user status tracker
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pregunta ${_currentIndex + 1} de ${_questions.length}',
                      style: AppTheme.labelLg.copyWith(color: AppTheme.onSurfaceVariant),
                    ),
                    Text(
                      'Tus Aciertos: $_score',
                      style: AppTheme.labelLg.copyWith(color: AppTheme.tertiaryDark),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SquishyProgressBar(value: progress),
                const SizedBox(height: 24),

                // Question card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(color: AppTheme.surfaceContainer, width: 1.5),
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Text(
                          questionText,
                          textAlign: TextAlign.center,
                          style: AppTheme.headlineMd.copyWith(fontSize: 22, height: 1.4),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Distractor buttons
                Column(
                  children: options.map((option) {
                    final isSelected = _selectedOption == option;
                    final isCorrect = option == question['correct'];

                    Color borderCol = AppTheme.outline.withValues(alpha: 0.5);
                    Color bgCol = AppTheme.surface;
                    Color textCol = AppTheme.onBackground;

                    if (isSelected) {
                      borderCol = AppTheme.primary;
                      bgCol = const Color(0xFFE8EFFF);
                      textCol = AppTheme.primary;
                    }

                    if (_isAnswered) {
                      if (isCorrect) {
                        borderCol = AppTheme.tertiary;
                        bgCol = const Color(0xFFEAFAF1);
                        textCol = AppTheme.tertiaryDark;
                      } else if (isSelected) {
                        borderCol = AppTheme.error;
                        bgCol = const Color(0xFFFFEBEA);
                        textCol = AppTheme.error;
                      }
                    }

                    return GestureDetector(
                      onTap: _isAnswered
                          ? null
                          : () => setState(() => _selectedOption = option),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: bgCol,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(color: borderCol, width: 2),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isAnswered && isCorrect
                                  ? Icons.check_circle_rounded
                                  : _isAnswered && isSelected
                                      ? Icons.cancel_rounded
                                      : isSelected
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded,
                              color: _isAnswered && isCorrect
                                  ? AppTheme.tertiary
                                  : _isAnswered && isSelected
                                      ? AppTheme.error
                                      : isSelected
                                          ? AppTheme.primary
                                          : AppTheme.outline,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                option,
                                style: AppTheme.labelLg.copyWith(
                                  fontSize: 16,
                                  color: textCol,
                                  fontWeight: isSelected || (_isAnswered && isCorrect)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Chunky Depress Action button
                TactileButton(
                  text: _isAnswered
                      ? (_currentIndex == _questions.length - 1 ? 'Enviar Resultados 🏆' : 'Siguiente')
                      : 'Comprobar',
                  onTap: _selectedOption == null
                      ? null
                      : _isAnswered
                          ? _next
                          : _verifyAnswer,
                  backgroundColor: _isAnswered ? AppTheme.primary : AppTheme.secondary,
                  darkColor: _isAnswered ? AppTheme.primaryDark : AppTheme.secondaryDark,
                  textColor: _isAnswered ? Colors.white : AppTheme.onBackground,
                ),
              ],
            ), // Column
          ), // Padding
        ), // ConstrainedBox
      ), // Center
    ), // SafeArea
  ), // Scaffold
); // PopScope
}

  Widget _buildResolutionScreen() {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isWinner = _winnerId == myId;
    final isTie = _winnerId == null;

    final myScore = _myResult?['score'] as int? ?? _score;
    final opponentScore = _opponentResult?['score'] as int? ?? 0;
    
    final myTimeS = ((_myResult?['time_taken_ms'] as int? ?? _timeTakenMs) / 1000).toStringAsFixed(1);
    final opponentTimeS = ((_opponentResult?['time_taken_ms'] as int? ?? 30000) / 1000).toStringAsFixed(1);

    String outcomeTitle = '¡EMPATE! 🤝';
    String outcomeSubtitle = '¡Estuvo reñido! Ambos jugaron con una velocidad y precisión increíbles.';
    Color outcomeColor = AppTheme.primary;
    String badgeEmoji = '🤝';
    Color badgeBg = const Color(0xFFE8EFFF);

    if (!isTie) {
      if (isWinner) {
        outcomeTitle = '¡VICTORIA! 🏆';
        outcomeSubtitle = '¡Increíble! Dominas los verbos en inglés a la perfección.';
        outcomeColor = AppTheme.tertiary;
        badgeEmoji = '🏆';
        badgeBg = const Color(0xFFEAFAF1);
      } else {
        outcomeTitle = '¡DERROTA! 🛡️';
        outcomeSubtitle = '¡No te rindas! Cada error es una oportunidad para aprender y mejorar.';
        outcomeColor = AppTheme.error;
        badgeEmoji = '🛡️';
        badgeBg = const Color(0xFFFFECEF);
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const SizedBox(height: 24),
              // Stunning outcome badge
              Center(
                child: Container(
                  height: 130,
                  width: 130,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: outcomeColor, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      badgeEmoji,
                      style: const TextStyle(fontSize: 64),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              
              Text(
                outcomeTitle,
                textAlign: TextAlign.center,
                style: AppTheme.displayLg.copyWith(fontSize: 32, color: outcomeColor),
              ),
              const SizedBox(height: 12),
              Text(
                outcomeSubtitle,
                textAlign: TextAlign.center,
                style: AppTheme.bodyLg.copyWith(color: AppTheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 36),

              // Duel stats comparator card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(color: AppTheme.surfaceContainer, width: 1.5),
                ),
                child: Column(
                  children: [
                    Text(
                      'Estadísticas del Combate',
                      style: AppTheme.labelLg.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    
                    // Header row
                    Row(
                      children: [
                        const Expanded(child: SizedBox.shrink()),
                        Expanded(
                          child: Text(
                            'Tú 👤',
                            textAlign: TextAlign.center,
                            style: AppTheme.labelLg.copyWith(color: AppTheme.primary),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${widget.opponentName} ⚔️',
                            textAlign: TextAlign.center,
                            style: AppTheme.labelLg.copyWith(color: AppTheme.error),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: AppTheme.surfaceContainer),
                    
                    // Score row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Puntuación',
                            style: AppTheme.bodyMd.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$myScore / 10',
                            textAlign: TextAlign.center,
                            style: AppTheme.headlineMd.copyWith(fontSize: 18, color: outcomeColor),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$opponentScore / 10',
                            textAlign: TextAlign.center,
                            style: AppTheme.headlineMd.copyWith(fontSize: 18, color: AppTheme.onBackground),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    
                    // Time taken row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tiempo total',
                            style: AppTheme.bodyMd.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${myTimeS}s',
                            textAlign: TextAlign.center,
                            style: AppTheme.labelLg.copyWith(fontSize: 15),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${opponentTimeS}s',
                            textAlign: TextAlign.center,
                            style: AppTheme.labelLg.copyWith(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Complete action return button
              TactileButton(
                text: 'Volver al Mapa',
                backgroundColor: AppTheme.primary,
                textColor: Colors.white,
                darkColor: AppTheme.primaryDark,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}
