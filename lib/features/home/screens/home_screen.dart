import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/squishy_progress_bar.dart';
import '../../../core/widgets/feedback_toast.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/progress_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../verbs/screens/verbs_list_screen.dart';
import 'presentation_video_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _completedProgress = [];



  final List<Map<String, dynamic>> _units = [
    {
      'title': 'Unidad 1: Básico Principiante A1',
      'desc': 'Verbos de uso diario (to be, to have, to do, to go...)',
      'level': 'a1',
      'verbsCount': 60,
      'color': AppTheme.primary,
      'icon': Icons.star_rounded,
    },
    {
      'title': 'Unidad 2: Básico Elemental A2',
      'desc': 'Verbos cotidianos (to speak, to learn, to buy, to choose...)',
      'level': 'a2',
      'verbsCount': 60,
      'color': AppTheme.secondary,
      'icon': Icons.bolt_rounded,
    },
    {
      'title': 'Unidad 3: Intermedio B1',
      'desc': 'Verbos de comunicación general (to build, to spend, to agree...)',
      'level': 'b1',
      'verbsCount': 60,
      'color': AppTheme.tertiary,
      'icon': Icons.emoji_events_rounded,
    },
    {
      'title': 'Unidad 4: Intermedio Alto B2',
      'desc': 'Verbos de fluidez y precisión (to achieve, to establish, to reduce...)',
      'level': 'b2',
      'verbsCount': 60,
      'color': const Color(0xFF9B59B6),
      'icon': Icons.insights_rounded,
    },
    {
      'title': 'Unidad 5: Avanzado C1',
      'desc': 'Verbos profesionales y académicos (to foster, to leverage, to tackle...)',
      'level': 'c1',
      'verbsCount': 60,
      'color': AppTheme.error,
      'icon': Icons.diamond_rounded,
    },
    {
      'title': 'Unidad 6: Experto C2',
      'desc': 'Verbos de maestría y retórica (to excel, to elucidate, to corroborate...)',
      'level': 'c2',
      'verbsCount': 60,
      'color': const Color(0xFFE67E22),
      'icon': Icons.workspace_premium_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await AuthService.getProfile();
    final progress = await ProgressService.fetchSublevelProgress();
    if (mounted) {
      setState(() {
        _profile = data;
        _completedProgress = progress;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) {
      FeedbackToast.showSuccess(
        context,
        title: 'Cerrar sesión',
        message: 'Has cerrado sesión con éxito.',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _showAvatarPicker(BuildContext context) {
    final avatars = [
      {'name': 'Miri Feliz', 'path': 'assets/images/mascot_happy.png'},
      {'name': 'Miri Celebrando', 'path': 'assets/images/mascot_celebrating.png'},
      {'name': 'Miri Triste', 'path': 'assets/images/mascot_sad.png'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.outline.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Elige tu Avatar 🦉',
                  style: AppTheme.headlineMd.copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecciona uno de los avatares oficiales para tu perfil',
                  style: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: avatars.map((avatar) {
                    final isSelected = _profile?['avatar_url'] == avatar['path'];
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        FeedbackToast.showSuccess(
                          context,
                          title: 'Actualizando avatar',
                          message: 'Guardando tu nuevo avatar...',
                        );
                        final success = await AuthService.updateAvatar(avatar['path']!);
                        if (success) {
                          await _loadProfile();
                        } else {
                          if (context.mounted) {
                            FeedbackToast.showError(
                              context,
                              title: 'Error',
                              message: 'No se pudo actualizar el avatar.',
                            );
                          }
                        }
                      },
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? AppTheme.primary : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: const Color(0xFFE8EFFF),
                              backgroundImage: AssetImage(avatar['path']!),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            avatar['name']!,
                            style: AppTheme.labelLg.copyWith(
                              color: isSelected ? AppTheme.primary : AppTheme.onBackground,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = _profile?['full_name'] ?? AuthService.currentUser?.email?.split('@').first ?? 'Estudiante';
    final String avatarUrl = _profile?['avatar_url'] ?? '';

    // Calculate dynamic streak and goals progress
    final int streakDays = _profile?['streak_days'] ?? 0;
    final String lastPracticeDateStr = _profile?['last_practice_date']?.toString() ?? '';
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final hasPracticedToday = lastPracticeDateStr == todayStr;

    final String streakText = streakDays == 1 ? '1 día de racha' : '$streakDays días de racha';
    final String subText = hasPracticedToday 
        ? '¡Racha asegurada por hoy! Sigue así mañana.'
        : 'Completa cualquier subnivel hoy para mantener tu racha.';
    final double streakProgress = hasPracticedToday ? 1.0 : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header Profile Area ────────────────────────────────────
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showAvatarPicker(context),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: const Color(0xFFE8EFFF),
                              backgroundImage: avatarUrl.isNotEmpty
                                  ? (avatarUrl.startsWith('http')
                                      ? NetworkImage(avatarUrl)
                                      : AssetImage(avatarUrl) as ImageProvider)
                                  : const AssetImage('assets/images/mascot_happy.png') as ImageProvider,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hola, $name 👋',
                              style: AppTheme.headlineMd.copyWith(fontSize: 20),
                            ),
                            Text(
                              '¿Listo para practicar hoy?',
                              style: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded, color: AppTheme.error),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Daily Goals Progress Card ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(color: AppTheme.surfaceContainer, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Racha de estudio 🔥',
                              style: AppTheme.labelLg.copyWith(fontSize: 16),
                            ),
                            Text(
                              streakText,
                              style: AppTheme.labelLg.copyWith(color: AppTheme.secondaryDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SquishyProgressBar(value: streakProgress),
                        const SizedBox(height: 12),
                        Text(
                          subText,
                          style: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Presentation Video Card ────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(color: AppTheme.surfaceContainer, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        onTap: _showVideoPresentationScreen,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFECEB),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_circle_filled_rounded,
                                  color: Color(0xFFEA4335),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Conoce Miriverbs 🎥',
                                      style: AppTheme.labelLg.copyWith(fontSize: 15),
                                    ),
                                    Text(
                                      'Ver video de presentación del método',
                                      style: AppTheme.bodyMd.copyWith(
                                        color: AppTheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: AppTheme.outline,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Tu Ruta de Aprendizaje',
                    style: AppTheme.headlineMd.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 16),

                  // ── Learning units list ────────────────────────────────────
                  ..._units.map((unit) {
                    final String levelCode = unit['level'];
                    final Color color = unit['color'];

                    // Check if level is unlocked
                    final bool isUnlocked = ProgressService.isLevelUnlocked(
                      levelCode: levelCode,
                      completedSublevels: _completedProgress,
                    );

                    // Dynamically compute progress
                    final double progress = ProgressService.getLevelCompletionPercentage(
                      levelCode: levelCode,
                      completedSublevels: _completedProgress,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        side: const BorderSide(color: AppTheme.surfaceContainer, width: 1.5),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        onTap: isUnlocked
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => VerbsListScreen(
                                      title: unit['title'],
                                      levelCode: levelCode,
                                    ),
                                  ),
                                ).then((_) {
                                  // Reload progress and profile when returning
                                  _loadProfile();
                                });
                              }
                            : () {
                                FeedbackToast.showWarning(
                                  context,
                                  title: 'Nivel Bloqueado 🔒',
                                  message: 'Completa la unidad anterior al 100% para desbloquear esta unidad.',
                                );
                              },
                        child: Opacity(
                          opacity: isUnlocked ? 1.0 : 0.6,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                // Icon badge
                                Container(
                                  height: 52,
                                  width: 52,
                                  decoration: BoxDecoration(
                                    color: isUnlocked
                                        ? color.withValues(alpha: 0.12)
                                        : AppTheme.outline.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isUnlocked ? unit['icon'] : Icons.lock_rounded,
                                    color: isUnlocked ? color : AppTheme.outline,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        unit['title'],
                                        style: AppTheme.labelLg.copyWith(fontSize: 16, color: AppTheme.onBackground),
                                      ),
                                      Text(
                                        isUnlocked ? unit['desc'] : '¡Completa la unidad anterior para desbloquear!',
                                        style: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: SquishyProgressBar(
                                              value: progress,
                                              height: 8,
                                              progressColors: isUnlocked
                                                  ? [color, color.withValues(alpha: 0.7)]
                                                  : [AppTheme.outline, AppTheme.outline.withValues(alpha: 0.7)],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '${(progress * 100).toInt()}%',
                                            style: AppTheme.labelMd.copyWith(color: isUnlocked ? color : AppTheme.outline),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isUnlocked ? Icons.arrow_forward_ios_rounded : Icons.lock_outline_rounded,
                                  color: AppTheme.outline,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVideoPresentationScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PresentationVideoScreen(),
        fullscreenDialog: true,
      ),
    );
  }
}
