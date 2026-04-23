import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/whiteboard_item.dart';

class MathPanel extends StatefulWidget {
  final void Function(MathGraphType) onInsert;
  final void Function(String) onInsertEquation;
  final VoidCallback? onDragStarted;
  const MathPanel({super.key, required this.onInsert, required this.onInsertEquation, this.onDragStarted});

  @override
  State<MathPanel> createState() => _MathPanelState();
}

class _MathPanelState extends State<MathPanel> {
  int _tab = 0;

  static const _graphItems = [
    (MathGraphType.xyGraph, 'XY Graph', Icons.grid_on_rounded, Color(0xFF1565C0)),
    (MathGraphType.xyzGraph, '3D Graph', Icons.view_in_ar_rounded, Color(0xFF6A1B9A)),
    (MathGraphType.numberLine, 'Number Line', Icons.horizontal_rule_rounded, Color(0xFF00838F)),
    (MathGraphType.unitCircle, 'Unit Circle', Icons.radio_button_unchecked_rounded, Color(0xFF2E7D32)),
    (MathGraphType.polarGraph, 'Polar', Icons.blur_circular_rounded, Color(0xFF4527A0)),
    (MathGraphType.vennDiagram, 'Venn', Icons.workspaces_outlined, Color(0xFFBF360C)),
  ];

  static const _mathEquations = [
    ('Quadratic Formula',       'x = (−b ± √(b²−4ac)) / 2a'),
    ('Pythagorean Theorem',     'a² + b² = c²'),
    ('Distance Formula',        'd = √((x₂−x₁)² + (y₂−y₁)²)'),
    ('Slope',                   'm = (y₂−y₁) / (x₂−x₁)'),
    ('Circle Area',             'A = πr²'),
    ('Circumference',           'C = 2πr'),
    ("Euler's Identity",        'eⁱᵖ + 1 = 0'),
    ('Log Change of Base',      'logᵦ(x) = ln(x) / ln(b)'),
    ('Law of Cosines',          'c² = a² + b² − 2ab·cos(C)'),
    ('Sine Rule',               'a/sin(A) = b/sin(B) = c/sin(C)'),
    ('Arithmetic Series',       'Sₙ = n/2 · (a₁ + aₙ)'),
    ('Geometric Series',        'Sₙ = a(1−rⁿ) / (1−r)'),
    ('Compound Interest',       'A = P(1 + r/n)ⁿᵗ'),
    ('Point-Slope Form',        'y − y₁ = m(x − x₁)'),
    ('Standard Ellipse',        'x²/a² + y²/b² = 1'),
  ];

  static const _physicsEquations = [
    ("Newton's 2nd Law",        'F = ma'),
    ('Mass–Energy',             'E = mc²'),
    ('Velocity (kinematics)',   'v = v₀ + at'),
    ('Displacement',            'd = v₀t + ½at²'),
    ('Work',                    'W = F·d·cos(θ)'),
    ('Momentum',                'p = mv'),
    ('Kinetic Energy',          'KE = ½mv²'),
    ('Gravitational PE',        'PE = mgh'),
    ("Ohm's Law",               'V = IR'),
    ('Power',                   'P = IV = I²R = V²/R'),
    ("Coulomb's Law",           'F = kq₁q₂ / r²'),
    ('Gravitation',             'F = Gm₁m₂ / r²'),
    ('Ideal Gas Law',           'PV = nRT'),
    ('Wave Speed',              'v = fλ'),
    ("Snell's Law",             'n₁ sin(θ₁) = n₂ sin(θ₂)'),
    ('Centripetal Force',       'Fc = mv² / r'),
    ('Period of Pendulum',      'T = 2π√(L/g)'),
    ('Pressure',                'P = F / A'),
  ];

