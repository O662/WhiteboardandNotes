import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/stroke.dart';
import '../models/whiteboard_item.dart';

export '../models/whiteboard_item.dart';

enum BackgroundStyle { blank, dots, grid }

class WhiteboardPainter extends CustomPainter {
  final List<WhiteboardItem> items;
  final BackgroundStyle backgroundStyle;
  final TransformationController? transformationController;
  final Size? screenSize;
  final int? selectedIndex;

  WhiteboardPainter({
    required this.items,
    this.backgroundStyle = BackgroundStyle.dots,
    this.transformationController,
    this.screenSize,
    this.selectedIndex,
  }) : super(repaint: transformationController);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    _drawBackground(canvas);
    // Frame items sit below the ink layer so strokes can be drawn on top.
    for (final item in items) {
      if (item is FrameItem) _drawFrameItem(canvas, item);
    }
    for (final item in items) {
      switch (item) {
        case StrokeItem():
          break; // rendered in AnnotationPainter above the rich-item overlay
        case TextItem():
          break; // rendered in the rich-item overlay so it respects z-order with images
        case StickyNoteItem():
          _drawStickyNote(canvas, item);
        case StickyNoteStackItem():
          _drawStickyNoteStack(canvas, item);
        case ShapeItem():
          _drawShapeItem(canvas, item);
        case FrameItem():
          break; // drawn before this loop
        case ImageItem() ||
              TableItem() ||
              AttachmentItem() ||
              LinkItem() ||
              VideoItem() ||
              PrintoutItem() ||
              MathGraphItem() ||
              ChecklistItem() ||
              DateTimeItem() ||
              PlaceholderItem() ||
              RecordingItem():
          break; // rendered as Flutter widget in the rich-item overlay
      }
    }
    if (selectedIndex != null && selectedIndex! < items.length) {
      final sel = items[selectedIndex!];
      // Rich items draw their own selection border in the overlay widget
      // Stroke selection is drawn in AnnotationPainter
      if (sel case StickyNoteItem() || StickyNoteStackItem() || FrameItem() || ShapeItem()) {
        _drawSelection(canvas, sel);
      }
    }
  }

  static void _drawSelection(Canvas canvas, WhiteboardItem item) {
    final rect = item.bounds.inflate(6);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    canvas.drawRRect(rrect,
        Paint()
          ..color = const Color(0x1A2979FF)
          ..style = PaintingStyle.fill);
    canvas.drawRRect(rrect,
        Paint()
          ..color = const Color(0xFF2979FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    const h = 8.0;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      final r = Rect.fromCenter(center: corner, width: h, height: h);
      canvas.drawRect(r, Paint()..color = Colors.white);
      canvas.drawRect(
          r,
          Paint()
            ..color = const Color(0xFF2979FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  /// Computes the visible rect in canvas space by inverting the view matrix.
  /// Falls back to getLocalClipBounds() only if the controller isn't wired up.
  Rect _visibleRect(Canvas canvas) {
    final tc = transformationController;
    final ss = screenSize;
    if (tc != null && ss != null) {
      final inverse = Matrix4.inverted(tc.value);
      final tl = MatrixUtils.transformPoint(inverse, Offset.zero);
      final br = MatrixUtils.transformPoint(inverse, Offset(ss.width, ss.height));
      return Rect.fromPoints(tl, br).inflate(80);
    }
    final clip = canvas.getLocalClipBounds();
    return clip.isEmpty ? const Rect.fromLTWH(0, 0, 2000, 2000) : clip;
  }

  void _drawBackground(Canvas canvas) {
    if (backgroundStyle == BackgroundStyle.blank) return;
    const spacing = 40.0;
    final rect = _visibleRect(canvas);
    final startX = (rect.left / spacing).floor() * spacing;
    final startY = (rect.top / spacing).floor() * spacing;

    if (backgroundStyle == BackgroundStyle.dots) {
      final paint = Paint()
        ..color = const Color(0xFFCCCCCC)
        ..style = PaintingStyle.fill;
      for (double x = startX; x <= rect.right; x += spacing) {
        for (double y = startY; y <= rect.bottom; y += spacing) {
          canvas.drawCircle(Offset(x, y), 1.5, paint);
        }
      }
    } else {
      final paint = Paint()
        ..color = const Color(0xFFDDDDDD)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;
      for (double x = startX; x <= rect.right; x += spacing) {
        canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
      }
      for (double y = startY; y <= rect.bottom; y += spacing) {
        canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
      }
    }
  }

  void _drawFrameItem(Canvas canvas, FrameItem item) {
    final rect = Rect.fromLTWH(
        item.position.dx, item.position.dy, item.width, item.height);

    // Drop shadow
    canvas.drawRect(
      rect.translate(3, 4),
      Paint()
        ..color = Colors.black.withAlpha(18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // White background
    canvas.drawRect(rect, Paint()..color = Colors.white);

    // Template pattern (clipped to frame)
    canvas.save();
    canvas.clipRect(rect);
    _drawFrameTemplate(canvas, item, rect);
    canvas.restore();

    // Border
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFFBBBBBB)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Label above the frame
    final tp = TextPainter(
      text: TextSpan(
        text: item.label,
        style: const TextStyle(
          color: Color(0xFF666666),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(item.position.dx, item.position.dy - 22));
  }

  void _drawFrameTemplate(Canvas canvas, FrameItem item, Rect rect) {
    switch (item.background) {
      case FrameBackground.blank:
        return;
      case FrameBackground.lined:
        _drawLinedTemplate(canvas, rect);
      case FrameBackground.dotted:
        _drawDottedTemplate(canvas, rect);
      case FrameBackground.grid:
        _drawGridTemplate(canvas, rect);
      case FrameBackground.graphPaper:
        _drawGraphPaperTemplate(canvas, rect);
    }
  }

  void _drawLinedTemplate(Canvas canvas, Rect rect) {
    const spacing = 32.0;
    // Pink margin line
    canvas.drawLine(
      Offset(rect.left + 64, rect.top),
      Offset(rect.left + 64, rect.bottom),
      Paint()
        ..color = const Color(0xFFFFCDD2)
        ..strokeWidth = 1.2,
    );
    // Ruled lines
    final linePaint = Paint()
      ..color = const Color(0xFFB0C4DE)
      ..strokeWidth = 0.8;
    double y = rect.top + 48;
    while (y <= rect.bottom - 4) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), linePaint);
      y += spacing;
    }
  }

  void _drawDottedTemplate(Canvas canvas, Rect rect) {
    const spacing = 28.0;
    final paint = Paint()
      ..color = const Color(0xFFAAAAAA)
      ..style = PaintingStyle.fill;
    final startX = rect.left + (rect.width % spacing) / 2;
    final startY = rect.top + (rect.height % spacing) / 2;
    for (double x = startX; x <= rect.right; x += spacing) {
      for (double y = startY; y <= rect.bottom; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.8, paint);
      }
    }
  }

  void _drawGridTemplate(Canvas canvas, Rect rect) {
    const spacing = 28.0;
    final paint = Paint()
      ..color = const Color(0xFFCCDDEE)
      ..strokeWidth = 0.6;
    for (double x = rect.left; x <= rect.right; x += spacing) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }
    for (double y = rect.top; y <= rect.bottom; y += spacing) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
  }

  void _drawGraphPaperTemplate(Canvas canvas, Rect rect) {
    const minor = 10.0;
    const major = 50.0;
    final minorPaint = Paint()
      ..color = const Color(0xFFCCEECC)
      ..strokeWidth = 0.4;
    final majorPaint = Paint()
      ..color = const Color(0xFF88CC88)
      ..strokeWidth = 0.9;
    for (double x = rect.left; x <= rect.right; x += minor) {
      final p = (x - rect.left) % major < 0.5 ? majorPaint : minorPaint;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), p);
    }
    for (double y = rect.top; y <= rect.bottom; y += minor) {
      final p = (y - rect.top) % major < 0.5 ? majorPaint : minorPaint;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), p);
    }
  }

  void _drawShapeItem(Canvas canvas, ShapeItem item) {
    final rect = Rect.fromLTWH(
        item.position.dx, item.position.dy, item.width, item.height);

    final strokePaint = Paint()
      ..color = item.strokeColor
      ..strokeWidth = item.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final fillPaint = item.filled
        ? (Paint()
          ..color = item.fillColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true)
        : null;

    void draw(Path? path) {
      if (path != null) {
        if (fillPaint != null) canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
      }
    }

    switch (item.shapeType) {
      case ShapeType.rectangle:
        if (fillPaint != null) canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, strokePaint);
      case ShapeType.ellipse:
        if (fillPaint != null) canvas.drawOval(rect, fillPaint);
        canvas.drawOval(rect, strokePaint);
      case ShapeType.triangle:
        draw(_trianglePath(rect));
      case ShapeType.diamond:
        draw(_diamondPath(rect));
      case ShapeType.star:
        draw(_starPath(rect));
      case ShapeType.hexagon:
        draw(_hexagonPath(rect));
      case ShapeType.arrow:
        draw(_arrowPath(rect));
      case ShapeType.line:
        canvas.drawLine(
          Offset(rect.left, rect.top),
          Offset(rect.right, rect.top),
          strokePaint..strokeCap = StrokeCap.round,
        );
    }
  }

  Path _trianglePath(Rect r) => Path()
    ..moveTo(r.center.dx, r.top)
    ..lineTo(r.right, r.bottom)
    ..lineTo(r.left, r.bottom)
    ..close();

  Path _diamondPath(Rect r) => Path()
    ..moveTo(r.center.dx, r.top)
    ..lineTo(r.right, r.center.dy)
    ..lineTo(r.center.dx, r.bottom)
    ..lineTo(r.left, r.center.dy)
    ..close();

  Path _starPath(Rect r) {
    final cx = r.center.dx;
    final cy = r.center.dy;
    final outer = math.min(r.width, r.height) / 2;
    final inner = outer * 0.42;
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final angle = (i * math.pi / 5) - math.pi / 2;
      final radius = i.isEven ? outer : inner;
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    return path..close();
  }

  Path _hexagonPath(Rect r) {
    final cx = r.center.dx;
    final cy = r.center.dy;
    final rx = r.width / 2;
    final ry = r.height / 2;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi / 3) - math.pi / 6;
      final x = cx + rx * math.cos(angle);
      final y = cy + ry * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    return path..close();
  }

  Path _arrowPath(Rect r) {
    final headW = r.width * 0.38;
    final shaftH = r.height * 0.42;
    final shaftTop = r.top + (r.height - shaftH) / 2;
    final shaftBot = shaftTop + shaftH;
    return Path()
      ..moveTo(r.left, shaftTop)
      ..lineTo(r.right - headW, shaftTop)
      ..lineTo(r.right - headW, r.top)
      ..lineTo(r.right, r.center.dy)
      ..lineTo(r.right - headW, r.bottom)
      ..lineTo(r.right - headW, shaftBot)
      ..lineTo(r.left, shaftBot)
      ..close();
  }

  static void _drawStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    switch (stroke.tool) {
      case DrawingTool.shape:
        _drawShape(canvas, stroke);
        return;
      case DrawingTool.frame:
        _drawFrame(canvas, stroke);
        return;
      case DrawingTool.ruler:
        if (stroke.points.length >= 2) {
          canvas.drawLine(
            stroke.points.first,
            stroke.points.last,
            Paint()
              ..color = stroke.color
              ..strokeWidth = stroke.strokeWidth
              ..strokeCap = StrokeCap.round
              ..isAntiAlias = true,
          );
        }
        return;
      case DrawingTool.lassoSelect:
        if (stroke.points.length >= 2) {
          final path = Path()
            ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
          for (final p in stroke.points.skip(1)) {
            path.lineTo(p.dx, p.dy);
          }
          path.close();
          canvas.drawPath(
              path,
              Paint()
                ..color = const Color(0x221E88E5)
                ..style = PaintingStyle.fill);
          canvas.drawPath(
              path,
              Paint()
                ..color = const Color(0xFF1E88E5)
                ..strokeWidth = 1.5
                ..style = PaintingStyle.stroke
                ..isAntiAlias = true);
        }
        return;
      case DrawingTool.rectSelect:
        if (stroke.points.length >= 2) {
          final rect = Rect.fromPoints(stroke.points.first, stroke.points.last);
          canvas.drawRect(
              rect,
              Paint()
                ..color = const Color(0x221E88E5)
                ..style = PaintingStyle.fill);
          canvas.drawRect(
              rect,
              Paint()
                ..color = const Color(0xFF1E88E5)
                ..strokeWidth = 1.5
                ..style = PaintingStyle.stroke
                ..isAntiAlias = true);
        }
        return;
      default:
        break;
    }

    final isHighlighter = stroke.tool == DrawingTool.highlighter;
    final isEraser = stroke.tool == DrawingTool.eraser;

    final paint = Paint()
      ..color = isHighlighter ? stroke.color.withAlpha(90) : stroke.color
      ..strokeWidth = isHighlighter ? stroke.strokeWidth * 3.5 : stroke.strokeWidth
      ..strokeCap = isHighlighter ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    if (isEraser) paint.blendMode = BlendMode.clear;

    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, paint.strokeWidth / 2,
          paint
            ..style = PaintingStyle.fill
            ..blendMode = isEraser ? BlendMode.clear : BlendMode.srcOver);
      return;
    }

    final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length - 1; i++) {
      final mid = Offset(
        (stroke.points[i].dx + stroke.points[i + 1].dx) / 2,
        (stroke.points[i].dy + stroke.points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(
          stroke.points[i].dx, stroke.points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    canvas.drawPath(path, paint);
  }

  static void _drawShape(Canvas canvas, Stroke stroke) {
    if (stroke.points.length < 2) return;
    final rect = Rect.fromPoints(stroke.points.first, stroke.points.last);
    canvas.drawRect(
      rect,
      Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );
  }

  static void _drawFrame(Canvas canvas, Stroke stroke) {
    if (stroke.points.length < 2) return;
    final rect = Rect.fromPoints(stroke.points.first, stroke.points.last);

    const labelH = 24.0;
    const labelW = 72.0;
    final labelRect =
        Rect.fromLTWH(rect.left, rect.top - labelH, labelW, labelH);

    canvas.drawRect(labelRect, Paint()..color = const Color(0xFF9E9E9E));
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF9E9E9E)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: 'Frame',
        style: TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(rect.left + 6, rect.top - labelH + 4));
  }

  void _drawStickyNote(Canvas canvas, StickyNoteItem item) {
    const w = 200.0, h = 160.0;
    final x = item.position.dx, y = item.position.dy;

    canvas.drawRRect(
      RRect.fromLTRBR(x + 3, y + 3, x + w + 3, y + h + 3,
          const Radius.circular(4)),
      Paint()
        ..color = Colors.black.withAlpha(28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // body
    canvas.drawRRect(
      RRect.fromLTRBR(x, y, x + w, y + h, const Radius.circular(4)),
      Paint()..color = item.color,
    );

    // header stripe
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(x, y, x + w, y + 28,
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4)),
      Paint()..color = Colors.black.withAlpha(30),
    );

    // text
    final tp = TextPainter(
      text: TextSpan(
        text: item.text,
        style: const TextStyle(
            color: Color(0xFF333333), fontSize: 14, height: 1.45),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: w - 16);
    tp.paint(canvas, Offset(x + 8, y + 36));
  }

  void _drawStickyNoteStack(Canvas canvas, StickyNoteStackItem item) {
    const w = 200.0, h = 160.0;
    final x = item.position.dx, y = item.position.dy;
    final hasNotes = item.notes.isNotEmpty;
    final topColor = item.displayColor;
    final backColor = topColor.withAlpha(170);

    final layerCount = hasNotes ? item.notes.length.clamp(1, 3) : 3;

    for (int i = layerCount - 1; i >= 0; i--) {
      final dx = (layerCount - 1 - i) * 6.0;
      final dy = i * -5.0;
      final layerColor = i == 0
          ? topColor
          : (hasNotes && i < item.notes.length
              ? item.notes[i].color.withAlpha(170)
              : backColor);

      if (i == 0) {
        canvas.drawRRect(
          RRect.fromLTRBR(x + dx + 3, y + dy + 3, x + dx + w + 3,
              y + dy + h + 3, const Radius.circular(4)),
          Paint()
            ..color = Colors.black.withAlpha(28)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }

      canvas.drawRRect(
        RRect.fromLTRBR(
            x + dx, y + dy, x + dx + w, y + dy + h, const Radius.circular(4)),
        Paint()..color = layerColor,
      );

      if (i == 0) {
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(x + dx, y + dy, x + dx + w, y + dy + 28,
              topLeft: const Radius.circular(4),
              topRight: const Radius.circular(4)),
          Paint()..color = Colors.black.withAlpha(30),
        );

        if (hasNotes && item.notes.first.text.isNotEmpty) {
          final tp = TextPainter(
            text: TextSpan(
              text: item.notes.first.text,
              style: const TextStyle(color: Color(0xFF333333), fontSize: 14, height: 1.45),
            ),
            textDirection: TextDirection.ltr,
          );
          tp.layout(maxWidth: w - 16);
          tp.paint(canvas, Offset(x + dx + 8, y + dy + 36));
        } else if (!hasNotes) {
          final tp = TextPainter(
            text: const TextSpan(
              text: '↓ drag to create a note',
              style: TextStyle(
                  color: Color(0x99333333), fontSize: 11, fontStyle: FontStyle.italic),
            ),
            textDirection: TextDirection.ltr,
          );
          tp.layout(maxWidth: w - 16);
          tp.paint(canvas, Offset(x + dx + 8, y + dy + 36));
        }

        // Count badge
        if (item.notes.length > 1) {
          final badgeText = '+${item.notes.length - 1}';
          final bp = TextPainter(
            text: TextSpan(
              text: badgeText,
              style: const TextStyle(
                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
            ),
            textDirection: TextDirection.ltr,
          );
          bp.layout();
          final bw = bp.width + 12;
          final bx = x + dx + w - bw - 6;
          final by = y + dy + h - 20;
          canvas.drawRRect(
            RRect.fromLTRBR(bx, by, bx + bw, by + 16, const Radius.circular(8)),
            Paint()..color = Colors.black.withAlpha(100),
          );
          bp.paint(canvas, Offset(bx + 6, by + 3));
        }
      }
    }
  }

  @override
  bool shouldRepaint(WhiteboardPainter old) => true;
}

/// Paints strokes above the rich-item widget overlay so annotations always
/// appear on top of images, tables, graphs, and other embedded items.
class AnnotationPainter extends CustomPainter {
  final List<WhiteboardItem> items;
  final Stroke? activeStroke;
  final Matrix4 transformMatrix;
  final int? selectedIndex;

  AnnotationPainter({
    required this.items,
    required this.transformMatrix,
    this.activeStroke,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.transform(transformMatrix.storage);
    // saveLayer so eraser (BlendMode.clear) punches through annotation strokes
    // without affecting the items below.
    canvas.saveLayer(null, Paint());
    for (final item in items) {
      if (item is StrokeItem) WhiteboardPainter._drawStroke(canvas, item.stroke);
    }
    if (activeStroke != null) WhiteboardPainter._drawStroke(canvas, activeStroke!);
    canvas.restore();
    if (selectedIndex != null && selectedIndex! < items.length) {
      final sel = items[selectedIndex!];
      if (sel is StrokeItem) WhiteboardPainter._drawSelection(canvas, sel);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AnnotationPainter old) => true;
}
