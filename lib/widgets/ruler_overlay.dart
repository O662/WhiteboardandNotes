import 'dart:math' as math;

import 'package:flutter/material.dart';

enum _RulerDragMode { body, leftHandle, rightHandle }

enum _RulerUnit { mm, cm, inches }

class _RulerData {
  Offset center;
  double angle;
  double length;
  _RulerUnit unit;
  Color color;

  _RulerData({
    required this.center,
    this.angle = 0.0, // ignore: unused_element_parameter
    this.length = 320.0, // ignore: unused_element_parameter
    this.unit = _RulerUnit.cm, // ignore: unused_element_parameter
    this.color = const Color(0xFFF5ECC2), // ignore: unused_element_parameter
  });
}

class RulerOverlay extends StatefulWidget {
  const RulerOverlay({super.key});

  @override
  State<RulerOverlay> createState() => RulerOverlayState();
}

class RulerOverlayState extends State<RulerOverlay> {
  final List<_RulerData> _rulers = [];
  _RulerDragMode? _dragMode;
  int? _activeIdx;

  static const double _rulerH = 40.0;
  static const double _handleR = 13.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rulers.isEmpty) {
      final s = MediaQuery.of(context).size;
      _rulers.add(_RulerData(center: Offset(s.width / 2, s.height / 2)));
    }
  }

  void addRuler() {
    final s = MediaQuery.of(context).size;
    setState(() {
      _rulers.add(_RulerData(
        center: Offset(
          s.width / 2 + _rulers.length * 24,
          s.height / 2 + _rulers.length * 24,
        ),
      ));
    });
  }

  void clearRulers() => setState(() => _rulers.clear());

  Offset _leftEnd(_RulerData r) {
    final c = math.cos(r.angle), s = math.sin(r.angle);
    return Offset(r.center.dx - c * r.length / 2, r.center.dy - s * r.length / 2);
  }

  Offset _rightEnd(_RulerData r) {
    final c = math.cos(r.angle), s = math.sin(r.angle);
    return Offset(r.center.dx + c * r.length / 2, r.center.dy + s * r.length / 2);
  }

  bool _hitBody(Offset p, _RulerData r) {
    final cosA = math.cos(r.angle), sinA = math.sin(r.angle);
    final dx = p.dx - r.center.dx, dy = p.dy - r.center.dy;
    return (dx * cosA + dy * sinA).abs() <= r.length / 2 &&
        (-dx * sinA + dy * cosA).abs() <= _rulerH / 2 + 6;
  }

  bool _hitUnitBadge(Offset p, _RulerData r) {
    final cosA = math.cos(r.angle), sinA = math.sin(r.angle);
    final dx = p.dx - r.center.dx, dy = p.dy - r.center.dy;
    final localX = dx * cosA + dy * sinA;
    final localY = -dx * sinA + dy * cosA;
    return localX.abs() <= 14 && (localY - 12).abs() <= 7;
  }

  void _onPanStart(DragStartDetails d) {
    final p = d.localPosition;
    for (int i = _rulers.length - 1; i >= 0; i--) {
      final r = _rulers[i];
      if ((p - _leftEnd(r)).distance <= _handleR * 2.2) {
        setState(() { _activeIdx = i; _dragMode = _RulerDragMode.leftHandle; });
        return;
      }
      if ((p - _rightEnd(r)).distance <= _handleR * 2.2) {
        setState(() { _activeIdx = i; _dragMode = _RulerDragMode.rightHandle; });
        return;
      }
      if (_hitBody(p, r)) {
        setState(() { _activeIdx = i; _dragMode = _RulerDragMode.body; });
        return;
      }
    }
    _activeIdx = null;
    _dragMode = null;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragMode == null || _activeIdx == null) return;
    final delta = d.delta;
    final r = _rulers[_activeIdx!];
    setState(() {
      switch (_dragMode!) {
        case _RulerDragMode.body:
          r.center = r.center + delta;
        case _RulerDragMode.leftHandle:
          final nl = _leftEnd(r) + delta;
          final fr = _rightEnd(r);
          final v = fr - nl;
          final len = v.distance;
          if (len >= 60) {
            r.center = (nl + fr) / 2;
            r.angle = math.atan2(v.dy, v.dx);
            r.length = len;
          }
        case _RulerDragMode.rightHandle:
          final fl = _leftEnd(r);
          final nr = _rightEnd(r) + delta;
          final v = nr - fl;
          final len = v.distance;
          if (len >= 60) {
            r.center = (fl + nr) / 2;
            r.angle = math.atan2(v.dy, v.dx);
            r.length = len;
          }
      }
    });
  }

  void _showRulerContextMenu(BuildContext context, Offset globalPos, _RulerData r) {
    final screenSize = MediaQuery.of(context).size;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx, globalPos.dy,
        screenSize.width - globalPos.dx,
        screenSize.height - globalPos.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      color: Colors.white,
      items: [
        for (final unit in _RulerUnit.values)
          PopupMenuItem(
            value: 'unit_${unit.name}',
            child: Row(children: [
              SizedBox(
                width: 16,
                child: r.unit == unit
                    ? const Icon(Icons.check, size: 14, color: Colors.blue)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(switch (unit) {
                _RulerUnit.mm => 'mm',
                _RulerUnit.cm => 'cm',
                _RulerUnit.inches => 'inches',
              }),
            ]),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'color',
          child: Row(children: [
            Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: r.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Change Color'),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
            SizedBox(width: 10),
            Text('Delete Ruler', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
    ).then((value) {
      if (!context.mounted) return;
      if (value == null) return;
      if (value.startsWith('unit_')) {
        final unitName = value.substring(5);
        setState(() {
          r.unit = _RulerUnit.values.firstWhere((u) => u.name == unitName);
        });
      } else if (value == 'color') {
        _showColorPicker(context, r);
      } else if (value == 'delete') {
        setState(() => _rulers.remove(r));
      }
    });
  }

  void _showColorPicker(BuildContext context, _RulerData r) {
    const colors = [
      Color(0xFFF5ECC2), Color(0xFFCCE5FF), Color(0xFFCCF0CC),
      Color(0xFFFFCCCC), Color(0xFFFFE0B2), Color(0xFFF8F8F8),
      Color(0xFF8B6914), Color(0xFF1A3A5C),
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ruler Color',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: colors.map((c) => GestureDetector(
                  onTap: () {
                    setState(() => r.color = c);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: r.color == c ? Colors.blue : Colors.grey.shade300,
                        width: r.color == c ? 2.5 : 1,
                      ),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (d) {
          for (final r in _rulers) {
            if (_hitUnitBadge(d.localPosition, r)) {
              setState(() {
                r.unit = _RulerUnit.values[(r.unit.index + 1) % _RulerUnit.values.length];
              });
              return;
            }
          }
          for (final r in _rulers) {
            if (_hitBody(d.localPosition, r)) {
              _showRulerContextMenu(context, d.globalPosition, r);
              return;
            }
          }
        },
        onLongPressStart: (d) {
          for (final r in _rulers) {
            if (_hitBody(d.localPosition, r)) {
              _showRulerContextMenu(context, d.globalPosition, r);
              return;
            }
          }
        },
        onSecondaryTapUp: (d) {
          for (final r in _rulers) {
            if (_hitBody(d.localPosition, r)) {
              _showRulerContextMenu(context, d.globalPosition, r);
              return;
            }
          }
        },
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: (_) => setState(() { _dragMode = null; _activeIdx = null; }),
        onPanCancel: () => setState(() { _dragMode = null; _activeIdx = null; }),
        child: CustomPaint(
          painter: _RulerPainter(
            rulers: _rulers,
            rulerH: _rulerH,
            handleR: _handleR,
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final List<_RulerData> rulers;
  final double rulerH;
  final double handleR;

  const _RulerPainter({
    required this.rulers,
    required this.rulerH,
    required this.handleR,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in rulers) { _paintBody(canvas, r); }
    for (final r in rulers) { _paintHandles(canvas, r); }
  }

  void _paintBody(Canvas canvas, _RulerData r) {
    final halfLen = r.length / 2;
    final halfH = rulerH / 2;

    canvas.save();
    canvas.translate(r.center.dx, r.center.dy);
    canvas.rotate(r.angle);

    final bodyRect = Rect.fromLTRB(-halfLen, -halfH, halfLen, halfH);
    final rr = RRect.fromRectXY(bodyRect, 5, 5);

    canvas.drawRRect(rr.shift(const Offset(0, 2)),
        Paint()..color = const Color(0x35000000));
    canvas.drawRRect(rr, Paint()..color = r.color);
    canvas.drawRRect(
      RRect.fromRectXY(
          Rect.fromLTRB(-halfLen + 2, -halfH + 2, halfLen - 2, -halfH + 7), 3, 3),
      Paint()..color = const Color(0x55FFFFFF),
    );
    canvas.drawRRect(
        rr,
        Paint()
          ..color = const Color(0xFFB59A2A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // Tick marks (assumes 96 logical px per inch)
    const double ppi = 96.0;
    const double ppmm = ppi / 25.4;
    final double tinyPx;
    final int midMult, majorMult;
    final String unitName;
    switch (r.unit) {
      case _RulerUnit.mm:
        tinyPx = ppmm; midMult = 5; majorMult = 10; unitName = 'mm';
      case _RulerUnit.cm:
        tinyPx = ppmm; midMult = 5; majorMult = 10; unitName = 'cm';
      case _RulerUnit.inches:
        tinyPx = ppi / 16; midMult = 4; majorMult = 16; unitName = 'in';
    }

    final n = (r.length / tinyPx).ceil();
    final tickPaint = Paint()..strokeCap = StrokeCap.butt;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= n; i++) {
      final xFromLeft = i * tinyPx;
      if (xFromLeft > r.length) break;
      final x = xFromLeft - halfLen;
      final isMajor = i % majorMult == 0;
      final isMid = !isMajor && i % midMult == 0;
      final tH = isMajor ? halfH * 0.60 : isMid ? halfH * 0.40 : halfH * 0.22;
      final sw = isMajor ? 1.5 : isMid ? 1.0 : 0.7;
      tickPaint..color = const Color(0xFF7A5500)..strokeWidth = sw;
      canvas.drawLine(Offset(x, -halfH + 2), Offset(x, -halfH + 2 + tH), tickPaint);

      if (isMajor && i > 0 && x.abs() < halfLen - 6) {
        final majorIdx = i ~/ majorMult;
        tp.text = TextSpan(
          text: r.unit == _RulerUnit.mm ? '${majorIdx * 10}' : '$majorIdx',
          style: const TextStyle(color: Color(0xFF5C3D00), fontSize: 8, fontWeight: FontWeight.w600),
        );
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, -halfH + 2 + halfH * 0.60 + 1));
      }
    }

    // Unit badge
    canvas.drawRRect(
      RRect.fromRectXY(
          Rect.fromCenter(center: const Offset(0, 12), width: 26, height: 11), 5.5, 5.5),
      Paint()..color = const Color(0xFFDDD0A0),
    );
    final badgeTp = TextPainter(textDirection: TextDirection.ltr);
    badgeTp.text = TextSpan(
      text: unitName,
      style: const TextStyle(color: Color(0xFF5C3D00), fontSize: 9, fontWeight: FontWeight.w700),
    );
    badgeTp.layout();
    badgeTp.paint(canvas, Offset(-badgeTp.width / 2, 12 - badgeTp.height / 2));

    canvas.restore();
  }

  void _paintHandles(Canvas canvas, _RulerData r) {
    final cosA = math.cos(r.angle), sinA = math.sin(r.angle);
    final halfLen = r.length / 2;
    for (final pt in [
      Offset(r.center.dx - cosA * halfLen, r.center.dy - sinA * halfLen),
      Offset(r.center.dx + cosA * halfLen, r.center.dy + sinA * halfLen),
    ]) {
      canvas.drawCircle(pt + const Offset(0, 1), handleR + 1,
          Paint()..color = const Color(0x40000000));
      canvas.drawCircle(pt, handleR, Paint()..color = const Color(0xFF2979FF));
      canvas.drawCircle(pt, handleR,
          Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0);
      canvas.drawLine(Offset(pt.dx - 4, pt.dy), Offset(pt.dx + 4, pt.dy),
          Paint()..color = Colors.white..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => true;
}