  static const _symbols = [
    // Constants
    ('π',   'π',       'Pi'),
    ('e',   'e',       "Euler's number"),
    ('φ',   'φ',       'Golden ratio'),
    ('τ',   'τ',       'Tau (2π)'),
    ('∞',   '∞',       'Infinity'),
    ('√',   '√',       'Square root'),
    // Calculus — integrals
    ('∫',   '∫',       'Integral'),
    ('∬',   '∬',       'Double integral'),
    ('∭',   '∭',       'Triple integral'),
    ('∮',   '∮',       'Contour integral'),
    // Calculus — derivatives
    ('d/dx',  'd/dx',    'Derivative'),
    ('d²/dx²','d²/dx²',  'Second derivative'),
    ('∂/∂x',  '∂/∂x',    'Partial derivative'),
    ('∇',   '∇',       'Del / Nabla'),
    // Summation / product
    ('Σ',   'Σ',       'Summation'),
    ('Π',   'Π',       'Product'),
    // Operators
    ('±',   '±',       'Plus-minus'),
    ('×',   '×',       'Multiply'),
    ('÷',   '÷',       'Divide'),
    ('≈',   '≈',       'Approximately'),
    ('≠',   '≠',       'Not equal'),
    ('≤',   '≤',       'Less or equal'),
    ('≥',   '≥',       'Greater or equal'),
    ('∝',   '∝',       'Proportional'),
    // Greek letters
    ('α',   'α',       'Alpha'),
    ('β',   'β',       'Beta'),
    ('γ',   'γ',       'Gamma'),
    ('δ',   'δ',       'Delta'),
    ('ε',   'ε',       'Epsilon'),
    ('θ',   'θ',       'Theta'),
    ('λ',   'λ',       'Lambda'),
    ('μ',   'μ',       'Mu'),
    ('σ',   'σ',       'Sigma'),
    ('ω',   'ω',       'Omega'),
    ('Δ',   'Δ',       'Delta (upper)'),
    ('Ω',   'Ω',       'Omega (upper)'),
    // Set theory
    ('∈',   '∈',       'Element of'),
    ('∉',   '∉',       'Not element of'),
    ('⊂',   '⊂',       'Subset'),
    ('∪',   '∪',       'Union'),
    ('∩',   '∩',       'Intersection'),
    ('∀',   '∀',       'For all'),
    ('∃',   '∃',       'There exists'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 272,
      padding: const EdgeInsets.all(12),
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
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTabBtn(0, 'Graphs'),
              _buildTabBtn(1, 'Math'),
              _buildTabBtn(2, 'Physics'),
              _buildTabBtn(3, 'Symbols'),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              child: switch (_tab) {
                0 => _buildGraphsTab(),
                3 => _buildSymbolsTab(),
                _ => _buildEquationsTab(
                    _tab == 1 ? _mathEquations : _physicsEquations),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBtn(int idx, String label) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1565C0) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildGraphsTab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
          children: [
            for (final (type, label, icon, color) in _graphItems)
              Draggable<MathGraphType>(
                data: type,
                onDragStarted: widget.onDragStarted,
                feedback: Material(
                  color: Colors.transparent,
                  child: _MathTile(label: label, icon: icon, color: color, size: 82),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _MathTile(label: label, icon: icon, color: color),
                ),
                child: GestureDetector(
                  onTap: () => widget.onInsert(type),
                  child: _MathTile(label: label, icon: icon, color: color),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF6A1B9A)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calculate_outlined, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Formula',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEquationsTab(List<(String, String)> equations) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < equations.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
          InkWell(
            onTap: () => widget.onInsertEquation(equations[i].$2),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          equations[i].$1,
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          equations[i].$2,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.add_circle_outline,
                      size: 16, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSymbolsTab() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (label, sym, tip) in _symbols)
          Tooltip(
            message: tip,
            child: InkWell(
              onTap: () => widget.onInsertEquation(sym),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MathTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double size;
  const _MathTile({
    required this.label,
    required this.icon,
    required this.color,
    this.size = 82,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withAlpha(38), Colors.white),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class MathGraphCard extends StatelessWidget {
  final MathGraphItem item;
  const MathGraphCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: CustomPaint(painter: _painterFor(item.graphType)),
      ),
    );
  }

  static CustomPainter _painterFor(MathGraphType t) => switch (t) {
        MathGraphType.xyGraph => const _XYGraphPainter(),
        MathGraphType.xyzGraph => const _XYZGraphPainter(),
        MathGraphType.numberLine => const _NumberLinePainter(),
        MathGraphType.unitCircle => const _UnitCirclePainter(),
        MathGraphType.polarGraph => const _PolarGraphPainter(),
        MathGraphType.vennDiagram => const _VennDiagramPainter(),
      };
}

class _XYGraphPainter extends CustomPainter {
  const _XYGraphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final unit = size.width / 10;
    final fs = (size.width * 0.032).clamp(8.0, 14.0);

    final gridP = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 0.5;
    for (int i = -5; i <= 5; i++) {
      canvas.drawLine(Offset(cx + i * unit, 0), Offset(cx + i * unit, size.height), gridP);
      canvas.drawLine(Offset(0, cy + i * unit), Offset(size.width, cy + i * unit), gridP);
    }

    final axP = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = (size.width * 0.004).clamp(1.0, 2.0)
      ..style = PaintingStyle.stroke;
    final m = unit * 0.5;
    canvas.drawLine(Offset(m, cy), Offset(size.width - m, cy), axP);
    canvas.drawLine(Offset(cx, m), Offset(cx, size.height - m), axP);

    final arrP = Paint()..color = const Color(0xFF1565C0)..style = PaintingStyle.fill;
    final a = unit * 0.22;
    _arrow(canvas, arrP, Offset(size.width - m, cy), Offset(1, 0), a);
    _arrow(canvas, arrP, Offset(m, cy), Offset(-1, 0), a);
    _arrow(canvas, arrP, Offset(cx, m), Offset(0, -1), a);
    _arrow(canvas, arrP, Offset(cx, size.height - m), Offset(0, 1), a);

    final tickP = Paint()
      ..color = const Color(0xFF555555)
      ..strokeWidth = (size.width * 0.003).clamp(0.5, 1.5);
    final t = unit * 0.12;
    for (int i = -4; i <= 4; i++) {
      if (i == 0) continue;
      canvas.drawLine(Offset(cx + i * unit, cy - t), Offset(cx + i * unit, cy + t), tickP);
      canvas.drawLine(Offset(cx - t, cy - i * unit), Offset(cx + t, cy - i * unit), tickP);
      if (i % 2 == 0) {
        _label(canvas, '$i', Offset(cx + i * unit, cy + unit * 0.26), fs, const Color(0xFF555555));
        _label(canvas, '$i', Offset(cx - unit * 0.3, cy - i * unit), fs, const Color(0xFF555555));
      }
    }
    _label(canvas, 'x', Offset(size.width - m + unit * 0.25, cy - unit * 0.3), fs * 1.1, const Color(0xFF1565C0), bold: true);
    _label(canvas, 'y', Offset(cx + unit * 0.22, m - unit * 0.2), fs * 1.1, const Color(0xFF1565C0), bold: true);
  }

  void _arrow(Canvas c, Paint p, Offset tip, Offset dir, double s) {
    final perp = Offset(-dir.dy, dir.dx);
    c.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((tip - dir * s + perp * s * 0.5).dx, (tip - dir * s + perp * s * 0.5).dy)
        ..lineTo((tip - dir * s - perp * s * 0.5).dx, (tip - dir * s - perp * s * 0.5).dy)
        ..close(),
      p,
    );
  }

  void _label(Canvas c, String text, Offset center, double fs, Color color, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fs, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_XYGraphPainter o) => false;
}

class _XYZGraphPainter extends CustomPainter {
  const _XYZGraphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.62);
    final axLen = size.width * 0.38;
    final unit = axLen / 4;
    final fs = (size.width * 0.033).clamp(8.0, 14.0);

    const xDir = Offset(0.866, 0.5);
    const yDir = Offset(-0.866, 0.5);
    const zDir = Offset(0.0, -1.0);

    final gridP = Paint()
      ..color = const Color(0xFFDDDDDD)
      ..strokeWidth = (size.width * 0.003).clamp(0.5, 1.0);
    for (int i = 1; i <= 4; i++) {
      canvas.drawLine(origin + xDir * (i * unit), origin + xDir * (i * unit) + yDir * axLen, gridP);
      canvas.drawLine(origin + yDir * (i * unit), origin + yDir * (i * unit) + xDir * axLen, gridP);
    }

    final aw = (size.width * 0.005).clamp(1.0, 2.5);
    _axis(canvas, origin, origin + xDir * axLen, const Color(0xFFD32F2F), aw);
    _axis(canvas, origin, origin + yDir * axLen, const Color(0xFF388E3C), aw);
    _axis(canvas, origin, origin + zDir * axLen, const Color(0xFF1565C0), aw);

    _label(canvas, 'X', origin + xDir * (axLen + unit * 0.35), fs * 1.1, const Color(0xFFD32F2F));
    _label(canvas, 'Y', origin + yDir * (axLen + unit * 0.35), fs * 1.1, const Color(0xFF388E3C));
    _label(canvas, 'Z', origin + zDir * (axLen + unit * 0.35), fs * 1.1, const Color(0xFF1565C0));

    canvas.drawCircle(origin, size.width * 0.012, Paint()..color = const Color(0xFF333333));
  }

  void _axis(Canvas c, Offset from, Offset to, Color color, double w) {
    c.drawLine(from, to, Paint()..color = color..strokeWidth = w..style = PaintingStyle.stroke);
    final d = (to - from) / (to - from).distance;
    final perp = Offset(-d.dy, d.dx);
    final s = w * 3.0;
    c.drawPath(
      Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo((to - d * s + perp * s * 0.5).dx, (to - d * s + perp * s * 0.5).dy)
        ..lineTo((to - d * s - perp * s * 0.5).dx, (to - d * s - perp * s * 0.5).dy)
        ..close(),
      Paint()..color = color..style = PaintingStyle.fill,
    );
  }

  void _label(Canvas c, String text, Offset center, double fs, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fs, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_XYZGraphPainter o) => false;
}

class _NumberLinePainter extends CustomPainter {
  const _NumberLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final margin = size.width * 0.07;
    final x0 = margin;
    final x1 = size.width - margin;
    final unit = (x1 - x0) / 10;
    final ox = x0 + 5 * unit;
    final fs = (size.height * 0.22).clamp(8.0, 14.0);
    final tickH = size.height * 0.18;
    final lw = (size.height * 0.04).clamp(1.0, 2.5);

