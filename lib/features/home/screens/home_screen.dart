import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/squishy_progress_bar.dart';
import '../../../core/widgets/feedback_toast.dart';
import '../../../core/services/auth_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../verbs/screens/verbs_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _profile;

  final List<Map<String, dynamic>> _units = [
    {
      'title': 'Unidad 1: Básico Principiante A1',
      'desc': 'Verbos de uso diario (to be, to have, to do, to go...)',
      'level': 'a1',
      'progress': 0.8,
      'verbsCount': 50,
      'color': AppTheme.primary,
      'icon': Icons.star_rounded,
    },
    {
      'title': 'Unidad 2: Básico Elemental A2',
      'desc': 'Verbos cotidianos (to speak, to learn, to buy, to choose...)',
      'level': 'a2',
      'progress': 0.35,
      'verbsCount': 50,
      'color': AppTheme.secondary,
      'icon': Icons.bolt_rounded,
    },
    {
      'title': 'Unidad 3: Intermedio B1',
      'desc': 'Verbos de comunicación general (to build, to spend, to agree...)',
      'level': 'b1',
      'progress': 0.0,
      'verbsCount': 50,
      'color': AppTheme.tertiary,
      'icon': Icons.emoji_events_rounded,
    },
    {
      'title': 'Unidad 4: Intermedio Alto B2',
      'desc': 'Verbos de fluidez y precisión (to achieve, to establish, to reduce...)',
      'level': 'b2',
      'progress': 0.0,
      'verbsCount': 50,
      'color': const Color(0xFF9B59B6),
      'icon': Icons.insights_rounded,
    },
    {
      'title': 'Unidad 5: Avanzado C1',
      'desc': 'Verbos profesionales y académicos (to foster, to leverage, to tackle...)',
      'level': 'c1',
      'progress': 0.0,
      'verbsCount': 50,
      'color': AppTheme.error,
      'icon': Icons.diamond_rounded,
    },
    {
      'title': 'Unidad 6: Experto C2',
      'desc': 'Verbos de maestría y retórica (to excel, to elucidate, to corroborate...)',
      'level': 'c2',
      'progress': 0.0,
      'verbsCount': 50,
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
    setState(() {
      _profile = data;
    });
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

  @override
  Widget build(BuildContext context) {
    final String name = _profile?['full_name'] ?? AuthService.currentUser?.email?.split('@').first ?? 'Estudiante';
    final String avatarUrl = _profile?['avatar_url'] ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // ── Header Profile Area ────────────────────────────────────
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFE8EFFF),
                        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl.isEmpty
                            ? Text(
                                name.substring(0, 1).toUpperCase(),
                                style: AppTheme.headlineMd.copyWith(color: AppTheme.primary),
                              )
                            : null,
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
                              '3 días seguidos',
                              style: AppTheme.labelLg.copyWith(color: AppTheme.secondaryDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const SquishyProgressBar(value: 0.6),
                        const SizedBox(height: 12),
                        Text(
                          'Completa 5 verbos más para lograr tu meta de hoy.',
                          style: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text(
                    'Tu Ruta de Aprendizaje',
                    style: AppTheme.headlineMd.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 16),

                  // ── Learning units list ────────────────────────────────────
                  Expanded(
                    child: ListView.builder(
                      itemCount: _units.length,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final unit = _units[index];
                        final double progress = unit['progress'];
                        final Color color = unit['color'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            side: const BorderSide(color: AppTheme.surfaceContainer, width: 1.5),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => VerbsListScreen(
                                    title: unit['title'],
                                    levelCode: unit['level'],
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  // Icon badge
                                  Container(
                                    height: 52,
                                    width: 52,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(unit['icon'], color: color, size: 28),
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
                                          unit['desc'],
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
                                                progressColors: [color, color.withValues(alpha: 0.7)],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              '${(progress * 100).toInt()}%',
                                              style: AppTheme.labelMd.copyWith(color: color),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.outline, size: 16),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
        ],
      ),
    );
  }
}
