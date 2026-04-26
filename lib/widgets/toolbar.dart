import 'package:flutter/material.dart';
import '../models/stroke.dart';
import 'color_picker_panel.dart';

class WhiteboardToolbar extends StatefulWidget {
  final DrawingTool selectedTool;
  final Color selectedColor;
  final double strokeWidth;
  final ValueChanged<DrawingTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;

  final VoidCallback onAddRuler;
  final VoidCallback onClearRulers;

  const WhiteboardToolbar({
    super.key,
    required this.selectedTool,
    required this.selectedColor,
    required this.strokeWidth,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.onAddRuler,
    required this.onClearRulers,
  });

  @override
  State<WhiteboardToolbar> createState() => _WhiteboardToolbarState();
}

class _WhiteboardToolbarState extends State<WhiteboardToolbar> {
  bool _showSizePanel = false;

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

  static const _sizePresets = [2.0, 5.0, 10.0, 18.0];

  void _openColorPicker(BuildContext context) {
    showColorPickerDialog(context, widget.selectedColor).then((picked) {
      if (picked != null && mounted) widget.onColorChanged(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    const preSelectTools = [
      (DrawingTool.pan, Icons.open_with_rounded, 'Pan'),
      (DrawingTool.pen, Icons.edit_rounded, 'Pen'),
      (DrawingTool.highlighter, Icons.highlight_rounded, 'Highlighter'),
    ];
    const postSelectTools = [
      (DrawingTool.text, Icons.title_rounded, 'Text'),
    ];

    final toolbar = Container(
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
          // Pan, Pen, Highlighter
          for (final (tool, icon, tip) in preSelectTools)
            _ToolBtn(
              icon: icon,
              tooltip: tip,
              selected: widget.selectedTool == tool,
              onTap: () => widget.onToolChanged(tool),
            ),
          // Select / Lasso Select
          _SelectBtn(selectedTool: widget.selectedTool, onToolChanged: widget.onToolChanged),
          // Text
          for (final (tool, icon, tip) in postSelectTools)
            _ToolBtn(
              icon: icon,
              tooltip: tip,
              selected: widget.selectedTool == tool,
              onTap: () => widget.onToolChanged(tool),
            ),
          // Eraser group
          _EraserBtn(selectedTool: widget.selectedTool, onToolChanged: widget.onToolChanged),
          _divider(),
          // Quick color swatches
          for (final color in _quickColors)
            _ColorSwatch(
              color: color,
              selected: widget.selectedColor == color,
              onTap: () => widget.onColorChanged(color),
            ),
          // Full palette button
          Tooltip(
            message: 'More colors',
            child: InkWell(
              onTap: () => _openColorPicker(context),
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
          // Size button — opens dropdown panel below toolbar
          _SizeBtn(
            strokeWidth: widget.strokeWidth,
            color: widget.selectedColor,
            panelOpen: _showSizePanel,
            onTap: () => setState(() => _showSizePanel = !_showSizePanel),
          ),
          _divider(),
          // Ruler
          _RulerBtn(
            selectedTool: widget.selectedTool,
            onToolChanged: widget.onToolChanged,
            onAddRuler: widget.onAddRuler,
            onClearRulers: widget.onClearRulers,
          ),
          // Laser pointer
          _ToolBtn(
            icon: Icons.ads_click_rounded,
            tooltip: 'Laser Pointer',
            selected: widget.selectedTool == DrawingTool.laser,
            onTap: () => widget.onToolChanged(DrawingTool.laser),
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        toolbar,
        if (_showSizePanel)
          _SizePanelDropdown(
            strokeWidth: widget.strokeWidth,
            color: widget.selectedColor,
            sizePresets: _sizePresets,
            onChanged: widget.onStrokeWidthChanged,
          ),
      ],
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

class _SelectBtn extends StatefulWidget {
  final DrawingTool selectedTool;
  final ValueChanged<DrawingTool> onToolChanged;

  const _SelectBtn({required this.selectedTool, required this.onToolChanged});

  @override
  State<_SelectBtn> createState() => _SelectBtnState();
}

class _SelectBtnState extends State<_SelectBtn> {
  DrawingTool _lastTool = DrawingTool.select;

  static const _selectTools = [
    (DrawingTool.select, Icons.touch_app_rounded, 'Select'),
    (DrawingTool.lassoSelect, Icons.gesture_rounded, 'Lasso Select'),
    (DrawingTool.rectSelect, Icons.crop_square_rounded, 'Rect Select'),
  ];

  bool get _isActive =>
      widget.selectedTool == DrawingTool.select ||
      widget.selectedTool == DrawingTool.lassoSelect ||
      widget.selectedTool == DrawingTool.rectSelect;

  IconData get _icon {
    if (_lastTool == DrawingTool.lassoSelect) return Icons.gesture_rounded;
    if (_lastTool == DrawingTool.rectSelect) return Icons.crop_square_rounded;
    return Icons.touch_app_rounded;
  }

  void _handleTap(BuildContext ctx) {
    if (!_isActive) {
      widget.onToolChanged(_lastTool);
    } else {
      _showMenu(ctx);
    }
  }

  Future<void> _showMenu(BuildContext ctx) async {
    final box = ctx.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(ctx).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final tool = await showMenu<DrawingTool>(
      context: ctx,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      color: Colors.white,
      items: [
        for (final (t, icon, label) in _selectTools)
          PopupMenuItem(
            value: t,
            child: Row(children: [
              Icon(icon, size: 18,
                  color: widget.selectedTool == t ? Colors.blue : Colors.black87),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: widget.selectedTool == t ? Colors.blue : Colors.black87,
                      fontWeight: widget.selectedTool == t
                          ? FontWeight.w600
                          : FontWeight.normal)),
            ]),
          ),
      ],
    );
    if (tool != null) {
      setState(() => _lastTool = tool);
      widget.onToolChanged(tool);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Tooltip(
        message: 'Select',
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _isActive ? Colors.blue.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_icon, size: 20,
              color: _isActive ? Colors.blue : Colors.black87),
        ),
      ),
    );
  }
}

class _EraserBtn extends StatefulWidget {
  final DrawingTool selectedTool;
  final ValueChanged<DrawingTool> onToolChanged;

  const _EraserBtn({required this.selectedTool, required this.onToolChanged});

  @override
  State<_EraserBtn> createState() => _EraserBtnState();
}

class _EraserBtnState extends State<_EraserBtn> {
  DrawingTool _lastTool = DrawingTool.strokeEraser;

  static const _eraserTools = [
    (DrawingTool.strokeEraser, Icons.auto_fix_normal_rounded, 'Eraser'),
    (DrawingTool.eraser, Icons.opacity, 'Transparent Pen'),
    (DrawingTool.lineDelete, Icons.remove_circle_outline_rounded, 'Delete Stroke'),
  ];

  bool get _isActive =>
      widget.selectedTool == DrawingTool.eraser ||
      widget.selectedTool == DrawingTool.strokeEraser ||
      widget.selectedTool == DrawingTool.lineDelete;

  IconData get _icon {
    for (final (tool, icon, _) in _eraserTools) {
      if (tool == _lastTool) return icon;
    }
    return Icons.auto_fix_normal_rounded;
  }

  void _handleTap(BuildContext ctx) {
    if (!_isActive) {
      widget.onToolChanged(_lastTool);
    } else {
      _showMenu(ctx);
    }
  }

  Future<void> _showMenu(BuildContext ctx) async {
    final box = ctx.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(ctx).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final tool = await showMenu<DrawingTool>(
      context: ctx,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      color: Colors.white,
      items: [
        for (final (t, icon, label) in _eraserTools)
          PopupMenuItem(
            value: t,
            child: Row(children: [
              Icon(icon, size: 18,
                  color: widget.selectedTool == t ? Colors.blue : Colors.black87),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: widget.selectedTool == t ? Colors.blue : Colors.black87,
                      fontWeight: widget.selectedTool == t
                          ? FontWeight.w600
                          : FontWeight.normal)),
            ]),
          ),
      ],
    );
    if (tool != null) {
      setState(() => _lastTool = tool);
      widget.onToolChanged(tool);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Tooltip(
        message: 'Eraser',
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _isActive ? Colors.blue.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_icon, size: 20,
              color: _isActive ? Colors.blue : Colors.black87),
        ),
      ),
    );
  }
}

