import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<Color?> showColorPickerDialog(BuildContext context, Color initial) =>
    showDialog<Color>(
      context: context,
      builder: (ctx) => _ColorPickerDialog(initialColor: initial),
    );

class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  const _ColorPickerDialog({required this.initialColor});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  static const double _wheelSize = 220.0;
  static const double _ringThick = 26.0;
  static const double _innerR = _wheelSize / 2 - _ringThick;
  static const double _sqSide = _innerR * math.sqrt2 * 0.88;

  late double _h, _s, _v, _a;
  late TextEditingController _hexCtrl;
  late TextEditingController _rCtrl, _gCtrl, _bCtrl;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _h = hsv.hue;
    _s = hsv.saturation;
    _v = hsv.value;
    _a = hsv.alpha;
    final c = _currentColor;
    _hexCtrl = TextEditingController(text: _toHex(c));
    _rCtrl = TextEditingController(text: '${_ch(c.r)}');
    _gCtrl = TextEditingController(text: '${_ch(c.g)}');
    _bCtrl = TextEditingController(text: '${_ch(c.b)}');
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    _rCtrl.dispose();
    _gCtrl.dispose();
    _bCtrl.dispose();
    super.dispose();
  }

  Color get _currentColor => HSVColor.fromAHSV(_a, _h, _s, _v).toColor();

  static int _ch(double channel) => (channel * 255.0).round().clamp(0, 255);

  static String _toHex(Color c) =>
      '#${_ch(c.r).toRadixString(16).padLeft(2, '0')}'
      '${_ch(c.g).toRadixString(16).padLeft(2, '0')}'
      '${_ch(c.b).toRadixString(16).padLeft(2, '0')}'.toUpperCase();

  void _syncFields() {
    final c = _currentColor;
    _hexCtrl.text = _toHex(c);
    _rCtrl.text = '${_ch(c.r)}';
    _gCtrl.text = '${_ch(c.g)}';
    _bCtrl.text = '${_ch(c.b)}';
  }

  void _handleWheel(Offset local) {
    const cx = _wheelSize / 2;
    const cy = _wheelSize / 2;
    final dx = local.dx - cx;
    final dy = local.dy - cy;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist >= _innerR - 4) {
      final angle = math.atan2(dy, dx);
      setState(() => _h = ((angle * 180 / math.pi) + 90 + 360) % 360);
    } else {
      const half = _sqSide / 2;
      final sx = ((dx + half) / _sqSide).clamp(0.0, 1.0);
      final sy = ((dy + half) / _sqSide).clamp(0.0, 1.0);
      setState(() {
        _s = sx;
        _v = 1 - sy;
      });
    }
    _syncFields();
  }

  void _onHexChanged(String v) {
    final cleaned = v.replaceAll('#', '');
    if (cleaned.length != 6) return;
    try {
      final color = Color(int.parse('FF$cleaned', radix: 16));
      final hsv = HSVColor.fromColor(color);
      setState(() {
        _h = hsv.hue;
        _s = hsv.saturation;
        _v = hsv.value;
      });
      _rCtrl.text = '${_ch(color.r)}';
      _gCtrl.text = '${_ch(color.g)}';
      _bCtrl.text = '${_ch(color.b)}';
    } catch (_) {}
  }

  void _onRgbChanged() {
    final r = (int.tryParse(_rCtrl.text) ?? 0).clamp(0, 255);
    final g = (int.tryParse(_gCtrl.text) ?? 0).clamp(0, 255);
    final b = (int.tryParse(_bCtrl.text) ?? 0).clamp(0, 255);
    final color = Color.fromARGB((_a * 255).round(), r, g, b);
    final hsv = HSVColor.fromColor(color);
    setState(() {
      _h = hsv.hue;
      _s = hsv.saturation;
      _v = hsv.value;
    });
    _hexCtrl.text = _toHex(color);
  }

  @override
  Widget build(BuildContext context) {
    final color = _currentColor;
    final hsl = HSLColor.fromColor(color);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Text('Color Picker',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4)],
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              GestureDetector(
                onTapDown: (d) => _handleWheel(d.localPosition),
                onPanUpdate: (d) => _handleWheel(d.localPosition),
                child: CustomPaint(
                  size: const Size(_wheelSize, _wheelSize),
                  painter: _WheelPainter(h: _h, s: _s, v: _v),
                ),
              ),
              const SizedBox(height: 12),
              // Opacity
              Row(children: [
                const SizedBox(
                  width: 20,
                  child: Text('A',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54)),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 8,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: _a,
                      onChanged: (v) {
                        setState(() => _a = v);
                        _syncFields();
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: 38,
                  child: Text('${(_a * 100).round()}%',
                      style: const TextStyle(fontSize: 11), textAlign: TextAlign.right),
                ),
              ]),
              const SizedBox(height: 8),
              // HEX
              Row(children: [
                const SizedBox(
                  width: 38,
                  child: Text('HEX',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54)),
                ),
                Expanded(
                  child: TextField(
                    controller: _hexCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 13, letterSpacing: 0.5),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(7),
                    ],
                    onChanged: _onHexChanged,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              // RGB
              Row(children: [
                _rgbField('R', _rCtrl, const Color(0xFFE53935)),
                const SizedBox(width: 6),
                _rgbField('G', _gCtrl, const Color(0xFF43A047)),
                const SizedBox(width: 6),
                _rgbField('B', _bCtrl, const Color(0xFF1E88E5)),
              ]),
              const SizedBox(height: 8),
              // HSL readout
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _hslChip('H', '${hsl.hue.round()}°'),
                    _hslChip('S', '${(hsl.saturation * 100).round()}%'),
                    _hslChip('L', '${(hsl.lightness * 100).round()}%'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(color),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Select'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rgbField(String label, TextEditingController ctrl, Color accent) => Expanded(
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: accent)),
            const SizedBox(height: 2),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              onChanged: (_) => _onRgbChanged(),
            ),
          ],
        ),
      );

  Widget _hslChip(String label, String value) => Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black45)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
}

