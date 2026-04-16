import 'package:flutter/material.dart';
import '../models/stroke.dart';

class WhiteboardPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? activeStroke;

  WhiteboardPainter({required this.strokes, this.activeStroke});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in [...strokes, ?activeStroke]) {
      _drawStroke(canvas, stroke);
    }
  }

  void _drawStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.tool == DrawingTool.eraser
          ? Colors.white
          : stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2, paint..style = PaintingStyle.fill);
      return;
    }

    final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length - 1; i++) {
      final mid = Offset(
        (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
        (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(
        stroke.points[i].dx, stroke.points[i].dy,
        mid.dx, mid.dy,
      );
    }
    path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WhiteboardPainter oldDelegate) => true;
}
