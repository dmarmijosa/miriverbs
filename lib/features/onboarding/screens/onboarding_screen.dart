import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tactile_button.dart';
import '../../../core/widgets/squishy_progress_bar.dart';
import '../../auth/screens/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _selectedGoal = 'Regular';

  final List<String> _goals = [
    'Casual (5 min/día)',
    'Regular (15 min/día)',
    'Serio (30 min/día)',
    'Intenso (45 min/día)',
  ];

  String _videoUrl = 'https://www.youtube.com/watch?v=7dxH6HGHa8I';
  String? _videoId;
  YoutubePlayerController? _youtubeController;
  bool _loadingVideo = true;

  @override
  void initState() {
    super.initState();
    _videoId = _extractVideoId(_videoUrl);
    _youtubeController = YoutubePlayerController.fromVideoId(
      videoId: _videoId!,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
        playsInline: true,
      ),
    );
    _loadingVideo = false;
    _fetchVideoUrl();
  }

  String _extractVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtube.com')) {
        final v = uri.queryParameters['v'];
        if (v != null && v.isNotEmpty) return v;
      } else if (uri.host.contains('youtu.be')) {
        if (uri.pathSegments.isNotEmpty) return uri.pathSegments.first;
      }
    } catch (_) {}

    final regExp = RegExp(
      r'^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*',
      caseSensitive: false,
      multiLine: false,
    );
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 2) {
      final id = match.group(2);
      if (id != null && id.length == 11) return id;
    }

    return '7dxH6HGHa8I';
  }

  Future<void> _fetchVideoUrl() async {
    try {
      final response = await Supabase.instance.client
          .from('app_configs')
          .select('value')
          .eq('key', 'presentation_video_url')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        final fetchedUrl = response['value'];
        final newId = _extractVideoId(fetchedUrl);
        if (newId != _videoId) {
          _videoUrl = fetchedUrl;
          _videoId = newId;
          _youtubeController?.cueVideoById(videoId: _videoId!);
        }
      }
    } catch (e) {
      debugPrint('Error fetching video URL from Supabase: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _youtubeController?.close();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    // Pause video if navigating away from the video slide (index 1)
    if (page != 1 && _youtubeController != null) {
      _youtubeController!.pauseVideo();
    }
  }

  void _finishOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // ── Header / Top progress line ─────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Miriverbs',
                    style: AppTheme.headlineMd.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextButton(
                    onPressed: _finishOnboarding,
                    child: Text(
                      'Saltar',
                      style: AppTheme.labelLg.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SquishyProgressBar(value: (_currentPage + 1) / 4),
              const SizedBox(height: 32),

              // ── Slider Area ────────────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: [
                    _buildBienvenidaSlide(),
                    _buildVideoSlide(),
                    _buildGamificacionSlide(),
                    _buildMetasSlide(),
                  ],
                ),
              ),

              // ── Footer / Navigation Actions ────────────────────────────────
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? AppTheme.primary : AppTheme.outline,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              TactileButton(
                text: _currentPage == 3 ? '¡Empezar ahora!' : 'Siguiente',
                onTap: _nextPage,
                backgroundColor: _currentPage == 3 ? AppTheme.secondary : AppTheme.primary,
                darkColor: _currentPage == 3 ? AppTheme.secondaryDark : AppTheme.primaryDark,
                textColor: _currentPage == 3 ? AppTheme.onBackground : Colors.white,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // Slide 1: Welcome / Bienvenida
  Widget _buildBienvenidaSlide() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/mascot_happy.png',
          height: 180,
          width: 180,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 40),
        Text(
          '¡Domina los verbos!',
          textAlign: TextAlign.center,
          style: AppTheme.displayLg.copyWith(fontSize: 34),
        ),
        const SizedBox(height: 16),
        Text(
          'Aprende y practica verbos y frases en inglés de manera progresiva y divertida, desde el nivel básico hasta el avanzado.',
          textAlign: TextAlign.center,
          style: AppTheme.bodyLg.copyWith(color: AppTheme.onSurfaceVariant),
        ),
      ],
    );
  }

  // Slide 2: Presentation Video
  Widget _buildVideoSlide() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Conoce Miriverbs 🎥',
          textAlign: TextAlign.center,
          style: AppTheme.displayLg.copyWith(fontSize: 34),
        ),
        const SizedBox(height: 12),
        Text(
          'Mira este breve video de presentación para entender cómo dominarás el inglés.',
          textAlign: TextAlign.center,
          style: AppTheme.bodyLg.copyWith(color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: Center(
            child: _loadingVideo
                ? const CircularProgressIndicator(color: AppTheme.primary)
                : Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: YoutubePlayer(
                        controller: _youtubeController!,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // Slide 2: Gamification / Gamificación
  Widget _buildGamificacionSlide() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/mascot_celebrating.png',
          height: 180,
          width: 180,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 40),
        Text(
          'Batallas y Retos',
          textAlign: TextAlign.center,
          style: AppTheme.displayLg.copyWith(fontSize: 34),
        ),
        const SizedBox(height: 16),
        Text(
          'Sube de nivel completando rachas y desafía a tus amigos en tiempo real en la Arena Multijugador ⚔️.',
          textAlign: TextAlign.center,
          style: AppTheme.bodyLg.copyWith(color: AppTheme.onSurfaceVariant),
        ),
      ],
    );
  }

  // Slide 3: Goals / Metas
  Widget _buildMetasSlide() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Elige tu meta diaria',
          textAlign: TextAlign.center,
          style: AppTheme.headlineLg,
        ),
        const SizedBox(height: 8),
        Text(
          'Para ayudarte a mantener el ritmo y el aprendizaje constante.',
          textAlign: TextAlign.center,
          style: AppTheme.bodyMd.copyWith(color: AppTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _goals.length,
            itemBuilder: (context, index) {
              final goal = _goals[index];
              final isSelected = _selectedGoal == goal;

              return GestureDetector(
                onTap: () => setState(() => _selectedGoal = goal),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE8EFFF) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.outline.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: isSelected ? AppTheme.primary : AppTheme.outline,
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        goal,
                        style: AppTheme.labelLg.copyWith(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppTheme.primary : AppTheme.onBackground,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
