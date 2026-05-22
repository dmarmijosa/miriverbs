import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tactile_button.dart';

class PresentationVideoScreen extends StatefulWidget {
  const PresentationVideoScreen({super.key});

  @override
  State<PresentationVideoScreen> createState() => _PresentationVideoScreenState();
}

class _PresentationVideoScreenState extends State<PresentationVideoScreen> {
  String _videoUrl = 'https://www.youtube.com/watch?v=7dxH6HGHa8I';
  String? _videoId;
  YoutubePlayerController? _youtubeController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _videoId = _extractVideoId(_videoUrl);
    _youtubeController = YoutubePlayerController.fromVideoId(
      videoId: _videoId!,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
        playsInline: true,
      ),
    );
    _isLoading = false;
    _fetchVideoUrl();
  }

  @override
  void dispose() {
    _youtubeController?.close();
    super.dispose();
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
          setState(() {
            _videoUrl = fetchedUrl;
            _videoId = newId;
          });
          _youtubeController?.cueVideoById(videoId: _videoId!);
        }
      }
    } catch (e) {
      debugPrint('Error fetching video URL from Supabase: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Premium dark cinema background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Presentación del Método 🎥',
          style: AppTheme.headlineMd.copyWith(
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            // Responsive Video Player container
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                constraints: const BoxConstraints(maxWidth: 720),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: AppTheme.primary),
                        )
                      : YoutubePlayer(
                          controller: _youtubeController!,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Presentation Details Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt_rounded, color: AppTheme.secondary, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'El Método Miriverbs',
                          style: AppTheme.labelLg.copyWith(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'En esta presentación conocerás la base pedagógica detrás de Miriverbs: el aprendizaje de los verbos a través del contexto activo, la gamificación interactiva en la Arena de Batalla, y el mantenimiento de rachas diarias para crear un hábito de estudio sólido.',
                      style: AppTheme.bodyMd.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(flex: 2),
            // Interactive Bottom Exit Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: TactileButton(
                text: '¡Entendido y listo!',
                onTap: () => Navigator.of(context).pop(),
                backgroundColor: AppTheme.primary,
                darkColor: AppTheme.primaryDark,
                textColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
