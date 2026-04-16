import 'package:flutter/material.dart';
import '../models/stroke.dart';
import '../models/whiteboard_item.dart';

export '../models/whiteboard_item.dart';

enum BackgroundStyle { blank, dots, grid }

class WhiteboardPainter extends CustomPainter {
  final List<WhiteboardItem> items;
  final Stroke? activeStroke;
  final BackgroundStyle backgroundStyle;
  final TransformationController? transformationController;
  final Size? screenSize;
  final int? selectedIndex;

  WhiteboardPainter({
    required this.items,
    this.activeStroke,
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
    for (final item in items) {
      switch (item) {
        case StrokeItem(:final stroke):
          _drawStroke(canvas, stroke);
        case TextItem():
          _drawText(canvas, item);
        case StickyNoteItem():
          _drawStickyNote(canvas, item);
      }
    }
    if (activeStroke != null) _drawStroke(canvas, activeStroke!);
    if (selectedIndex != null && selectedIndex! < items.length) {
      _drawSelection(canvas, items[selectedIndex!]);
    }
  }

  void _drawSelection(Canvas canvas, WhiteboardItem item) {
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

  void _drawStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    switch (stroke.tool) {
      case DrawingTool.shape:
        _drawShape(canvas, stroke);
        return;
      case DrawingTool.frame:
        _drawFrame(canvas, stroke);
        return;
      default:
        break;
    }

    final isHighlighter = stroke.tool == DrawingTool.highlighter;
    final isEraser = stroke.tool == DrawingTool.eraser;

    final paint = Paint()
      ..color = isEraser
          ? Colors.white
          : isHighlighter
              ? stroke.color.withAlpha(90)
              : stroke.color
      ..strokeWidth = isHighlighter ? stroke.strokeWidth * 3.5 : stroke.strokeWidth
      ..strokeCap = isHighlighter ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, paint.strokeWidth / 2,
          paint..style = PaintingStyle.fill);
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

  void _drawShape(Canvas canvas, Stroke stroke) {
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

  void _drawFrame(Canvas canvas, Stroke stroke) {
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

  void _drawText(Canvas canvas, TextItem item) {
    final tp = TextPainter(
      text: TextSpan(
        text: item.text,
        style: TextStyle(color: item.color, fontSize: item.fontSize),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: 480);
    tp.paint(canvas, item.position);
  }

  void _drawStickyNote(Canvas canvas, StickyNoteItem item) {
    const w = 200.0, h = 160.0;
    final x = item.position.dx, y = item.position.dy;

    // shadow
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

  @override
  bool shouldRepaint(WhiteboardPainter old) => true;
}
