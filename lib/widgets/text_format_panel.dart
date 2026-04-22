import 'package:flutter/material.dart';

class TextFormatPanel extends StatelessWidget {
  final double fontSize;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final String fontFamily;
  final Color color;
  final TextAlign textAlign;
  final int indentLevel;
  final bool bullet;
  final double lineHeight;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<bool> onBoldChanged;
  final ValueChanged<bool> onItalicChanged;
  final ValueChanged<bool> onUnderlineChanged;
  final ValueChanged<bool> onStrikethroughChanged;
  final ValueChanged<String> onFontFamilyChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<TextAlign> onAlignChanged;
  final ValueChanged<int> onIndentChanged;
  final ValueChanged<bool> onBulletChanged;
  final ValueChanged<double> onLineHeightChanged;
  final VoidCallback onClearFormatting;

  const TextFormatPanel({
    super.key,
    required this.fontSize,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strikethrough,
    required this.fontFamily,
    required this.color,
    required this.textAlign,
    required this.indentLevel,
    required this.bullet,
    required this.lineHeight,
    required this.onFontSizeChanged,
    required this.onBoldChanged,
    required this.onItalicChanged,
    required this.onUnderlineChanged,
    required this.onStrikethroughChanged,
    required this.onFontFamilyChanged,
    required this.onColorChanged,
    required this.onAlignChanged,
    required this.onIndentChanged,
    required this.onBulletChanged,
    required this.onLineHeightChanged,
    required this.onClearFormatting,
  });

  static const _fonts = [
    ('System', ''),
    ('Arial', 'Arial'),
    ('Calibri', 'Calibri'),
    ('Courier New', 'Courier New'),
    ('Georgia', 'Georgia'),
    ('Times New Roman', 'Times New Roman'),
    ('Verdana', 'Verdana'),
  ];

  static const _quickColors = [
    Color(0xFF000000),
    Color(0xFFE53935),
    Color(0xFF1E88E5),
  ];

  static const _paletteColors = [
    Color(0xFF000000), Color(0xFF424242), Color(0xFF757575), Color(0xFFBDBDBD), Color(0xFFFFFFFF),
    Color(0xFF8B0000), Color(0xFFE53935), Color(0xFFFF5252), Color(0xFFEC407A), Color(0xFFF48FB1),
    Color(0xFFE65100), Color(0xFFF57C00), Color(0xFFFFD600), Color(0xFFFFEE58), Color(0xFFFFF9C4),
    Color(0xFF1B5E20), Color(0xFF43A047), Color(0xFF26A69A), Color(0xFF00BCD4), Color(0xFFB3E5FC),
    Color(0xFF0D47A1), Color(0xFF1E88E5), Color(0xFF3F51B5), Color(0xFF7B1FA2), Color(0xFFEA80FC),
  ];

  String get _styleLabel {
    if (fontSize >= 48) return 'Title';
    if (fontSize >= 32) return 'Heading 1';
    if (fontSize >= 24) return 'Heading 2';
    if (fontSize >= 18) return 'Heading 3';
    return 'Normal';
  }

  String get _fontLabel => fontFamily.isEmpty ? 'System' : fontFamily;

