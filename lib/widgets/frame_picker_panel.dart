import 'package:flutter/material.dart';

import '../models/whiteboard_item.dart';

class FramePickerPanel extends StatelessWidget {
  final void Function(FrameType) onSelect;
  const FramePickerPanel({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 272,
      constraints: const BoxConstraints(maxHeight: 580),
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('Standard', const [
              FrameType.a4Portrait,
              FrameType.letter,
              FrameType.ratio16x9,
              FrameType.ratio4x3,
              FrameType.ratio1x1,
            ]),
            const SizedBox(height: 10),
            _section('Devices', const [
              FrameType.mobile,
              FrameType.tablet,
              FrameType.desktop,
            ]),
            const SizedBox(height: 10),
            _section('Notes & Templates', const [
              FrameType.noteBlank,
              FrameType.noteLined,
              FrameType.noteDotted,
              FrameType.noteGrid,
              FrameType.graphPaper,
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<FrameType> types) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF999999),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 7),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.82,
          children: types.map(_cell).toList(),
        ),
      ],
    );
  }

  Widget _cell(FrameType type) {
    final label = FrameItem.labelFor(type);
    final w = FrameItem.defaultWidth(type);
    final h = FrameItem.defaultHeight(type);
    final ar = w / h;
    const maxDim = 40.0;
    final pw = ar >= 1 ? maxDim : maxDim * ar;
    final ph = ar <= 1 ? maxDim : maxDim / ar;

    return InkWell(
      onTap: () => onSelect(type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: pw + 4,
              height: ph + 4,
              child: CustomPaint(
                painter: _FrameIconPainter(type: type),
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrameIconPainter extends CustomPainter {
  final FrameType type;
  const _FrameIconPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(rect, Paint()..color = Colors.white);
    _drawTemplatePreview(canvas, size);
    _drawDeviceDecor(canvas, size);

    final radius = (type == FrameType.mobile || type == FrameType.tablet)
        ? 3.5
        : 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..color = const Color(0xFF333333)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawTemplatePreview(Canvas canvas, Size size) {
    final bg = FrameItem.defaultBackground(type);
    switch (bg) {
      case FrameBackground.blank:
        break;
      case FrameBackground.lined:
        final p = Paint()..color = const Color(0xFFB0C4DE)..strokeWidth = 0.6;
        for (double y = 6; y < size.height - 2; y += 6) {
          canvas.drawLine(Offset(2, y), Offset(size.width - 2, y), p);
        }
      case FrameBackground.dotted:
        final p = Paint()..color = const Color(0xFFAAAAAA);
        for (double x = 4; x < size.width; x += 5) {
          for (double y = 4; y < size.height; y += 5) {
            canvas.drawCircle(Offset(x, y), 0.7, p);
          }
        }
      case FrameBackground.grid:
        final p = Paint()..color = const Color(0xFFCCDDEE)..strokeWidth = 0.5;
        for (double x = 0; x < size.width; x += 6) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        for (double y = 0; y < size.height; y += 6) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
      case FrameBackground.graphPaper:
        final minor = Paint()
          ..color = const Color(0xFFCCEECC)
          ..strokeWidth = 0.3;
        final major = Paint()
          ..color = const Color(0xFF88CC88)
          ..strokeWidth = 0.6;
        for (double x = 0; x < size.width; x += 3) {
          canvas.drawLine(
              Offset(x, 0), Offset(x, size.height),
              x.round() % 15 == 0 ? major : minor);
        }
        for (double y = 0; y < size.height; y += 3) {
          canvas.drawLine(
              Offset(0, y), Offset(size.width, y),
              y.round() % 15 == 0 ? major : minor);
        }
    }
  }

  void _drawDeviceDecor(Canvas canvas, Size size) {
    switch (type) {
      case FrameType.desktop:
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, 7),
          Paint()..color = const Color(0xFF444444),
        );
        final colors = [
          const Color(0xFFFF5F57),
          const Color(0xFFFFBD2E),
          const Color(0xFF28C840),
        ];
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(
              Offset(3.5 + i * 5.5, 3.5), 1.8, Paint()..color = colors[i]);
        }
      case FrameType.mobile:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(size.width / 2, 2.5),
                width: size.width * 0.35,
                height: 4),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFF333333),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(size.width / 2, size.height - 2.5),
                width: size.width * 0.4,
                height: 2),
            const Radius.circular(1),
          ),
          Paint()..color = const Color(0xFF444444),
        );
      case FrameType.tablet:
        canvas.drawCircle(
            Offset(size.width / 2, 2.5), 1.2, Paint()..color = const Color(0xFF555555));
        canvas.drawCircle(
          Offset(size.width / 2, size.height - 3.5),
          2.5,
          Paint()
            ..color = const Color(0xFF888888)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(_FrameIconPainter old) => type != old.type;
}