    canvas.drawLine(Offset(x0, cy), Offset(x1, cy),
        Paint()..color = const Color(0xFF1565C0)..strokeWidth = lw..style = PaintingStyle.stroke);

    final ap = Paint()..color = const Color(0xFF1565C0)..style = PaintingStyle.fill;
    final a = size.height * 0.14;
    canvas.drawPath(Path()..moveTo(x1, cy)..lineTo(x1 - a, cy - a * 0.5)..lineTo(x1 - a, cy + a * 0.5)..close(), ap);
    canvas.drawPath(Path()..moveTo(x0, cy)..lineTo(x0 + a, cy - a * 0.5)..lineTo(x0 + a, cy + a * 0.5)..close(), ap);

    final tickP = Paint()..color = const Color(0xFF333333)..strokeWidth = (size.height * 0.025).clamp(0.5, 1.5);
    for (int i = -5; i <= 5; i++) {
      final x = ox + i * unit;
      final h = i == 0 ? tickH * 1.5 : tickH;
      canvas.drawLine(Offset(x, cy - h), Offset(x, cy + h), tickP);
      final tp = TextPainter(
        text: TextSpan(text: '$i', style: TextStyle(color: i == 0 ? const Color(0xFF1565C0) : const Color(0xFF333333), fontSize: fs, fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, cy + tickH + size.height * 0.05));
    }
  }

