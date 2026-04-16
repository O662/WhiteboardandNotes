import 'package:flutter/material.dart';
import 'stroke.dart';

sealed class WhiteboardItem {
  const WhiteboardItem();

  Rect get bounds;
  WhiteboardItem movedBy(Offset delta);
  Map<String, dynamic> toJson();

  static WhiteboardItem fromJson(Map<String, dynamic> json) =>
      switch (json['type'] as String) {
        'stroke' => StrokeItem(
            Stroke.fromJson(json['stroke'] as Map<String, dynamic>)),
        'text' => TextItem(
            position: Offset((json['x'] as num).toDouble(),
                (json['y'] as num).toDouble()),
            text: json['text'] as String,
            color: _colorFromInt(json['color'] as int),
            fontSize: (json['fontSize'] as num).toDouble(),
          ),
        'stickyNote' => StickyNoteItem(
            position: Offset((json['x'] as num).toDouble(),
                (json['y'] as num).toDouble()),
            text: json['text'] as String,
            color: _colorFromInt(json['color'] as int),
          ),
        _ => throw FormatException('Unknown item type: ${json['type']}'),
      };
}

final class StrokeItem extends WhiteboardItem {
  final Stroke stroke;
  const StrokeItem(this.stroke);

  @override
  Rect get bounds {
    if (stroke.points.isEmpty) return Rect.zero;
    if (stroke.tool == DrawingTool.shape || stroke.tool == DrawingTool.frame) {
      if (stroke.points.length < 2) return Rect.zero;
      final r = Rect.fromPoints(stroke.points.first, stroke.points.last);
      if (stroke.tool == DrawingTool.frame) {
        return r.expandToInclude(Rect.fromLTWH(r.left, r.top - 24, 72, 24));
      }
      return r;
    }
    double minX = stroke.points.first.dx, maxX = minX;
    double minY = stroke.points.first.dy, maxY = minY;
    for (final p in stroke.points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final inflate = stroke.strokeWidth / 2 + 4;
    return Rect.fromLTRB(
        minX - inflate, minY - inflate, maxX + inflate, maxY + inflate);
  }

  @override
  StrokeItem movedBy(Offset delta) => StrokeItem(stroke.movedBy(delta));

  @override
  Map<String, dynamic> toJson() => {'type': 'stroke', 'stroke': stroke.toJson()};
}

final class TextItem extends WhiteboardItem {
  final Offset position;
  final String text;
  final Color color;
  final double fontSize;

  const TextItem({
    required this.position,
    required this.text,
    required this.color,
    this.fontSize = 20.0,
  });

  @override
  Rect get bounds {
    final approxW = (text.length * fontSize * 0.55 + 16).clamp(40.0, 480.0);
    final approxH = fontSize * 1.6 + 8;
    return Rect.fromLTWH(position.dx, position.dy, approxW, approxH);
  }

  @override
  TextItem movedBy(Offset delta) => TextItem(
        position: position + delta,
        text: text,
        color: color,
        fontSize: fontSize,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'text',
        'x': position.dx,
        'y': position.dy,
        'text': text,
        'color': _colorToInt(color),
        'fontSize': fontSize,
      };
}

final class StickyNoteItem extends WhiteboardItem {
  final Offset position;
  final String text;
  final Color color;

  const StickyNoteItem({
    required this.position,
    required this.text,
    required this.color,
  });

  @override
  Rect get bounds => Rect.fromLTWH(position.dx, position.dy, 200, 160);

  @override
  StickyNoteItem movedBy(Offset delta) => StickyNoteItem(
        position: position + delta,
        text: text,
        color: color,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'stickyNote',
        'x': position.dx,
        'y': position.dy,
        'text': text,
        'color': _colorToInt(color),
      };
}

int _colorToInt(Color c) =>
    ((c.a * 255).round() << 24) |
    ((c.r * 255).round() << 16) |
    ((c.g * 255).round() << 8) |
    (c.b * 255).round();

Color _colorFromInt(int v) => Color.fromARGB(
    (v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
