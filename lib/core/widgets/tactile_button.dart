import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TactileButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color darkColor;
  final Color textColor;
  final bool isSecondary;
  final IconData? icon;
  final Widget? leading;
  final double height;
  final double width;
  final double fontSize;

  const TactileButton({
    super.key,
    required this.text,
    required this.onTap,
    this.backgroundColor = AppTheme.primary,
    this.darkColor = AppTheme.primaryDark,
    this.textColor = Colors.white,
    this.isSecondary = false,
    this.icon,
    this.leading,
    this.height = 56.0,
    this.width = double.infinity,
    this.fontSize = 16.0,
  });

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      setState(() => _isPressed = false);
      widget.onTap!();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onTap == null;
    final double depth = 4.0;

    Color bg = widget.isSecondary ? AppTheme.surface : widget.backgroundColor;
    Color borderBg = widget.isSecondary ? AppTheme.surfaceContainer : widget.darkColor;
    Color txtColor = widget.isSecondary ? AppTheme.primary : widget.textColor;

    if (isDisabled) {
      bg = AppTheme.surfaceContainer;
      borderBg = AppTheme.surfaceDim;
      txtColor = AppTheme.onSurfaceVariant.withValues(alpha: 0.5);
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: SizedBox(
        width: widget.width,
        height: widget.height + depth,
        child: Stack(
          children: [
            // ── The bottom shadow/extrusion ────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: borderBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: widget.isSecondary
                      ? Border.all(color: AppTheme.outline.withValues(alpha: 0.5), width: 1.5)
                      : null,
                ),
              ),
            ),
            // ── The primary interactive face ────────────────────────────────
            AnimatedPositioned(
              duration: const Duration(milliseconds: 60),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              top: _isPressed ? depth : 0,
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: widget.isSecondary
                      ? Border.all(color: AppTheme.outline, width: 2)
                      : null,
                  boxShadow: _isPressed || isDisabled
                      ? null
                      : [
                          BoxShadow(
                            color: borderBg.withValues(alpha: 0.25),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          )
                        ],
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.leading != null) ...[
                        widget.leading!,
                        const SizedBox(width: 8),
                      ] else if (widget.icon != null) ...[
                        Icon(widget.icon, color: txtColor, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: AppTheme.labelLg.copyWith(
                          color: txtColor,
                          fontSize: widget.fontSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