  @override
  bool shouldRepaint(_NumberLinePainter o) => false;
}

class _UnitCirclePainter extends CustomPainter {
  const _UnitCirclePainter();

  static const _keyDegs = [0, 30, 45, 60, 90, 120, 135, 150, 180, 210, 225, 240, 270, 300, 315, 330];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.37;
    final fs = (size.width * 0.029).clamp(7.0, 12.0);

    canvas.drawCircle(Offset(cx, cy), r * 0.5,
        Paint()..color = const Color(0xFFEEEEEE)..strokeWidth = 0.5..style = PaintingStyle.stroke);

    final axP = Paint()..color = const Color(0xFF888888)..strokeWidth = (size.width * 0.003).clamp(0.5, 1.5)..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - r * 1.25, cy), Offset(cx + r * 1.25, cy), axP);
    canvas.drawLine(Offset(cx, cy - r * 1.25), Offset(cx, cy + r * 1.25), axP);

    final spokeP = Paint()..color = const Color(0xFFDDDDDD)..strokeWidth = 0.5;
    for (final deg in _keyDegs) {
      final rad = deg * math.pi / 180;
      canvas.drawLine(Offset(cx, cy), Offset(cx + r * math.cos(rad), cy - r * math.sin(rad)), spokeP);
    }

    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = const Color(0xFF1565C0)..strokeWidth = (size.width * 0.005).clamp(1.0, 2.5)..style = PaintingStyle.stroke);

    final dotP = Paint()..color = const Color(0xFF1565C0);
    for (final deg in _keyDegs) {
      final rad = deg * math.pi / 180;
      canvas.drawCircle(Offset(cx + r * math.cos(rad), cy - r * math.sin(rad)), size.width * 0.012, dotP);
    }

    const labeled = {0: '0°', 90: '90°', 180: '180°', 270: '270°', 30: '30°', 45: '45°', 60: '60°'};
    for (final e in labeled.entries) {
      final rad = e.key * math.pi / 180;
      final lr = r * 1.16;
      _label(canvas, e.value, Offset(cx + lr * math.cos(rad), cy - lr * math.sin(rad)), fs, const Color(0xFF555555));
    }
    _label(canvas, '(1,0)', Offset(cx + r + size.width * 0.01, cy - fs), fs * 0.82, const Color(0xFF333333));
    _label(canvas, '(0,1)', Offset(cx + size.width * 0.04, cy - r - fs * 0.6), fs * 0.82, const Color(0xFF333333));
    _label(canvas, '(-1,0)', Offset(cx - r - size.width * 0.04, cy - fs), fs * 0.82, const Color(0xFF333333));
    _label(canvas, '(0,-1)', Offset(cx + size.width * 0.02, cy + r + fs * 0.6), fs * 0.82, const Color(0xFF333333));
  }

  void _label(Canvas c, String text, Offset center, double fs, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fs)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_UnitCirclePainter o) => false;
}

