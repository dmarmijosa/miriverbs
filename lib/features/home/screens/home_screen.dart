import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
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
  final GlobalKey _keyStreak = GlobalKey();
  final GlobalKey _keyTikTok = GlobalKey();
  final GlobalKey _keyUnit = GlobalKey();

  /// Map containing user profile information (e.g., full_name, avatar_url, streak_days, last_practice_date)
  Map<String, dynamic>? _profile;

  /// List of completed progressive sublevels from user_sublevel_progress table in Supabase
  List<Map<String, dynamic>> _completedProgress = [];

  /// The visual name of the Teacher's TikTok account, sourced dynamically from Supabase
  String _tiktokName = 'Teacher Miryan❤️👩‍🏫💻';

  /// The web URL of the Teacher's TikTok account, sourced dynamically from Supabase
  String _tiktokUrl = 'https://www.tiktok.com/@miryanyanez16';

  /// Predefined static curriculum map outlining learning units, difficulty levels, descriptions, colors, and badges
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
    // Cold load the active profile and study progress on startup
    _loadProfile();
  }

  /// Queries the active student profile, CEFR progress, and dynamic TikTok configs from Supabase.
  /// Refreshes the local widget state to render correct badges, streaks, and brand URLs.
  Future<void> _loadProfile() async {
    final data = await AuthService.getProfile();
    final progress = await ProgressService.fetchSublevelProgress();
    
    try {
      final configs = await Supabase.instance.client
          .from('app_configs')
          .select()
          .inFilter('key', ['tiktok_name', 'tiktok_url']);
      if (configs.isNotEmpty) {
        for (final row in configs) {
          final k = row['key'];
          final v = row['value'];
          if (k == 'tiktok_name' && v != null) {
            _tiktokName = v;
          } else if (k == 'tiktok_url' && v != null) {
            _tiktokUrl = v;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading TikTok configs from Supabase: $e');
    }

    if (mounted) {
      setState(() {
        _profile = data;
        _completedProgress = progress;
      });
      _startShowcaseIfNeeded();
    }
  }

  void _startShowcaseIfNeeded() async {
    final userId = AuthService.currentUser?.id;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final bool done = prefs.getBool('showcase_done_v1_$userId') ?? false;
    if (!done) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              ShowCaseWidget.of(context).startShowCase([
                _keyStreak,
                _keyTikTok,
                _keyUnit,
              ]);
              prefs.setBool('showcase_done_v1_$userId', true);
            }
          });
        });
      }
    }
  }

  /// Triggers a secure URL launch redirecting the user to the Teacher's TikTok profile in external app/browser.
  Future<void> _launchTikTok() async {
    try {
      final uri = Uri.parse(_tiktokUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          FeedbackToast.showError(
            context,
            title: 'Error de enlace',
            message: 'No se pudo abrir la cuenta de TikTok.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        FeedbackToast.showError(
          context,
          title: 'Error',
          message: 'Ocurrió un problema al abrir el enlace.',
        );
      }
    }
  }

  /// Signs the user out from Supabase Auth and navigates back to the SSO login screen.
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

  /// Displays an interactive, glassmorphic bottom sheet letting users choose a premium Mascot character as their avatar.
  /// Updates profile details in Supabase database instantly upon selection.
  /// 
  /// @param context - Standard build routing context.
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

    return ShowCaseWidget(
      builder: (context) {
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
                            Row(
                              children: [
                                Text(
                                  'Hola, ',
                                  style: AppTheme.headlineMd.copyWith(fontSize: 20),
                                ),
                                Flexible(
                                  child: Text(
                                    name,
                                    style: AppTheme.headlineMd.copyWith(fontSize: 20),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                Text(
                                  ' 👋',
                                  style: AppTheme.headlineMd.copyWith(fontSize: 20),
                                ),
                              ],
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
                  Showcase(
                    key: _keyStreak,
                    title: 'Racha de estudio 🔥',
                    description: 'Completa cualquier subnivel cada día para mantener tu racha activa.',
                    textColor: AppTheme.primary,
                    targetPadding: const EdgeInsets.all(8),
                    child: Container(
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
                  const SizedBox(height: 16),

                  // ── TikTok Social Card ─────────────────────────────────────
                  Showcase(
                    key: _keyTikTok,
                    title: 'Videos de Teacher Miryan 🎵',
                    description: '¡Aprende inglés de forma súper divertida con lecciones cortas y dinámicas en TikTok!',
                    textColor: AppTheme.primary,
                    targetPadding: const EdgeInsets.all(8),
                    child: Container(
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
                          onTap: _launchTikTok,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF2F2F2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Text(
                                    '🎵',
                                    style: TextStyle(fontSize: 20),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _tiktokName,
                                        style: AppTheme.labelLg.copyWith(fontSize: 15),
                                      ),
                                      Text(
                                        '¡Aprende inglés con los mejores videos de TikTok!',
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

                    final Widget cardWidget = Card(
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

                    if (levelCode == 'a1') {
                      return Showcase(
                        key: _keyUnit,
                        title: 'Tu Ruta de Aprendizaje 📚',
                        description: 'Toca una unidad desbloqueada para ver la lista de verbos y empezar a practicar.',
                        textColor: AppTheme.primary,
                        targetPadding: const EdgeInsets.all(4),
                        child: cardWidget,
                      );
                    }
                    return cardWidget;
                  }),

                  const SizedBox(height: 32),
                  const Divider(color: AppTheme.surfaceContainer, thickness: 1.5),
                  const SizedBox(height: 16),
                  
                  // Footer section
                  Column(
                    children: [
                      Text(
                        'Miri Verbs © ${DateTime.now().year} • Nexacode',
                        style: AppTheme.bodyMd.copyWith(
                          color: AppTheme.outline,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _showPrivacyPolicyModal,
                        child: Text(
                          'Política de Privacidad',
                          style: AppTheme.labelLg.copyWith(
                            color: AppTheme.primary,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                            decorationColor: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  },
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

  void _showPrivacyPolicyModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            side: const BorderSide(color: AppTheme.surfaceContainer, width: 1.5),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550, maxHeight: 600),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Política de Privacidad',
                              style: AppTheme.headlineMd.copyWith(fontSize: 16),
                            ),
                            Text(
                              'Miri Verbs • Actualizado ${DateTime.now().year}',
                              style: AppTheme.bodyMd.copyWith(
                                color: AppTheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.outline, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.surfaceContainer, thickness: 1),
                  const SizedBox(height: 12),

                  // Content Scroll View
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'En Miri Verbs (desarrollada por Danny Armijos / Nexacode), nos tomamos muy en serio tu privacidad. Esta política de privacidad describe cómo recopilamos, utilizamos y protegemos la información personal cuando utilizas nuestra aplicación móvil.',
                            style: AppTheme.bodyMd.copyWith(fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          
                          _buildSectionTitle('1. Información que Recopilamos'),
                          _buildBulletPoint('Información de Registro:', 'Tu dirección de correo electrónico y tu nombre o apodo que elijas para tu perfil para identificar tu cuenta.'),
                          _buildBulletPoint('Identificadores Únicos:', 'Un ID de usuario cifrado generado por nuestro sistema de base de datos de Supabase y el token de notificaciones push de tu dispositivo móvil.'),
                          _buildBulletPoint('Datos de Diagnóstico (Anónimos):', 'Registros de fallos y rendimiento (Firebase Crashlytics) para solucionar problemas de programación y garantizar la estabilidad de la app.'),
                          const SizedBox(height: 14),

                          _buildSectionTitle('2. Cómo Utilizámos tus Datos'),
                          _buildBulletPoint('Funcionalidad de la App:', 'Autenticar tu cuenta, guardar tu progreso en la lista de verbos, gestionar tus puntuaciones y emparejarte en batallas en tiempo real en la Arena PvP.'),
                          _buildBulletPoint('Notificaciones Push:', 'Enviar alertas de desafíos PvP en tiempo real a tu dispositivo utilizando el identificador de dispositivo para asegurar que los retos te lleguen al instante.'),
                          _buildBulletPoint('Soporte y Estabilidad:', 'Analizar errores técnicos de manera totalmente anónima.'),
                          const SizedBox(height: 14),

                          _buildSectionTitle('3. Compartición y Venta de Datos'),
                          Text(
                            'Miri Verbs no vende, alquila ni comparte tus datos personales con terceros con fines comerciales o publicitarios.',
                            style: AppTheme.bodyMd.copyWith(fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 14),

                          _buildSectionTitle('4. Eliminación de Cuentas y Datos'),
                          Text(
                            'Creemos firmemente en la soberanía de los datos. Tienes derecho a solicitar la eliminación permanente de tu cuenta y todos tus progresos, rachas y copas PvP en cualquier momento de forma instantánea.',
                            style: AppTheme.bodyMd.copyWith(fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          
                          // Clickable delete account action
                          InkWell(
                            onTap: () {
                              Navigator.of(context).pop(); // Close modal first
                              _deleteAccountNatively();
                            },
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.08),
                                border: Border.all(color: AppTheme.error.withValues(alpha: 0.15), width: 1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  const Icon(Icons.delete_forever_rounded, color: AppTheme.error, size: 16),
                                  Text(
                                    'Solicitar Eliminación de Cuenta 🗑️',
                                    style: AppTheme.labelLg.copyWith(color: AppTheme.error, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.surfaceContainer, thickness: 1),
                  const SizedBox(height: 12),

                  // Close button
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Entendido',
                      style: AppTheme.labelLg.copyWith(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: AppTheme.labelLg.copyWith(fontSize: 13, color: AppTheme.primary),
      ),
    );
  }

  Widget _buildBulletPoint(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5, left: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 4, color: AppTheme.outline),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTheme.bodyMd.copyWith(fontSize: 11, color: AppTheme.onSurfaceVariant, height: 1.3),
                children: [
                  TextSpan(
                    text: '$label ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.onBackground),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _deleteAccountNatively() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            side: const BorderSide(color: AppTheme.surfaceContainer, width: 1.5),
          ),
          title: Text(
            '¿Eliminar cuenta para siempre? ⚠️',
            style: AppTheme.headlineMd.copyWith(fontSize: 18, color: AppTheme.error),
          ),
          content: Text(
            'Esta acción es definitiva e irreversible. Borrará de inmediato todo tu progreso, copas PvP, rachas de estudio y tu perfil de Miri Verbs. No podrás recuperar tus datos de ninguna manera.',
            style: AppTheme.bodyMd.copyWith(fontSize: 13, color: AppTheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancelar',
                style: AppTheme.labelLg.copyWith(color: AppTheme.outline),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Close confirmation dialog
                
                // Show loading progress overlay
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                );

                try {
                  // Call the SECURITY DEFINER postgres function to delete the current user
                  await Supabase.instance.client.rpc('delete_current_user');
                  
                  // Logout
                  await AuthService.logout();

                  if (mounted) {
                    Navigator.of(context).pop(); // Close progress dialog
                    FeedbackToast.showSuccess(
                      context,
                      title: 'Cuenta Eliminada 🗑️',
                      message: 'Tu cuenta y todos tus datos han sido borrados de producción.',
                    );
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop(); // Close progress dialog
                    FeedbackToast.showWarning(
                      context,
                      title: 'Error de Eliminación ⚠️',
                      message: 'No se pudo procesar la eliminación. Inténtalo de nuevo más tarde.',
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                elevation: 0,
              ),
              child: Text(
                'Sí, eliminar para siempre',
                style: AppTheme.labelLg.copyWith(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}