  IconData get _alignIcon => switch (textAlign) {
        TextAlign.center => Icons.format_align_center,
        TextAlign.right => Icons.format_align_right,
        TextAlign.justify => Icons.format_align_justify,
        _ => Icons.format_align_left,
      };

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
              const Text('Text Color',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
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
                                color: color == c
                                    ? Colors.blue
                                    : Colors.grey.shade300,
                                width: color == c ? 2.5 : 1,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(28),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRow1(context),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
            _buildRow2(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRow1(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PillDropdown<double>(
          label: _styleLabel,
          items: const [
            PopupMenuItem(value: 56.0, child: Text('Title', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
            PopupMenuItem(value: 36.0, child: Text('Heading 1', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            PopupMenuItem(value: 28.0, child: Text('Heading 2', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            PopupMenuItem(value: 22.0, child: Text('Heading 3', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
            PopupMenuItem(value: 16.0, child: Text('Normal', style: TextStyle(fontSize: 14))),
          ],
          onSelected: onFontSizeChanged,
        ),
        _divider(),
        _SizeStepper(fontSize: fontSize, onChanged: onFontSizeChanged),
        _divider(),
        _FmtToggle(icon: Icons.format_bold, tooltip: 'Bold', active: bold, onTap: () => onBoldChanged(!bold)),
        _FmtToggle(icon: Icons.format_italic, tooltip: 'Italic', active: italic, onTap: () => onItalicChanged(!italic)),
        _FmtToggle(icon: Icons.format_underline, tooltip: 'Underline', active: underline, onTap: () => onUnderlineChanged(!underline)),
        _FmtToggle(icon: Icons.format_strikethrough, tooltip: 'Strikethrough', active: strikethrough, onTap: () => onStrikethroughChanged(!strikethrough)),
        _divider(),
        _FmtBtn(icon: Icons.superscript, tooltip: 'Superscript / Subscript'),
        _FmtBtn(icon: Icons.link, tooltip: 'Link'),
        _FmtToggle(icon: Icons.format_clear, tooltip: 'Clear Formatting', active: false, onTap: onClearFormatting),
        _FmtBtn(icon: Icons.format_paint, tooltip: 'Copy Format'),
        _FmtBtn(icon: Icons.content_cut, tooltip: 'Cut'),
      ],
    );
  }

  Widget _buildRow2(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PillDropdown<String>(
          label: _fontLabel,
          items: [
            for (final (name, family) in _fonts)
              PopupMenuItem(
                value: family,
                child: Text(name,
                    style: TextStyle(
                        fontFamily: family.isEmpty ? null : family,
                        fontSize: 14)),
              ),
          ],
          onSelected: onFontFamilyChanged,
        ),
        _divider(),
        for (final c in _quickColors)
          GestureDetector(
            onTap: () => onColorChanged(c),
            child: Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: color == c ? Colors.blue : Colors.grey.shade300,
                  width: color == c ? 2.5 : 1.5,
                ),
              ),
            ),
          ),
        Tooltip(
          message: 'More colors',
          child: InkWell(
            onTap: () => _openPalette(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                gradient: const SweepGradient(colors: [
                  Colors.red, Colors.orange, Colors.yellow,
                  Colors.green, Colors.blue, Colors.purple, Colors.red,
                ]),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
            ),
          ),
        ),
        _FmtBtn(icon: Icons.highlight, tooltip: 'Highlight'),
        _divider(),
        _FmtToggle(
          icon: Icons.format_indent_decrease,
          tooltip: 'Decrease Indent',
          active: false,
          onTap: indentLevel > 0 ? () => onIndentChanged(indentLevel - 1) : () {},
        ),
        _FmtToggle(
          icon: Icons.format_indent_increase,
          tooltip: 'Increase Indent',
          active: false,
          onTap: () => onIndentChanged(indentLevel + 1),
        ),
        _divider(),
        PopupMenuButton<TextAlign>(
          tooltip: 'Alignment',
          padding: EdgeInsets.zero,
          icon: Icon(_alignIcon, size: 18, color: Colors.black87),
          onSelected: onAlignChanged,
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: TextAlign.left, child: Row(children: [Icon(Icons.format_align_left, size: 18), SizedBox(width: 8), Text('Left')])),
            PopupMenuItem(value: TextAlign.center, child: Row(children: [Icon(Icons.format_align_center, size: 18), SizedBox(width: 8), Text('Center')])),
            PopupMenuItem(value: TextAlign.right, child: Row(children: [Icon(Icons.format_align_right, size: 18), SizedBox(width: 8), Text('Right')])),
            PopupMenuItem(value: TextAlign.justify, child: Row(children: [Icon(Icons.format_align_justify, size: 18), SizedBox(width: 8), Text('Justify')])),
          ],
        ),
        _FmtToggle(
          icon: Icons.format_list_bulleted,
          tooltip: 'Bullet List',
          active: bullet,
          onTap: () => onBulletChanged(!bullet),
        ),
        PopupMenuButton<double>(
          tooltip: 'Line Height',
          padding: EdgeInsets.zero,
          icon: Icon(Icons.format_line_spacing, size: 18,
              color: lineHeight != 1.2 ? Colors.blue : Colors.black87),
          onSelected: onLineHeightChanged,
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 1.0, child: Text('Single (1.0)')),
            PopupMenuItem(value: 1.2, child: Text('Default (1.2)')),
            PopupMenuItem(value: 1.5, child: Text('1.5')),
            PopupMenuItem(value: 1.8, child: Text('1.8')),
            PopupMenuItem(value: 2.0, child: Text('Double (2.0)')),
          ],
        ),
        _divider(),
        _FmtBtn(icon: Icons.copy, tooltip: 'Copy'),
        _FmtBtn(icon: Icons.paste, tooltip: 'Paste'),
      ],
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(height: 22, child: VerticalDivider(width: 1, thickness: 1)),
      );
}

class _PillDropdown<T> extends StatelessWidget {
  final String label;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  const _PillDropdown({
    required this.label,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (_) => items,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 14, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

class _SizeStepper extends StatefulWidget {
  final double fontSize;
  final ValueChanged<double> onChanged;

  const _SizeStepper({required this.fontSize, required this.onChanged});

  @override
  State<_SizeStepper> createState() => _SizeStepperState();
}

class _SizeStepperState extends State<_SizeStepper> {
  bool _editing = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.fontSize.toInt().toString());
  }

  @override
  void didUpdateWidget(_SizeStepper old) {
    super.didUpdateWidget(old);
    if (!_editing) _ctrl.text = widget.fontSize.toInt().toString();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _commit() {
    final v = double.tryParse(_ctrl.text);
    if (v != null) {
      widget.onChanged(v.clamp(8.0, 144.0));
    } else {
      _ctrl.text = widget.fontSize.toInt().toString();
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(
          icon: Icons.remove,
          onTap: widget.fontSize > 8
              ? () => widget.onChanged((widget.fontSize - 1).clamp(8.0, 144.0))
              : null,
        ),
        if (_editing)
          SizedBox(
            width: 34,
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 3),
                border: UnderlineInputBorder(),
              ),
              onSubmitted: (_) => _commit(),
              onEditingComplete: _commit,
            ),
          )
        else
          GestureDetector(
            onTap: () {
              _ctrl.text = widget.fontSize.toInt().toString();
              setState(() => _editing = true);
            },
            child: Container(
              width: 34,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.fontSize.toInt().toString(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        _StepBtn(
          icon: Icons.add,
          onTap: widget.fontSize < 144
              ? () => widget.onChanged((widget.fontSize + 1).clamp(8.0, 144.0))
              : null,
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        child: Icon(icon, size: 14,
            color: onTap != null ? Colors.black87 : Colors.black26),
      ),
    );
  }
}

class _FmtToggle extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  const _FmtToggle({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: active ? Colors.blue.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18,
              color: active ? Colors.blue : Colors.black87),
        ),
      ),
    );
  }
}

class _FmtBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;

  const _FmtBtn({required this.icon, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: Colors.black38),
      ),
    );
  }
}
