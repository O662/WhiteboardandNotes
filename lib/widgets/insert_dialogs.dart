import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/whiteboard_item.dart';
import 'shape_picker_panel.dart';
import 'insert_panel.dart';

class ShapeConfigResult {
  final double width;
  final double height;
  final bool filled;
  final Color fillColor;
  const ShapeConfigResult({
    required this.width,
    required this.height,
    required this.filled,
    required this.fillColor,
  });
}

Future<ShapeConfigResult?> showShapeConfigDialog(
  BuildContext context,
  ShapeType type,
  Color strokeColor,
  double strokeWidth,
) async {
  double w = ShapeItem.defaultWidth(type).toDouble();
  double h = ShapeItem.defaultHeight(type).toDouble();
  if (h == 0) h = 8;
  bool filled = false;
  Color fillColor = strokeColor.withAlpha(60);
  bool confirmed = false;

  final fillColors = [
    strokeColor.withAlpha(60),
    Colors.red.withAlpha(60),
    Colors.green.withAlpha(60),
    Colors.blue.withAlpha(60),
    Colors.amber.withAlpha(60),
    Colors.purple.withAlpha(60),
  ];

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text('Insert ${ShapeItem.labelFor(type)}'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: CustomPaint(
                    size: _shapePreviewSize(type, w, h),
                    painter: ShapePreviewPainter(
                      type: type,
                      strokeColor: strokeColor,
                      strokeWidth: strokeWidth,
                      filled: filled,
                      fillColor: fillColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (type != ShapeType.line) ...[
                Row(children: [
                  const SizedBox(
                      width: 54,
                      child: Text('Width', style: TextStyle(fontSize: 13))),
                  Expanded(
                    child: Slider(
                      value: w, min: 50, max: 1200, divisions: 115,
                      onChanged: (v) => set(() => w = v),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('${w.round()}',
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.right),
                  ),
                ]),
                Row(children: [
                  const SizedBox(
                      width: 54,
                      child: Text('Height', style: TextStyle(fontSize: 13))),
                  Expanded(
                    child: Slider(
                      value: h, min: 50, max: 1200, divisions: 115,
                      onChanged: (v) => set(() => h = v),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('${h.round()}',
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.right),
                  ),
                ]),
              ] else ...[
                Row(children: [
                  const SizedBox(
                      width: 54,
                      child: Text('Length', style: TextStyle(fontSize: 13))),
                  Expanded(
                    child: Slider(
                      value: w, min: 50, max: 1200, divisions: 115,
                      onChanged: (v) => set(() => w = v),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('${w.round()}',
                        style: const TextStyle(fontSize: 13),
                        textAlign: TextAlign.right),
                  ),
                ]),
              ],
              if (type != ShapeType.line) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Text('Fill', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  Switch(
                    value: filled,
                    onChanged: (v) => set(() => filled = v),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  if (filled) ...[
                    const SizedBox(width: 8),
                    for (final c in fillColors)
                      GestureDetector(
                        onTap: () => set(() => fillColor = c),
                        child: Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: fillColor == c
                                  ? Colors.blue
                                  : Colors.grey.shade400,
                              width: fillColor == c ? 2 : 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ]),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              confirmed = true;
              Navigator.pop(ctx);
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    ),
  );

  if (!confirmed) return null;
  return ShapeConfigResult(width: w, height: h, filled: filled, fillColor: fillColor);
}

Size _shapePreviewSize(ShapeType type, double w, double h) {
  const maxW = 140.0;
  const maxH = 72.0;
  if (type == ShapeType.line) return const Size(maxW, 2);
  final scaleW = w > maxW ? maxW / w : 1.0;
  final scaleH = h > maxH ? maxH / h : 1.0;
  final scale = scaleW < scaleH ? scaleW : scaleH;
  return Size((w * scale).clamp(20, maxW), (h * scale).clamp(10, maxH));
}

Future<({int rows, int cols})?> showInsertTableDialog(BuildContext context) async {
  int rows = 3, cols = 3;
  bool confirmed = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Insert Table'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const SizedBox(width: 40, child: Text('Rows')),
              const SizedBox(width: 16),
              NumberStepper(
                  value: rows, min: 1, max: 20,
                  onChanged: (v) => set(() => rows = v)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const SizedBox(width: 40, child: Text('Cols')),
              const SizedBox(width: 16),
              NumberStepper(
                  value: cols, min: 1, max: 10,
                  onChanged: (v) => set(() => cols = v)),
            ]),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              confirmed = true;
              Navigator.pop(ctx);
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    ),
  );

  if (!confirmed) return null;
  return (rows: rows, cols: cols);
}

Future<({String url, String label})?> showInsertLinkDialog(BuildContext context) async {
  String url = '', label = '';
  bool confirmed = false;

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Insert Link'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => url = v,
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => label = v,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (url.isNotEmpty) {
              confirmed = true;
              Navigator.pop(ctx);
            }
          },
          child: const Text('Insert'),
        ),
      ],
    ),
  );

  if (!confirmed || url.isEmpty) return null;
  return (url: url, label: label.isEmpty ? url : label);
}

Future<List<int>?> showImportPdfPagesDialog(BuildContext context, int pageCount) async {
  List<bool> selected = List.filled(pageCount, true);
  bool confirmed = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Import PDF Pages'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 280,
          height: math.min(pageCount * 44.0 + 60, 320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$pageCount pages — select which to import:',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: pageCount,
                  itemBuilder: (_, i) => CheckboxListTile(
                    dense: true,
                    title: Text('Page ${i + 1}'),
                    value: selected[i],
                    onChanged: (v) => set(() => selected[i] = v ?? false),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => set(() => selected = List.filled(pageCount, true)),
            child: const Text('All'),
          ),
          FilledButton(
            onPressed: () {
              confirmed = true;
              Navigator.pop(ctx);
            },
            child: const Text('Import'),
          ),
        ],
      ),
    ),
  );

  if (!confirmed) return null;
  return [
    for (int i = 0; i < selected.length; i++)
      if (selected[i]) i,
  ];
}

Future<List<List<String>>?> showEditTableDialog(
    BuildContext context, TableItem table) async {
  final cells = List.generate(
      table.rows, (r) => List<String>.from(table.cells[r]));
  List<List<String>>? result;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Edit Table'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int r = 0; r < table.rows; r++)
                Row(
                  children: [
                    for (int c = 0; c < table.cols; c++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: TextField(
                            controller: TextEditingController(text: cells[r][c]),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              border: const OutlineInputBorder(),
                              fillColor: r == 0 ? Colors.grey.shade100 : null,
                              filled: r == 0,
                            ),
                            style: TextStyle(
                              fontWeight: r == 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                            onChanged: (v) => cells[r][c] = v,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              result = cells;
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  return result;
}
