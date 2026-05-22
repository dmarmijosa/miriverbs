import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SquishyProgressBar extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double height;
  final Color trackColor;
  final List<Color> progressColors;

  const SquishyProgressBar({
    super.key,
    required this.value,
    this.height = 14.0,
    this.trackColor = AppTheme.surfaceContainer,
    this.progressColors = const [AppTheme.primary, Color(0xFF7D9CFF)],
  });

  @override
  Widget build(BuildContext context) {
    final double clampedValue = value.clamp(0.0, 1.0);

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: trackColor == AppTheme.surfaceContainer
              ? AppTheme.surfaceDim.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double totalWidth = constraints.maxWidth;
          final double progressWidth = totalWidth * clampedValue;

          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                width: progressWidth,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height / 2),
                  gradient: LinearGradient(
                    colors: progressColors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: clampedValue > 0.05
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(right: 3),
                          width: 6,
                          height: height - 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }
}
