import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FeedbackToast {
  static void showSuccess(BuildContext context, {required String title, required String message}) {
    _show(
      context,
      title: title,
      message: message,
      backgroundColor: AppTheme.secondary,
      icon: Icons.celebration_rounded,
      textColor: AppTheme.onBackground,
      iconColor: AppTheme.primary,
    );
  }

  static void showWarning(BuildContext context, {required String title, required String message}) {
    _show(
      context,
      title: title,
      message: message,
      backgroundColor: const Color(0xFFFFF8E1), // Soft amber background
      icon: Icons.warning_amber_rounded,
      textColor: const Color(0xFF5D4037),
      iconColor: Colors.amber[800]!,
    );
  }

  static void showError(BuildContext context, {required String title, required String message}) {
    _show(
      context,
      title: title,
      message: message,
      backgroundColor: const Color(0xFFFFDAD6), // Soft coral red background
      icon: Icons.error_outline_rounded,
      textColor: const Color(0xFF410002),
      iconColor: AppTheme.error,
    );
  }

  static void _show(
    BuildContext context, {
    required String title,
    required String message,
    required Color backgroundColor,
    required IconData icon,
    required Color textColor,
    required Color iconColor,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        title: title,
        message: message,
        backgroundColor: backgroundColor,
        icon: icon,
        textColor: textColor,
        iconColor: iconColor,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String title;
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final Color textColor;
  final Color iconColor;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.title,
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.textColor,
    required this.iconColor,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _yAnim = Tween<double>(begin: -100, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _controller.forward();

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;

    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnim.value,
                  child: Transform.translate(
                    offset: Offset(0, _yAnim.value),
                    child: child,
                  ),
                );
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(
                      color: widget.iconColor.withValues(alpha: 0.15),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          color: widget.iconColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: AppTheme.labelLg.copyWith(
                                color: widget.textColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.message,
                              style: AppTheme.bodyMd.copyWith(
                                color: widget.textColor.withValues(alpha: 0.85),
                                fontSize: 13,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
