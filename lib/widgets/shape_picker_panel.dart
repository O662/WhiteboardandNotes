import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/whiteboard_item.dart';

class ShapePickerPanel extends StatelessWidget {
  final void Function(ShapeType) onSelect;
  final VoidCallback? onDragStarted;
  const ShapePickerPanel({super.key, required this.onSelect, this.onDragStarted});

  static const _shapes = ShapeType.values;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(36),
            blurRadius: 24,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SHAPES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF999999),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: _shapes.map(_cell).toList(),
          ),
        ],
      ),
    );
  }

  Widget _cell(ShapeType type) {
    final inner = Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 36,
            child: CustomPaint(painter: _ShapeIconPainter(type: type)),
          ),
          const SizedBox(height: 4),
          Text(
            ShapeItem.labelFor(type),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333333),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    return Draggable<ShapeType>(
      data: type,
      onDragStarted: onDragStarted,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: CustomPaint(painter: _ShapeIconPainter(type: type)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: inner),
      child: InkWell(
        onTap: () => onSelect(type),
        borderRadius: BorderRadius.circular(10),
        child: inner,
      ),
    );
  }
}

class _ShapeIconPainter extends CustomPainter {
  final ShapeType type;
  const _ShapeIconPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 4.0;
    final rect = Rect.fromLTWH(pad, pad, size.width - pad * 2, size.height - pad * 2);
    final paint = Paint()
      ..color = const Color(0xFF444444)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (type) {
      case ShapeType.rectangle:
        canvas.drawRect(rect, paint);
      case ShapeType.ellipse:
        canvas.drawOval(rect, paint);
      case ShapeType.triangle:
        canvas.drawPath(_tri(rect), paint);
      case ShapeType.diamond:
        canvas.drawPath(_diamond(rect), paint);
      case ShapeType.star:
        canvas.drawPath(_star(rect), paint);
      case ShapeType.hexagon:
        canvas.drawPath(_hex(rect), paint);
      case ShapeType.arrow:
        canvas.drawPath(_arrow(rect), paint);
      case ShapeType.line:
        canvas.drawLine(
          Offset(rect.left, rect.center.dy),
          Offset(rect.right, rect.center.dy),
          paint..strokeWidth = 2.5,
        );
    }
  }

  Path _tri(Rect r) => Path()
    ..moveTo(r.center.dx, r.top)
    ..lineTo(r.right, r.bottom)
    ..lineTo(r.left, r.bottom)
    ..close();

  Path _diamond(Rect r) => Path()
    ..moveTo(r.center.dx, r.top)
    ..lineTo(r.right, r.center.dy)
    ..lineTo(r.center.dx, r.bottom)
    ..lineTo(r.left, r.center.dy)
    ..close();

  Path _star(Rect r) {
    final cx = r.center.dx;
    final cy = r.center.dy;
    final outer = math.min(r.width, r.height) / 2;
    final inner = outer * 0.42;
    final p = Path();
    for (int i = 0; i < 10; i++) {
      final a = (i * math.pi / 5) - math.pi / 2;
      final rad = i.isEven ? outer : inner;
      final pt = Offset(cx + rad * math.cos(a), cy + rad * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  Path _hex(Rect r) {
    final cx = r.center.dx;
    final cy = r.center.dy;
    final rx = r.width / 2;
    final ry = r.height / 2;
    final p = Path();
    for (int i = 0; i < 6; i++) {
      final a = (i * math.pi / 3) - math.pi / 6;
      final pt = Offset(cx + rx * math.cos(a), cy + ry * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  Path _arrow(Rect r) {
    final headW = r.width * 0.38;
    final shaftH = r.height * 0.42;
    final st = r.top + (r.height - shaftH) / 2;
    final sb = st + shaftH;
    return Path()
      ..moveTo(r.left, st)
      ..lineTo(r.right - headW, st)
      ..lineTo(r.right - headW, r.top)
      ..lineTo(r.right, r.center.dy)
      ..lineTo(r.right - headW, r.bottom)
      ..lineTo(r.right - headW, sb)
      ..lineTo(r.left, sb)
      ..close();
  }

  @override
  bool shouldRepaint(_ShapeIconPainter old) => type != old.type;
}

class ShapePreviewPainter extends CustomPainter {
  final ShapeType type;
  final Color strokeColor;
  final double strokeWidth;
  final bool filled;
  final Color fillColor;

  const ShapePreviewPainter({
    required this.type,
    required this.strokeColor,
    required this.strokeWidth,
    required this.filled,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final sp = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth.clamp(1.0, 4.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final fp = filled
        ? (Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true)
        : null;

    void draw(Path path) {
      if (fp != null) canvas.drawPath(path, fp);
      canvas.drawPath(path, sp);
    }

    final icon = _ShapeIconPainter(type: type);
    switch (type) {
      case ShapeType.rectangle:
        if (fp != null) canvas.drawRect(rect, fp);
        canvas.drawRect(rect, sp);
      case ShapeType.ellipse:
        if (fp != null) canvas.drawOval(rect, fp);
        canvas.drawOval(rect, sp);
      case ShapeType.triangle:
        draw(icon._tri(rect));
      case ShapeType.diamond:
        draw(icon._diamond(rect));
      case ShapeType.star:
        draw(icon._star(rect));
      case ShapeType.hexagon:
        draw(icon._hex(rect));
      case ShapeType.arrow:
        draw(icon._arrow(rect));
      case ShapeType.line:
        canvas.drawLine(rect.centerLeft, rect.centerRight,
            sp..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(ShapePreviewPainter old) =>
      type != old.type ||
      strokeColor != old.strokeColor ||
      strokeWidth != old.strokeWidth ||
      filled != old.filled ||
      fillColor != old.fillColor;
}
