import 'dart:ui';

enum DrawingTool { pan, pen, highlighter, eraser, select, shape, frame, stickyNote, text, math }

class Stroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final DrawingTool tool;

  const Stroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.tool,
  });

  Stroke copyWith({List<Offset>? points}) => Stroke(
        points: points ?? this.points,
        color: color,
        strokeWidth: strokeWidth,
        tool: tool,
      );

  Stroke movedBy(Offset delta) =>
      copyWith(points: points.map((p) => p + delta).toList());

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'color': _colorToInt(color),
        'strokeWidth': strokeWidth,
        'tool': tool.name,
      };

  static Stroke fromJson(Map<String, dynamic> json) => Stroke(
        points: (json['points'] as List)
            .map((p) => Offset(
                (p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
            .toList(),
        color: _colorFromInt(json['color'] as int),
        strokeWidth: (json['strokeWidth'] as num).toDouble(),
        tool: DrawingTool.values.firstWhere(
          (t) => t.name == json['tool'],
          orElse: () => DrawingTool.pen,
        ),
      );
}

int _colorToInt(Color c) =>
    ((c.a * 255).round() << 24) |
    ((c.r * 255).round() << 16) |
    ((c.g * 255).round() << 8) |
    (c.b * 255).round();

Color _colorFromInt(int v) => Color.fromARGB(
    (v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
