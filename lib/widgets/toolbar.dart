import 'package:flutter/material.dart';
import '../models/stroke.dart';

class WhiteboardToolbar extends StatelessWidget {
  final DrawingTool selectedTool;
  final Color selectedColor;
  final double strokeWidth;
  final ValueChanged<DrawingTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;

  const WhiteboardToolbar({
    super.key,
    required this.selectedTool,
    required this.selectedColor,
    required this.strokeWidth,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
  });

  static const _quickColors = [
    Color(0xFF000000),
    Color(0xFFE53935),
    Color(0xFFF57C00),
    Color(0xFFFFD600),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFF7B1FA2),
    Color(0xFFEC407A),
    Color(0xFFFFFFFF),
  ];

  static const _paletteColors = [
    Color(0xFF000000), Color(0xFF424242), Color(0xFF757575), Color(0xFFBDBDBD), Color(0xFFE0E0E0), Color(0xFFFFFFFF),
    Color(0xFF8B0000), Color(0xFFE53935), Color(0xFFFF5252), Color(0xFFFF8A80), Color(0xFFEC407A), Color(0xFFF48FB1),
    Color(0xFFE65100), Color(0xFFF57C00), Color(0xFFFFA000), Color(0xFFFFD600), Color(0xFFFFEE58), Color(0xFFFFF9C4),
    Color(0xFF1B5E20), Color(0xFF43A047), Color(0xFF26A69A), Color(0xFF00BCD4), Color(0xFF4FC3F7), Color(0xFFB3E5FC),
    Color(0xFF0D47A1), Color(0xFF1E88E5), Color(0xFF3F51B5), Color(0xFF7B1FA2), Color(0xFFE040FB), Color(0xFFEA80FC),
  ];

  static const _sizePresets = [2.0, 5.0, 10.0, 18.0];

  void _openPalette(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Color Palette',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _paletteColors
                    .map((c) => GestureDetector(
                          onTap: () {
                            onColorChanged(c);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == c
                                    ? Colors.blue
                                    : Colors.grey.shade300,
                                width: selectedColor == c ? 2.5 : 1,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
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
    final drawingTools = [
      (DrawingTool.pan, Icons.open_with_rounded, 'Pan'),
      (DrawingTool.pen, Icons.edit_rounded, 'Pen'),
      (DrawingTool.highlighter, Icons.highlight_rounded, 'Highlighter'),
      (DrawingTool.eraser, Icons.auto_fix_normal_rounded, 'Eraser'),
      (DrawingTool.select, Icons.touch_app_rounded, 'Select'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(28),
              blurRadius: 14,
              offset: const Offset(0, 3))
        ],
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drawing tools
          for (final (tool, icon, tip) in drawingTools)
            _ToolBtn(
              icon: icon,
              tooltip: tip,
              selected: selectedTool == tool,
              onTap: () => onToolChanged(tool),
            ),
          _divider(),
          // Quick color swatches
          for (final color in _quickColors)
            _ColorSwatch(
              color: color,
              selected: selectedColor == color,
              onTap: () => onColorChanged(color),
            ),
          // Full palette button
          Tooltip(
            message: 'More colors',
            child: InkWell(
              onTap: () => _openPalette(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  gradient: const SweepGradient(colors: [
                    Colors.red,
                    Colors.orange,
                    Colors.yellow,
                    Colors.green,
                    Colors.blue,
                    Colors.purple,
                    Colors.red,
                  ]),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                width: 22,
                height: 22,
              ),
            ),
          ),
          _divider(),
          // Pen size presets
          for (final size in _sizePresets)
            _SizePreset(
              size: size,
              color: selectedColor,
              selected: strokeWidth == size,
              onTap: () => onStrokeWidthChanged(size),
            ),
          // Size slider
          SizedBox(
            width: 80,
            child: Slider(
              value: strokeWidth.clamp(1.0, 24.0),
              min: 1,
              max: 24,
              onChanged: onStrokeWidthChanged,
              activeColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: SizedBox(height: 26, child: VerticalDivider(width: 1, thickness: 1)),
      );
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorSwatch(
      {required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.blue : Colors.grey.shade300,
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: selected
              ? [BoxShadow(color: Colors.blue.withAlpha(60), blurRadius: 4)]
              : null,
        ),
      ),
    );
  }
}

class _SizePreset extends StatelessWidget {
  final double size;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _SizePreset(
      {required this.size,
      required this.color,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dotSize = (size * 0.9).clamp(3.0, 16.0);
    return Tooltip(
      message: '${size.toInt()}px',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: selected ? Colors.blue.withAlpha(20) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: selected ? Colors.blue : Colors.black87,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  const _ToolBtn(
      {required this.icon,
      required this.tooltip,
      this.selected = false,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected ? Colors.blue.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              Icon(icon, size: 20, color: selected ? Colors.blue : Colors.black87),
        ),
      ),
    );
  }
}