class _WheelPainter extends CustomPainter {
  final double h, s, v;

  static const double _wheelSize = 220.0;
  static const double _ringThick = 26.0;
  static const double _innerR = _wheelSize / 2 - _ringThick;
  static const double _sqSide = _innerR * math.sqrt2 * 0.88;
  static const double _half = _sqSide / 2;

  const _WheelPainter({required this.h, required this.s, required this.v});

  @override
  void paint(Canvas canvas, Size size) {
    const cx = _wheelSize / 2;
    const cy = _wheelSize / 2;
    const center = Offset(cx, cy);
    const midR = cx - _ringThick / 2;

    // Hue ring via sweep gradient
    final hueColors = List.generate(
      362,
      (i) => HSVColor.fromAHSV(1, (i % 360).toDouble(), 1, 1).toColor(),
    );
    canvas.drawCircle(
      center,
      midR,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: hueColors,
        ).createShader(Rect.fromCircle(center: center, radius: midR))
        ..strokeWidth = _ringThick
        ..style = PaintingStyle.stroke,
    );

    // SV square
    final sqRect = Rect.fromCenter(center: center, width: _sqSide, height: _sqSide);
    final hueColor = HSVColor.fromAHSV(1, h, 1, 1).toColor();
    canvas.drawRect(
        sqRect,
        Paint()
          ..shader =
              LinearGradient(colors: [Colors.white, hueColor]).createShader(sqRect));
    canvas.drawRect(
        sqRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black],
          ).createShader(sqRect));

    // SV indicator dot
    final svX = (cx - _half) + s * _sqSide;
    final svY = (cy - _half) + (1 - v) * _sqSide;
    canvas.drawCircle(
        Offset(svX, svY), 9, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5);
    canvas.drawCircle(
        Offset(svX, svY), 6, Paint()..color = HSVColor.fromAHSV(1, h, s, v).toColor());

    // Hue indicator dot on ring
    final hueRad = (h - 90) * math.pi / 180;
    final hueIx = cx + midR * math.cos(hueRad);
    final hueIy = cy + midR * math.sin(hueRad);
    canvas.drawCircle(Offset(hueIx, hueIy), _ringThick / 2 + 3, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(hueIx, hueIy),
        _ringThick / 2 + 3,
        Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 1);
    canvas.drawCircle(Offset(hueIx, hueIy), _ringThick / 2 - 1, Paint()..color = hueColor);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.h != h || old.s != s || old.v != v;
}
