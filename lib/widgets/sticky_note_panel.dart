import 'package:flutter/material.dart';

enum StickyNotePickType { single, stack }

typedef StickyNotePickData = ({StickyNotePickType type, Color color});

class StickyNotePickerPanel extends StatefulWidget {
  const StickyNotePickerPanel({super.key});

  @override
  State<StickyNotePickerPanel> createState() => _StickyNotePickerPanelState();
}

class _StickyNotePickerPanelState extends State<StickyNotePickerPanel> {
  static const _colors = [
    Color(0xFFFFF9C4),
    Color(0xFFB3E5FC),
    Color(0xFFC8E6C9),
    Color(0xFFFFCDD2),
    Color(0xFFE1BEE7),
    Color(0xFFFFE0B2),
  ];

  Color _selected = const Color(0xFFFFF9C4);

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
            'STICKY NOTES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF999999),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final c in _colors)
                GestureDetector(
                  onTap: () => setState(() => _selected = c),
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c == _selected
                            ? Colors.blue
                            : Colors.grey.shade300,
                        width: c == _selected ? 2.5 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _cell(StickyNotePickType.single, 'Single')),
              const SizedBox(width: 8),
              Expanded(child: _cell(StickyNotePickType.stack, 'Stack')),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Drag onto canvas to place',
            style: TextStyle(fontSize: 9, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }

  Widget _cell(StickyNotePickType type, String label) {
    final data = (type: type, color: _selected);
    return Draggable<StickyNotePickData>(
      data: data,
      feedback: Material(
        color: Colors.transparent,
        child: _DragFeedback(type: type, color: _selected),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _CellBody(type: type, label: label, color: _selected),
      ),
      child: _CellBody(type: type, label: label, color: _selected),
    );
  }
}

class _CellBody extends StatelessWidget {
  final StickyNotePickType type;
  final String label;
  final Color color;
  const _CellBody({required this.type, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 38,
            child: CustomPaint(
              painter: type == StickyNotePickType.single
                  ? _SingleIconPainter(color: color)
                  : _StackIconPainter(color: color),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  final StickyNotePickType type;
  final Color color;
  const _DragFeedback({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    if (type == StickyNotePickType.single) {
      return Container(
        width: 120,
        height: 96,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 12,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 18,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(30),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 130,
      height: 110,
      child: Stack(
        children: [
          for (int i = 2; i >= 0; i--)
            Positioned(
              left: (2 - i) * 6.0,
              top: i * 4.0,
              child: Container(
                width: 108,
                height: 86,
                decoration: BoxDecoration(
                  color: i == 0 ? color : color.withAlpha(180),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: i == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 8,
                            offset: const Offset(2, 3),
                          )
                        ]
                      : null,
                ),
                child: i == 0
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(30),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'drag to peel',
                              style: TextStyle(
                                  fontSize: 9, color: Color(0xFF777777)),
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _SingleIconPainter extends CustomPainter {
  final Color color;
  const _SingleIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 4.0;
    final r = RRect.fromLTRBR(
        pad, pad, size.width - pad, size.height - pad, const Radius.circular(2));
    canvas.drawRRect(
        r.shift(const Offset(1, 1)),
        Paint()
          ..color = Colors.black.withAlpha(25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawRRect(r, Paint()..color = color);
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(pad, pad, size.width - pad, pad + 8,
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2)),
      Paint()..color = Colors.black.withAlpha(28),
    );
  }

  @override
  bool shouldRepaint(_SingleIconPainter old) => color != old.color;
}

class _StackIconPainter extends CustomPainter {
  final Color color;
  const _StackIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 4.0;
    for (int i = 2; i >= 0; i--) {
      final dx = (2 - i) * 3.0;
      final dy = i * -2.5;
      final r = RRect.fromLTRBR(
          pad + dx,
          pad + 6 + dy,
          size.width - pad + dx,
          size.height - pad + dy,
          const Radius.circular(2));
      if (i == 0) {
        canvas.drawRRect(
            r.shift(const Offset(1, 1)),
            Paint()
              ..color = Colors.black.withAlpha(20)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      }
      canvas.drawRRect(r, Paint()..color = i == 0 ? color : color.withAlpha(160));
      if (i == 0) {
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(
              pad + dx,
              pad + 6 + dy,
              size.width - pad + dx,
              pad + 6 + dy + 7,
              topLeft: const Radius.circular(2),
              topRight: const Radius.circular(2)),
          Paint()..color = Colors.black.withAlpha(28),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StackIconPainter old) => color != old.color;
}
