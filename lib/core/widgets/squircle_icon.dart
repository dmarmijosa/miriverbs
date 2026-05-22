import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SquircleIcon extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final double size;
  final double iconSize;

  const SquircleIcon({
    super.key,
    required this.icon,
    this.iconColor = AppTheme.primary,
    this.backgroundColor = const Color(0xFFE8EFFF),
    this.size = 48.0,
    this.iconSize = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: iconColor,
          size: iconSize,
        ),
      ),
    );
  }
}
