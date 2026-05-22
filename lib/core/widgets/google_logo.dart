import 'package:flutter/material.dart';

class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 24.0;
    canvas.scale(scale, scale);

    final Paint paint = Paint()..isAntiAlias = true;

    // Red (Top Arc)
    paint.color = const Color(0xFFEA4335);
    final Path pathRed = Path()
      ..moveTo(12.0, 5.0)
      ..cubicTo(15.2, 5.0, 18.1, 6.1, 20.3, 8.2)
      ..lineTo(23.9, 4.6)
      ..cubicTo(20.7, 1.7, 16.6, 0.0, 12.0, 0.0)
      ..cubicTo(7.4, 0.0, 3.4, 2.6, 1.2, 6.4)
      ..lineTo(5.1, 9.4)
      ..cubicTo(6.3, 6.8, 8.9, 5.0, 12.0, 5.0)
      ..close();
    canvas.drawPath(pathRed, paint);

    // Green (Bottom Arc)
    paint.color = const Color(0xFF34A853);
    final Path pathGreen = Path()
      ..moveTo(12.0, 19.0)
      ..cubicTo(8.9, 19.0, 6.3, 17.2, 5.1, 14.6)
      ..lineTo(1.2, 17.6)
      ..cubicTo(3.4, 21.4, 7.4, 24.0, 12.0, 24.0)
      ..cubicTo(16.4, 24.0, 20.2, 22.4, 22.9, 19.7)
      ..lineTo(19.0, 16.7)
      ..cubicTo(17.3, 18.1, 14.8, 19.0, 12.0, 19.0)
      ..close();
    canvas.drawPath(pathGreen, paint);

    // Yellow (Left Arc)
    paint.color = const Color(0xFFFBBC05);
    final Path pathYellow = Path()
      ..moveTo(5.1, 14.6)
      ..cubicTo(4.7, 13.5, 4.5, 12.3, 4.5, 11.0)
      ..cubicTo(4.5, 9.7, 4.7, 8.5, 5.1, 7.4)
      ..lineTo(1.2, 4.4)
      ..cubicTo(0.4, 6.4, 0.0, 8.6, 0.0, 11.0)
      ..cubicTo(0.0, 13.4, 0.4, 15.6, 1.2, 17.6)
      ..lineTo(5.1, 14.6)
      ..close();
    canvas.drawPath(pathYellow, paint);

    // Blue (Right bar & Right Arc)
    paint.color = const Color(0xFF4285F4);
    final Path pathBlue = Path()
      ..moveTo(24.0, 12.0)
      ..cubicTo(24.0, 11.2, 23.9, 10.4, 23.8, 9.6)
      ..lineTo(12.0, 9.6)
      ..lineTo(12.0, 14.4)
      ..lineTo(18.7, 14.4)
      ..cubicTo(18.4, 16.0, 17.5, 17.4, 16.1, 18.3)
      ..lineTo(20.0, 21.3)
      ..cubicTo(22.4, 19.1, 24.0, 15.8, 24.0, 12.0)
      ..close();
    canvas.drawPath(pathBlue, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
