import 'package:flutter/material.dart';
import '/models/durationstate.dart';

class MiniPlayerProgressBar extends StatelessWidget {
  const MiniPlayerProgressBar(
      {super.key,
      required this.progressBarStatus,
      required this.progressBarColor});
  final ProgressBarState progressBarStatus;
  final Color progressBarColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 4),
      painter: ProgressBarPainter(
          current: progressBarStatus.current,
          total: progressBarStatus.total,
          progressBarColor: progressBarColor),
    );
  }
}

class ProgressBarPainter extends CustomPainter {
  const ProgressBarPainter(
      {required this.current,
      required this.total,
      required this.progressBarColor});
  final Duration current;
  final Duration total;
  final Color progressBarColor;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = progressBarColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    final end = total.inSeconds == 0
        ? 0.0
        : size.width * (current.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    canvas.drawLine(Offset(0, y), Offset(end, y), paint);
  }

  @override
  bool shouldRepaint(covariant ProgressBarPainter oldDelegate) {
    return oldDelegate.current != current ||
        oldDelegate.total != total ||
        oldDelegate.progressBarColor != progressBarColor;
  }
}