class _PolarGraphPainter extends CustomPainter {
  const _PolarGraphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width * 0.41;
    final ringStep = maxR / 4;
    final fs = (size.width * 0.027).clamp(7.0, 11.0);

    final gridP = Paint()..color = const Color(0xFFCCCCCC)..strokeWidth = (size.width * 0.003).clamp(0.5, 1.0)..style = PaintingStyle.stroke;
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(Offset(cx, cy), i * ringStep, gridP);
    }
    for (int deg = 0; deg < 360; deg += 30) {
      final rad = deg * math.pi / 180;
      canvas.drawLine(Offset(cx, cy), Offset(cx + maxR * math.cos(rad), cy - maxR * math.sin(rad)), gridP);
    }

    final axP = Paint()..color = const Color(0xFF555555)..strokeWidth = (size.width * 0.004).clamp(0.8, 1.8)..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - maxR, cy), Offset(cx + maxR, cy), axP);
    canvas.drawLine(Offset(cx, cy - maxR), Offset(cx, cy + maxR), axP);

    const angleLabels = {0: '0', 30: 'π/6', 60: 'π/3', 90: 'π/2', 120: '2π/3', 150: '5π/6', 180: 'π', 210: '7π/6', 240: '4π/3', 270: '3π/2', 300: '5π/3', 330: '11π/6'};
    for (final e in angleLabels.entries) {
      final rad = e.key * math.pi / 180;
      final lr = maxR + size.width * 0.07;
      _label(canvas, e.value, Offset(cx + lr * math.cos(rad), cy - lr * math.sin(rad)), fs, const Color(0xFF555555));
    }
    for (int i = 1; i <= 4; i++) {
      _label(canvas, '$i', Offset(cx + i * ringStep, cy - fs * 0.7), fs, const Color(0xFF888888));
    }
    canvas.drawCircle(Offset(cx, cy), size.width * 0.01, Paint()..color = const Color(0xFF333333));
  }

  void _label(Canvas c, String text, Offset center, double fs, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fs)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_PolarGraphPainter o) => false;
}

class _VennDiagramPainter extends CustomPainter {
  const _VennDiagramPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final r = size.width * 0.28;
    final cxA = size.width / 2 - size.width * 0.12;
    final cxB = size.width / 2 + size.width * 0.12;
    final fs = (size.width * 0.038).clamp(9.0, 15.0);
    final sw = (size.width * 0.004).clamp(1.0, 2.0);

    canvas.drawRRect(
      RRect.fromLTRBR(size.width * 0.04, size.height * 0.08, size.width * 0.96, size.height * 0.92, const Radius.circular(6)),
      Paint()..color = const Color(0xFFBBBBBB)..strokeWidth = (size.width * 0.003).clamp(0.5, 1.5)..style = PaintingStyle.stroke,
    );

    canvas.drawCircle(Offset(cxA, cy), r, Paint()..color = const Color(0x331565C0)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cxA, cy), r, Paint()..color = const Color(0xFF1565C0)..strokeWidth = sw..style = PaintingStyle.stroke);
    canvas.drawCircle(Offset(cxB, cy), r, Paint()..color = const Color(0x33E65100)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cxB, cy), r, Paint()..color = const Color(0xFFE65100)..strokeWidth = sw..style = PaintingStyle.stroke);

    _label(canvas, 'A', Offset(cxA - r * 0.44, cy), fs * 1.2, const Color(0xFF1565C0), bold: true);
    _label(canvas, 'B', Offset(cxB + r * 0.44, cy), fs * 1.2, const Color(0xFFE65100), bold: true);
    _label(canvas, 'A∩B', Offset(size.width / 2, cy), fs * 0.8, const Color(0xFF555555));
    _label(canvas, 'U', Offset(size.width * 0.08, size.height * 0.15), fs * 0.85, const Color(0xFF888888));
  }

  void _label(Canvas c, String text, Offset center, double fs, Color color, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fs, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_VennDiagramPainter o) => false;
}
