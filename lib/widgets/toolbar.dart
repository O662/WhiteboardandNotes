import 'package:flutter/material.dart';
import '../models/stroke.dart';

class WhiteboardToolbar extends StatelessWidget {
  final DrawingTool selectedTool;
  final Color selectedColor;
  final double strokeWidth;
  final ValueChanged<DrawingTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  const WhiteboardToolbar({
    super.key,
    required this.selectedTool,
    required this.selectedColor,
    required this.strokeWidth,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.onUndo,
    required this.onClear,
  });

  static const _colors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolButton(
            icon: Icons.edit,
            tooltip: 'Pen',
            selected: selectedTool == DrawingTool.pen,
            onTap: () => onToolChanged(DrawingTool.pen),
          ),
          _ToolButton(
            icon: Icons.auto_fix_normal,
            tooltip: 'Eraser',
            selected: selectedTool == DrawingTool.eraser,
            onTap: () => onToolChanged(DrawingTool.eraser),
          ),
          const SizedBox(width: 8),
          const VerticalDivider(width: 1),
          const SizedBox(width: 8),
          for (final color in _colors)
            GestureDetector(
              onTap: () => onColorChanged(color),
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedColor == color ? Colors.blue : Colors.grey,
                    width: selectedColor == color ? 2.5 : 1,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          const VerticalDivider(width: 1),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Slider(
              value: strokeWidth,
              min: 1,
              max: 24,
              onChanged: onStrokeWidthChanged,
            ),
          ),
          const SizedBox(width: 8),
          const VerticalDivider(width: 1),
          const SizedBox(width: 8),
          _ToolButton(icon: Icons.undo, tooltip: 'Undo', onTap: onUndo),
          _ToolButton(icon: Icons.delete_outline, tooltip: 'Clear', onTap: onClear),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    this.selected = false,
    required this.onTap,
  });

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
          child: Icon(icon, size: 22, color: selected ? Colors.blue : Colors.black87),
        ),
      ),
    );
  }
}
