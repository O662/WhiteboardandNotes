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
        'image' => ImageItem(
            position: Offset((json['x'] as num).toDouble(),
                (json['y'] as num).toDouble()),
            path: json['path'] as String,
            width: (json['width'] as num).toDouble(),
            height: (json['height'] as num).toDouble(),
          ),
        'table' => TableItem(
            position: Offset((json['x'] as num).toDouble(),
                (json['y'] as num).toDouble()),
            rows: json['rows'] as int,
            cols: json['cols'] as int,
            cells: (json['cells'] as List)
                .map((row) =>
                    (row as List).map((c) => c as String).toList())
                .toList(),
            width: (json['width'] as num).toDouble(),
            height: (json['height'] as num).toDouble(),
          ),
        'attachment' => AttachmentItem(
            position: Offset((json['x'] as num).toDouble(),
                (json['y'] as num).toDouble()),
            path: json['path'] as String,
            filename: json['filename'] as String,
          ),
        'link' => LinkItem(
            position: Offset((json['x'] as num).toDouble(),
                (json['y'] as num).toDouble()),
            url: json['url'] as String,
            label: json['label'] as String,
          ),
        'video' => VideoItem(
            position: Offset((json['x'] as num).toDouble(),
                (json['y'] as num).toDouble()),
            path: json['path'] as String,
            filename: json['filename'] as String,
            width: (json['width'] as num).toDouble(),
            height: (json['height'] as num).toDouble(),
          ),
        'printout' => PrintoutItem(
            position: Offset((json['x'] as num).toDouble(),
                (json['y'] as num).toDouble()),
            path: json['path'] as String,
            filename: json['filename'] as String,
            width: (json['width'] as num).toDouble(),
            height: (json['height'] as num).toDouble(),
          ),
        'mathGraph' => MathGraphItem(
            position: Offset((json['x'] as num).toDouble(),
                (json['y'] as num).toDouble()),
            graphType: MathGraphType.values
                .firstWhere((t) => t.name == json['graphType']),
            width: (json['width'] as num).toDouble(),
            height: (json['height'] as num).toDouble(),
          ),
        _ => throw FormatException('Unknown item type: ${json['type']}'),
      };
}

// ── Existing item types ────────────────────────────────────────────────────

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
  Map<String, dynamic> toJson() =>
      {'type': 'stroke', 'stroke': stroke.toJson()};
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

// ── Rich item types ────────────────────────────────────────────────────────

final class ImageItem extends WhiteboardItem {
  final Offset position;
  final String path;
  final double width;
  final double height;

  const ImageItem({
    required this.position,
    required this.path,
    this.width = 400.0,
    this.height = 300.0,
  });

  @override
  Rect get bounds => Rect.fromLTWH(position.dx, position.dy, width, height);

  @override
  ImageItem movedBy(Offset delta) =>
      ImageItem(position: position + delta, path: path, width: width, height: height);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'image',
        'x': position.dx,
        'y': position.dy,
        'path': path,
        'width': width,
        'height': height,
      };
}

final class TableItem extends WhiteboardItem {
  final Offset position;
  final int rows;
  final int cols;
  final List<List<String>> cells;
  final double width;
  final double height;

  const TableItem({
    required this.position,
    required this.rows,
    required this.cols,
    required this.cells,
    required this.width,
    required this.height,
  });

  factory TableItem.empty({
    required Offset position,
    required int rows,
    required int cols,
  }) {
    final cells = List.generate(rows, (_) => List.filled(cols, ''));
    final w = (cols * 100.0).clamp(200.0, 800.0);
    final h = rows * 36.0 + 4.0;
    return TableItem(
      position: position,
      rows: rows,
      cols: cols,
      cells: cells,
      width: w,
      height: h,
    );
  }

  TableItem withCells(List<List<String>> newCells) => TableItem(
        position: position,
        rows: rows,
        cols: cols,
        cells: newCells,
        width: width,
        height: height,
      );

  @override
  Rect get bounds => Rect.fromLTWH(position.dx, position.dy, width, height);

  @override
  TableItem movedBy(Offset delta) => TableItem(
        position: position + delta,
        rows: rows,
        cols: cols,
        cells: cells,
        width: width,
        height: height,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'table',
        'x': position.dx,
        'y': position.dy,
        'rows': rows,
        'cols': cols,
        'cells': cells,
        'width': width,
        'height': height,
      };
}

