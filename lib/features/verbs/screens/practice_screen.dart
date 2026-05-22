import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/data/syllabus_data.dart';
import '../../../core/widgets/tactile_button.dart';
import '../../../core/widgets/squishy_progress_bar.dart';
import '../../../core/widgets/feedback_toast.dart';

class PracticeScreen extends StatefulWidget {
  final List<VerbModel> verbs;
  final String levelName;

  const PracticeScreen({
    super.key,
    required this.verbs,
    required this.levelName,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late List<Map<String, dynamic>> _questions;
  int _currentIndex = 0;
  int _score = 0;
  String? _selectedOption;
  bool _isAnswered = false;

  @override
  void initState() {
    super.initState();
    _generateQuiz();
  }

  void _generateQuiz() {
    final rand = Random();
    _questions = [];

    // Shuffle verbs to have random items
    final shuffledVerbs = List<VerbModel>.from(widget.verbs)..shuffle();
    final quizLength = min(5, shuffledVerbs.length);

    for (int i = 0; i < quizLength; i++) {
      final verb = shuffledVerbs[i];
      final type = rand.nextInt(3); // 0: Meaning, 1: Past Simple, 2: Fill in blank

      String questionText = '';
      String correctAnswer = '';
      List<String> options = [];

      if (type == 0) {
        questionText = '¿Cuál es el significado de "${verb.infinitive}"?';
        correctAnswer = verb.spanish;
        options.add(correctAnswer);

        // Fetch 3 decoy options
        final decoys = SyllabusData.verbs
            .where((v) => v.spanish != correctAnswer)
            .map((v) => v.spanish)
            .toList()
          ..shuffle();
        options.addAll(decoys.take(3));
      } else if (type == 1) {
        questionText = '¿Cuál es el pasado simple de "${verb.infinitive}"?';
        correctAnswer = verb.pastSimple;
        options.add(correctAnswer);

        final decoys = SyllabusData.verbs
            .where((v) => v.pastSimple != correctAnswer)
            .map((v) => v.pastSimple)
            .toList()
          ..shuffle();
        options.addAll(decoys.take(3));
      } else {
        // Example fill in blank
        final blankEn = verb.exampleEn.replaceAll(
          RegExp(
            '\\b(${verb.infinitive.replaceAll("to ", "")}|${verb.pastSimple}|${verb.pastParticiple}|${verb.gerund})\\b',
            caseSensitive: false,
          ),
          '_______',
        );
        questionText = 'Completa la frase:\n"$blankEn"\n\n(${verb.exampleEs})';
        
        // Find which exact form was replaced
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

        options.add(correctAnswer);
        final decoys = [
          verb.infinitive.replaceAll("to ", ""),
          verb.pastSimple,
          verb.pastParticiple,
          verb.gerund,
        ]..remove(correctAnswer);
        options.addAll(decoys);
      }

      options.shuffle();

      _questions.add({
        'question': questionText,
        'correct': correctAnswer,
        'options': options,
        'verb': verb,
      });
    }
  }

  void _verifyAnswer() {
    if (_selectedOption == null) return;

    final question = _questions[_currentIndex];
    final isCorrect = _selectedOption == question['correct'];

    setState(() {
      _isAnswered = true;
      if (isCorrect) {
        _score++;
        FeedbackToast.showSuccess(
          context,
          title: '¡Respuesta Correcta! 🌟',
          message: '¡Buen trabajo! Sigue así.',
        );
      } else {
        FeedbackToast.showError(
          context,
          title: 'Incorrecto ❌',
          message: 'La respuesta correcta era: ${question['correct']}',
        );
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
      _showResultDialog();
    }
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXLarge)),
        title: Text(
          '¡Práctica Completada! 🎉',
          textAlign: TextAlign.center,
          style: AppTheme.headlineMd.copyWith(color: AppTheme.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Tu puntuación fue:',
              style: AppTheme.bodyLg,
            ),
            const SizedBox(height: 8),
            Text(
              '$_score / ${_questions.length}',
              style: AppTheme.displayLg.copyWith(color: AppTheme.secondaryDark),
            ),
          ],
        ),
        actions: [
          Center(
            child: TactileButton(
              text: 'Finalizar',
              width: 160,
              onTap: () {
                Navigator.pop(dialogCtx); // Close dialog
                Navigator.pop(context); // Return to list
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final question = _questions[_currentIndex];
    final String questionText = question['question'];
    final List<String> options = List<String>.from(question['options']);
    final double progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.levelName,
          style: AppTheme.headlineMd.copyWith(fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.onBackground),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Progress indicator ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pregunta ${_currentIndex + 1} de ${_questions.length}',
                    style: AppTheme.labelLg.copyWith(color: AppTheme.onSurfaceVariant),
                  ),
                  Text(
                    'Aciertos: $_score',
                    style: AppTheme.labelLg.copyWith(color: AppTheme.tertiaryDark),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SquishyProgressBar(value: progress),
              const SizedBox(height: 32),

              // ── Question Box ───────────────────────────────────────────────
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
              const SizedBox(height: 32),

              // ── Answers Grid / Column ──────────────────────────────────────
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
                      bgCol = const Color(0xFFEAFAF1); // Soft green
                      textCol = AppTheme.tertiaryDark;
                    } else if (isSelected) {
                      borderCol = AppTheme.error;
                      bgCol = const Color(0xFFFFEBEA); // Soft red
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
              const SizedBox(height: 24),

              // ── Action Button ──────────────────────────────────────────────
              TactileButton(
                text: _isAnswered
                    ? (_currentIndex == _questions.length - 1 ? 'Ver resultados 🏆' : 'Siguiente')
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
          ),
        ),
      ),
    );
  }
}
