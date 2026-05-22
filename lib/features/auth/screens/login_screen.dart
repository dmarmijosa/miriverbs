import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tactile_button.dart';
import '../../../core/widgets/feedback_toast.dart';
import '../../../core/widgets/google_logo.dart';
import '../../../core/services/auth_service.dart';
import '../../home/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final result = await AuthService.loginWithGoogle();
    setState(() => _isLoading = false);

    if (result.success) {
      if (mounted) {
        FeedbackToast.showSuccess(
          context,
          title: '¡Sesión con Google!',
          message: 'Iniciaste sesión correctamente.',
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      if (mounted) {
        FeedbackToast.showError(
          context,
          title: 'Error de Google',
          message: result.errorMessage ?? 'No se pudo completar el inicio de sesión.',
        );
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    // Simulate Apple login delay and trigger success for experience validation
    await Future.delayed(const Duration(milliseconds: 1200));
    setState(() => _isLoading = false);

    if (mounted) {
      FeedbackToast.showSuccess(
        context,
        title: '¡Sesión con Apple!',
        message: 'Iniciaste sesión con Apple correctamente (Simulado).',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Beautiful Premium Background Blobs ────────────────────────────────
          Positioned(
            top: -100,
            right: -80,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (0.05 * _animController.value),
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primaryLight.withValues(alpha: 0.45),
                          AppTheme.primaryLight.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFF2AF).withValues(alpha: 0.35),
                    const Color(0xFFFFF2AF).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ── Foreground Layout ──────────────────────────────────────────────
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: IntrinsicHeight(
                      child: AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeAnimation.value,
                            child: Transform.translate(
                              offset: Offset(0, _slideAnimation.value),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Spacer(),

                            // ── Branding Mascot ──────────────────────────────────
                            Center(
                              child: Image.asset(
                                'assets/images/mascot_happy.png',
                                height: 160,
                                width: 160,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Miriverbs',
                              textAlign: TextAlign.center,
                              style: AppTheme.displayLg.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Aprende verbos y frases en inglés de forma progresiva, natural e interactiva.',
                              textAlign: TextAlign.center,
                              style: AppTheme.bodyLg.copyWith(
                                color: AppTheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),

                            // ── Level Badge Previews (Premium UI Decoration) ──────
                            const SizedBox(height: 36),
                            Center(
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: [
                                  _buildBadge('A1', 'Básico', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
                                  _buildBadge('A2', 'Elemental', const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
                                  _buildBadge('B1', 'Intermedio', const Color(0xFFFFF3E0), const Color(0xFFEF6C00)),
                                  _buildBadge('B2', 'Intermedio Alto', const Color(0xFFEDE7F6), const Color(0xFF651FFF)),
                                  _buildBadge('C1', 'Avanzado', const Color(0xFFFCE4EC), const Color(0xFFC2185B)),
                                ],
                              ),
                            ),

                            const Spacer(),
                            const SizedBox(height: 48),

                            // ── Social Sign-In Panel ─────────────────────────────
                            if (_isLoading) ...[
                              const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      color: AppTheme.primary,
                                      strokeWidth: 4,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Iniciando sesión...',
                                      style: TextStyle(
                                        color: AppTheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              // Google SSO
                              TactileButton(
                                text: 'Continuar con Google',
                                leading: const GoogleLogo(size: 22.0),
                                backgroundColor: Colors.white,
                                textColor: AppTheme.onBackground,
                                darkColor: const Color(0xFFD0D3DE),
                                isSecondary: true,
                                onTap: _signInWithGoogle,
                              ),
                              const SizedBox(height: 16),
                              // Apple SSO
                              TactileButton(
                                text: 'Continuar con Apple',
                                icon: Icons.apple_rounded,
                                backgroundColor: Colors.black,
                                textColor: Colors.white,
                                darkColor: const Color(0xFF222222),
                                onTap: _signInWithApple,
                              ),
                            ],

                            const SizedBox(height: 24),
                            // Micro-text footer
                            Center(
                              child: Text(
                                'Al continuar, aceptas nuestros Términos de Servicio.',
                                style: AppTheme.labelMd.copyWith(
                                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String code, String name, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: text.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            name,
            style: TextStyle(
              color: text.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
