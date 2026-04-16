import 'dart:ui';

enum DrawingTool { pen, eraser }

class Stroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final DrawingTool tool;

  Stroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.tool,
  });

  Stroke copyWith({List<Offset>? points}) {
    return Stroke(
      points: points ?? this.points,
      color: color,
      strokeWidth: strokeWidth,
      tool: tool,
    );
  }
}
