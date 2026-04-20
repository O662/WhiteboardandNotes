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
            fontWeight: (json['bold'] as bool? ?? false) ? FontWeight.bold : FontWeight.normal,
            fontStyle: (json['italic'] as bool? ?? false) ? FontStyle.italic : FontStyle.normal,
            fontFamily: json['fontFamily'] as String? ?? '',
            underline: json['underline'] as bool? ?? false,
            strikethrough: json['strikethrough'] as bool? ?? false,
            textAlign: TextAlign.values.firstWhere(
              (a) => a.name == (json['textAlign'] as String? ?? 'left'),
              orElse: () => TextAlign.left,
            ),
            indentLevel: json['indentLevel'] as int? ?? 0,
            bullet: json['bullet'] as bool? ?? false,
            lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.2,
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
        'shape' => ShapeItem(
            position: Offset((json['x'] as num).toDouble(),
                (json['y'] as num).toDouble()),
            shapeType: ShapeType.values
                .firstWhere((t) => t.name == json['shapeType']),
            width: (json['width'] as num).toDouble(),
            height: (json['height'] as num).toDouble(),
            strokeColor: _colorFromInt(json['strokeColor'] as int),
            strokeWidth: (json['strokeWidth'] as num).toDouble(),
            filled: json['filled'] as bool? ?? false,
            fillColor: _colorFromInt(
                json['fillColor'] as int? ?? 0x00000000),
          ),
        'frame' => FrameItem(
            position: Offset((json['x'] as num).toDouble(),
                (json['y'] as num).toDouble()),
            frameType: FrameType.values
                .firstWhere((t) => t.name == json['frameType']),
            background: FrameBackground.values
                .firstWhere((b) => b.name == json['background'],
                    orElse: () => FrameBackground.blank),
            label: json['label'] as String?,
            width: (json['width'] as num).toDouble(),
            height: (json['height'] as num).toDouble(),
          ),
        'checklist' => ChecklistItem(
            position: Offset((json['x'] as num).toDouble(),
                (json['y'] as num).toDouble()),
            title: json['title'] as String? ?? 'Checklist',
            entries: (json['entries'] as List? ?? [])
                .map((e) => ChecklistEntry.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
        'dateTime' => DateTimeItem(
            position: Offset((json['x'] as num).toDouble(),
                (json['y'] as num).toDouble()),
            mode: DateTimeMode.values.firstWhere(
                (m) => m.name == (json['mode'] as String? ?? 'time'),
                orElse: () => DateTimeMode.time),
            isLive: json['isLive'] as bool? ?? true,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
                json['createdAt'] as int? ?? 0),
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
  final FontWeight fontWeight;
  final FontStyle fontStyle;
  final String fontFamily;
  final bool underline;
  final bool strikethrough;
  final TextAlign textAlign;
  final int indentLevel;
  final bool bullet;
  final double lineHeight;

  const TextItem({
    required this.position,
    required this.text,
    required this.color,
    this.fontSize = 20.0,
    this.fontWeight = FontWeight.normal,
    this.fontStyle = FontStyle.normal,
    this.fontFamily = '',
    this.underline = false,
    this.strikethrough = false,
    this.textAlign = TextAlign.left,
    this.indentLevel = 0,
    this.bullet = false,
    this.lineHeight = 1.2,
  });

  static const double indentStep = 24.0;

  @override
  Rect get bounds {
    final indent = indentLevel * indentStep + (bullet ? 20.0 : 0.0);
    final approxW = (text.length * fontSize * 0.55 + 16 + indent).clamp(40.0, 480.0);
    final lineCount = '\n'.allMatches(text).length + 1;
    final approxH = fontSize * lineHeight * lineCount + 8;
    return Rect.fromLTWH(position.dx, position.dy, approxW, approxH);
  }

  @override
  TextItem movedBy(Offset delta) => TextItem(
        position: position + delta,
        text: text,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        fontFamily: fontFamily,
        underline: underline,
        strikethrough: strikethrough,
        textAlign: textAlign,
        indentLevel: indentLevel,
        bullet: bullet,
        lineHeight: lineHeight,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'text',
        'x': position.dx,
        'y': position.dy,
        'text': text,
        'color': _colorToInt(color),
        'fontSize': fontSize,
        'bold': fontWeight == FontWeight.bold,
        'italic': fontStyle == FontStyle.italic,
        'fontFamily': fontFamily,
        'underline': underline,
        'strikethrough': strikethrough,
        'textAlign': textAlign.name,
        'indentLevel': indentLevel,
        'bullet': bullet,
        'lineHeight': lineHeight,
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

// ── Shape item ─────────────────────────────────────────────────────────────

enum ShapeType {
  rectangle,
  ellipse,
  triangle,
  diamond,
  star,
  hexagon,
  arrow,
  line,
}

final class ShapeItem extends WhiteboardItem {
  final Offset position;
  final ShapeType shapeType;
  final double width;
  final double height;
  final Color strokeColor;
  final double strokeWidth;
  final bool filled;
  final Color fillColor;

  const ShapeItem({
    required this.position,
    required this.shapeType,
    required this.width,
    required this.height,
    required this.strokeColor,
    this.strokeWidth = 2.0,
    this.filled = false,
    this.fillColor = const Color(0x00000000),
  });

  static String labelFor(ShapeType t) => switch (t) {
        ShapeType.rectangle => 'Rectangle',
        ShapeType.ellipse => 'Ellipse',
        ShapeType.triangle => 'Triangle',
        ShapeType.diamond => 'Diamond',
        ShapeType.star => 'Star',
        ShapeType.hexagon => 'Hexagon',
        ShapeType.arrow => 'Arrow',
        ShapeType.line => 'Line',
      };

  static double defaultWidth(ShapeType t) => switch (t) {
        ShapeType.arrow => 300,
        ShapeType.line => 300,
        _ => 200,
      };

  static double defaultHeight(ShapeType t) => switch (t) {
        ShapeType.arrow => 140,
        ShapeType.line => 0,
        _ => 200,
      };

  @override
  Rect get bounds => shapeType == ShapeType.line
      ? Rect.fromLTWH(position.dx, position.dy - strokeWidth / 2,
          width, strokeWidth + 8)
      : Rect.fromLTWH(position.dx, position.dy, width, height);

  @override
  ShapeItem movedBy(Offset delta) => ShapeItem(
        position: position + delta,
        shapeType: shapeType,
        width: width,
        height: height,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
        filled: filled,
        fillColor: fillColor,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'shape',
        'x': position.dx,
        'y': position.dy,
        'shapeType': shapeType.name,
        'width': width,
        'height': height,
        'strokeColor': _colorToInt(strokeColor),
        'strokeWidth': strokeWidth,
        'filled': filled,
        'fillColor': _colorToInt(fillColor),
      };
}

// ── Frame item ─────────────────────────────────────────────────────────────

enum FrameType {
  a4Portrait,
  a4Landscape,
  letter,
  letterLandscape,
  ratio16x9,
  ratio4x3,
  ratio1x1,
  mobile,
  tablet,
  desktop,
  noteLined,
  noteBlank,
  noteDotted,
  noteGrid,
  graphPaper,
}

enum FrameBackground { blank, lined, dotted, grid, graphPaper }

final class FrameItem extends WhiteboardItem {
  final Offset position;
  final double width;
  final double height;
  final FrameType frameType;
  final FrameBackground background;
  final String label;

  FrameItem({
    required this.position,
    required this.frameType,
    double? width,
    double? height,
    FrameBackground? background,
    String? label,
  })  : width = width ?? defaultWidth(frameType),
        height = height ?? defaultHeight(frameType),
        background = background ?? defaultBackground(frameType),
        label = label ?? labelFor(frameType);

  static double defaultWidth(FrameType t) => switch (t) {
        FrameType.a4Portrait => 595,
        FrameType.a4Landscape => 842,
        FrameType.letter => 612,
        FrameType.letterLandscape => 792,
        FrameType.ratio16x9 => 960,
        FrameType.ratio4x3 => 800,
        FrameType.ratio1x1 => 600,
        FrameType.mobile => 390,
        FrameType.tablet => 768,
        FrameType.desktop => 1280,
        FrameType.noteLined ||
        FrameType.noteBlank ||
        FrameType.noteDotted ||
        FrameType.noteGrid =>
          595,
        FrameType.graphPaper => 600,
      };

  static double defaultHeight(FrameType t) => switch (t) {
        FrameType.a4Portrait => 842,
        FrameType.a4Landscape => 595,
        FrameType.letter => 792,
        FrameType.letterLandscape => 612,
        FrameType.ratio16x9 => 540,
        FrameType.ratio4x3 => 600,
        FrameType.ratio1x1 => 600,
        FrameType.mobile => 844,
        FrameType.tablet => 1024,
        FrameType.desktop => 800,
        FrameType.noteLined ||
        FrameType.noteBlank ||
        FrameType.noteDotted ||
        FrameType.noteGrid =>
          842,
        FrameType.graphPaper => 600,
      };

  static FrameBackground defaultBackground(FrameType t) => switch (t) {
        FrameType.noteLined => FrameBackground.lined,
        FrameType.noteDotted => FrameBackground.dotted,
        FrameType.noteGrid => FrameBackground.grid,
        FrameType.graphPaper => FrameBackground.graphPaper,
        _ => FrameBackground.blank,
      };

  static String labelFor(FrameType t) => switch (t) {
        FrameType.a4Portrait => 'A4',
        FrameType.a4Landscape => 'A4 Landscape',
        FrameType.letter => 'Letter',
        FrameType.letterLandscape => 'Letter Landscape',
        FrameType.ratio16x9 => '16 : 9',
        FrameType.ratio4x3 => '4 : 3',
        FrameType.ratio1x1 => '1 : 1',
        FrameType.mobile => 'Mobile',
        FrameType.tablet => 'Tablet',
        FrameType.desktop => 'Desktop',
        FrameType.noteLined => 'Note — Lined',
        FrameType.noteBlank => 'Note — Blank',
        FrameType.noteDotted => 'Note — Dotted',
        FrameType.noteGrid => 'Note — Grid',
        FrameType.graphPaper => 'Graph Paper',
      };

  @override
  Rect get bounds =>
      Rect.fromLTWH(position.dx, position.dy - 28, width, height + 28);

  @override
  FrameItem movedBy(Offset delta) => FrameItem(
        position: position + delta,
        frameType: frameType,
        width: width,
        height: height,
        background: background,
        label: label,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'frame',
        'x': position.dx,
        'y': position.dy,
        'frameType': frameType.name,
        'background': background.name,
        'label': label,
        'width': width,
        'height': height,
      };
}

// ── Checklist item ─────────────────────────────────────────────────────────

class ChecklistEntry {
  final String text;
  final bool checked;
  const ChecklistEntry({required this.text, this.checked = false});

  ChecklistEntry copyWith({String? text, bool? checked}) =>
      ChecklistEntry(text: text ?? this.text, checked: checked ?? this.checked);

  Map<String, dynamic> toJson() => {'text': text, 'checked': checked};

  static ChecklistEntry fromJson(Map<String, dynamic> j) =>
      ChecklistEntry(text: j['text'] as String, checked: j['checked'] as bool? ?? false);
}

final class ChecklistItem extends WhiteboardItem {
  final Offset position;
  final List<ChecklistEntry> entries;
  final String title;

  static const double cardWidth = 240.0;

  const ChecklistItem({
    required this.position,
    this.entries = const [],
    this.title = 'Checklist',
  });

  double get _cardHeight => (46.0 + entries.length * 36.0 + 40.0).clamp(80.0, 500.0);

  @override
  Rect get bounds => Rect.fromLTWH(position.dx, position.dy, cardWidth, _cardHeight);

  ChecklistItem withEntries(List<ChecklistEntry> newEntries) =>
      ChecklistItem(position: position, entries: newEntries, title: title);

  @override
  ChecklistItem movedBy(Offset delta) =>
      ChecklistItem(position: position + delta, entries: entries, title: title);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'checklist',
        'x': position.dx,
        'y': position.dy,
        'title': title,
        'entries': entries.map((e) => e.toJson()).toList(),
      };
}

// ── DateTime display item ───────────────────────────────────────────────────

enum DateTimeMode { time, date, datetime }

final class DateTimeItem extends WhiteboardItem {
  final Offset position;
  final DateTimeMode mode;
  final bool isLive;
  final DateTime createdAt;

  const DateTimeItem({
    required this.position,
    required this.mode,
    required this.isLive,
    required this.createdAt,
  });

  static double widthFor(DateTimeMode m) =>
      m == DateTimeMode.datetime ? 220.0 : 180.0;
  static double heightFor(DateTimeMode m) =>
      m == DateTimeMode.datetime ? 104.0 : 76.0;

  @override
  Rect get bounds =>
      Rect.fromLTWH(position.dx, position.dy, widthFor(mode), heightFor(mode));

  @override
  DateTimeItem movedBy(Offset delta) => DateTimeItem(
        position: position + delta,
        mode: mode,
        isLive: isLive,
        createdAt: createdAt,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'dateTime',
        'x': position.dx,
        'y': position.dy,
        'mode': mode.name,
        'isLive': isLive,
        'createdAt': createdAt.millisecondsSinceEpoch,
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