class _RulerBtn extends StatelessWidget {
  final DrawingTool selectedTool;
  final ValueChanged<DrawingTool> onToolChanged;
  final VoidCallback onAddRuler;
  final VoidCallback onClearRulers;

  const _RulerBtn({
    required this.selectedTool,
    required this.onToolChanged,
    required this.onAddRuler,
    required this.onClearRulers,
  });

  bool get _isActive => selectedTool == DrawingTool.ruler;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 4,
          color: Colors.white,
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Ruler',
        padding: EdgeInsets.zero,
        onSelected: (value) {
          if (value == 'add') {
            onToolChanged(DrawingTool.ruler);
            onAddRuler();
          } else if (value == 'clear') {
            onClearRulers();
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'add',
            child: Row(children: [
              Icon(Icons.add_rounded, size: 18, color: Colors.black87),
              SizedBox(width: 10),
              Text('Add Ruler'),
            ]),
          ),
          PopupMenuItem(
            value: 'clear',
            child: Row(children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
              SizedBox(width: 10),
              Text('Clear All', style: TextStyle(color: Colors.red)),
            ]),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _isActive ? Colors.blue.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.straighten_rounded, size: 20,
              color: _isActive ? Colors.blue : Colors.black87),
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

class _SizeBtn extends StatelessWidget {
  final double strokeWidth;
  final Color color;
  final bool panelOpen;
  final VoidCallback onTap;

  const _SizeBtn({
    required this.strokeWidth,
    required this.color,
    required this.panelOpen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dotSize = (strokeWidth * 0.9).clamp(3.0, 16.0);
    return Tooltip(
      message: 'Pen size',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: panelOpen ? Colors.blue.withAlpha(20) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: panelOpen ? Colors.blue : Colors.black87,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                panelOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 14,
                color: panelOpen ? Colors.blue : Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SizePanelDropdown extends StatelessWidget {
  final double strokeWidth;
  final Color color;
  final List<double> sizePresets;
  final ValueChanged<double> onChanged;

  const _SizePanelDropdown({
    required this.strokeWidth,
    required this.color,
    required this.sizePresets,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(28),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final size in sizePresets)
                _SizePreset(
                  size: size,
                  color: color,
                  selected: strokeWidth == size,
                  onTap: () => onChanged(size),
                ),
            ],
          ),
          SizedBox(
            width: 180,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: strokeWidth.clamp(1.0, 40.0),
                min: 1,
                max: 40,
                onChanged: onChanged,
                activeColor: Colors.blue,
              ),
            ),
          ),
          Text(
            '${strokeWidth.round()} px',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
