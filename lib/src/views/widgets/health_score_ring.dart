import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class HealthScoreRing extends StatelessWidget {
  const HealthScoreRing({
    super.key,
    required this.score,
    this.size = 56,
    this.strokeWidth = 5,
  });

  final int score;
  final double size;
  final double strokeWidth;

  static Color colorFor(int score) {
    if (score >= 80) {
      return AppColors.success;
    }
    if (score >= 55) {
      return AppColors.warning;
    }
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(score);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: score.clamp(0, 100) / 100,
          color: color,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Text(
            '$score',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.28,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final background = Paint()
      ..color = AppColors.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final foreground = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, background);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * progress,
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