final class AttachmentItem extends WhiteboardItem {
  final Offset position;
  final String path;
  final String filename;

  static const double cardWidth = 280.0;
  static const double cardHeight = 80.0;

  const AttachmentItem({
    required this.position,
    required this.path,
    required this.filename,
  });

  @override
  Rect get bounds =>
      Rect.fromLTWH(position.dx, position.dy, cardWidth, cardHeight);

  @override
  AttachmentItem movedBy(Offset delta) =>
      AttachmentItem(position: position + delta, path: path, filename: filename);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'attachment',
        'x': position.dx,
        'y': position.dy,
        'path': path,
        'filename': filename,
      };
}

final class LinkItem extends WhiteboardItem {
  final Offset position;
  final String url;
  final String label;

  static const double cardWidth = 280.0;
  static const double cardHeight = 72.0;

  const LinkItem({
    required this.position,
    required this.url,
    required this.label,
  });

  @override
  Rect get bounds =>
      Rect.fromLTWH(position.dx, position.dy, cardWidth, cardHeight);

  @override
  LinkItem movedBy(Offset delta) =>
      LinkItem(position: position + delta, url: url, label: label);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'link',
        'x': position.dx,
        'y': position.dy,
        'url': url,
        'label': label,
      };
}

final class VideoItem extends WhiteboardItem {
  final Offset position;
  final String path;
  final String filename;
  final double width;
  final double height;

  const VideoItem({
    required this.position,
    required this.path,
    required this.filename,
    this.width = 400.0,
    this.height = 260.0,
  });

  @override
  Rect get bounds => Rect.fromLTWH(position.dx, position.dy, width, height);

  @override
  VideoItem movedBy(Offset delta) => VideoItem(
        position: position + delta,
        path: path,
        filename: filename,
        width: width,
        height: height,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'video',
        'x': position.dx,
        'y': position.dy,
        'path': path,
        'filename': filename,
        'width': width,
        'height': height,
      };
}

final class PrintoutItem extends WhiteboardItem {
  final Offset position;
  final String path;
  final String filename;
  final double width;
  final double height;

  const PrintoutItem({
    required this.position,
    required this.path,
    required this.filename,
    this.width = 420.0,
    this.height = 594.0,
  });

  String get extension => filename.contains('.')
      ? filename.split('.').last.toLowerCase()
      : '';

  @override
  Rect get bounds => Rect.fromLTWH(position.dx, position.dy, width, height);

  @override
  PrintoutItem movedBy(Offset delta) => PrintoutItem(
        position: position + delta,
        path: path,
        filename: filename,
        width: width,
        height: height,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'printout',
        'x': position.dx,
        'y': position.dy,
        'path': path,
        'filename': filename,
        'width': width,
        'height': height,
      };
}

// ── Math graph item ────────────────────────────────────────────────────────

enum MathGraphType {
  xyGraph,
  xyzGraph,
  numberLine,
  unitCircle,
  polarGraph,
  vennDiagram,
}

final class MathGraphItem extends WhiteboardItem {
  final Offset position;
  final MathGraphType graphType;
  final double width;
  final double height;

  MathGraphItem({
    required this.position,
    required this.graphType,
    double? width,
    double? height,
  })  : width = width ?? _defaultW(graphType),
        height = height ?? _defaultH(graphType);

  static double _defaultW(MathGraphType t) =>
      t == MathGraphType.numberLine ? 500.0 : 400.0;

  static double _defaultH(MathGraphType t) => switch (t) {
        MathGraphType.numberLine => 100.0,
        MathGraphType.vennDiagram => 300.0,
        _ => 400.0,
      };

  @override
  Rect get bounds => Rect.fromLTWH(position.dx, position.dy, width, height);

  @override
  MathGraphItem movedBy(Offset delta) => MathGraphItem(
        position: position + delta,
        graphType: graphType,
        width: width,
        height: height,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'mathGraph',
        'x': position.dx,
        'y': position.dy,
        'graphType': graphType.name,
        'width': width,
        'height': height,
      };
}

// ── Color helpers ──────────────────────────────────────────────────────────

int _colorToInt(Color c) =>
    ((c.a * 255).round() << 24) |
    ((c.r * 255).round() << 16) |
    ((c.g * 255).round() << 8) |
    (c.b * 255).round();

Color _colorFromInt(int v) => Color.fromARGB(
    (v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
