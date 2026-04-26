import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/whiteboard_item.dart';

class ImageCard extends StatelessWidget {
  final ImageItem item;
  const ImageCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final file = File(item.path);
    if (!file.existsSync()) {
      return Container(
        color: Colors.grey.shade100,
        child: Center(
            child: Icon(Icons.broken_image_outlined,
                color: Colors.grey.shade400, size: 40)),
      );
    }
    return Image.file(file, fit: BoxFit.contain, gaplessPlayback: true);
  }
}

class TableCard extends StatelessWidget {
  final TableItem item;
  final double scale;
  const TableCard({super.key, required this.item, required this.scale});

  @override
  Widget build(BuildContext context) {
    final fontSize = (12.0 / scale).clamp(10.0, 16.0);
    return Container(
      color: Colors.white,
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade400, width: 0.5),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          for (int r = 0; r < item.rows; r++)
            TableRow(
              decoration: BoxDecoration(
                  color: r == 0 ? Colors.grey.shade100 : Colors.white),
              children: [
                for (int c = 0; c < item.cols; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    child: Text(
                      item.cells[r][c].isEmpty && r == 0
                          ? 'Col ${c + 1}'
                          : item.cells[r][c],
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight:
                            r == 0 ? FontWeight.w600 : FontWeight.normal,
                        color: item.cells[r][c].isEmpty && r == 0
                            ? Colors.grey.shade400
                            : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class AttachmentCard extends StatelessWidget {
  final AttachmentItem item;
  const AttachmentCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final ext = item.filename.contains('.')
        ? item.filename.split('.').last.toUpperCase()
        : 'FILE';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade200),
            ),
            alignment: Alignment.center,
            child: Text(ext,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.filename,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Select → Open file',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Icon(Icons.open_in_new_rounded,
              size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}

class LinkCard extends StatelessWidget {
  final LinkItem item;
  const LinkCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: Colors.blue.shade50, shape: BoxShape.circle),
            child: Icon(Icons.link_rounded,
                color: Colors.blue.shade600, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.black87),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(item.url,
                    style:
                        TextStyle(fontSize: 11, color: Colors.blue.shade400),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.open_in_new_rounded,
              size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}

class VideoCard extends StatelessWidget {
  final VideoItem item;
  const VideoCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_rounded,
              size: 56, color: Colors.white70),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(item.filename,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 4),
          Text('Select → Play video',
              style:
                  TextStyle(color: Colors.white.withAlpha(100), fontSize: 11)),
        ],
      ),
    );
  }
}

class PrintoutCard extends StatelessWidget {
  final PrintoutItem item;
  const PrintoutCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final ext = item.extension;
    final isPdf = ext == 'pdf';
    final color = isPdf ? Colors.red.shade600 : Colors.blue.shade600;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8)),
            ),
            child: Row(children: [
              Icon(
                  isPdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.description_outlined,
                  color: color,
                  size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.filename,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: color),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.description_outlined,
                      size: 64,
                      color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(ext.toUpperCase(),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade400)),
                  const SizedBox(height: 4),
                  Text('Select → Open file',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade400)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChecklistCard extends StatefulWidget {
  final ChecklistItem item;
  final void Function(ChecklistItem) onUpdate;
  const ChecklistCard({super.key, required this.item, required this.onUpdate});

  @override
  State<ChecklistCard> createState() => _ChecklistCardState();
}

class _ChecklistCardState extends State<ChecklistCard> {
  final _newItemController = TextEditingController();

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  void _toggle(int i) {
    final entries = [...widget.item.entries];
    entries[i] = entries[i].copyWith(checked: !entries[i].checked);
    widget.onUpdate(widget.item.withEntries(entries));
  }

  void _addEntry(String text) {
    if (text.trim().isEmpty) return;
    final entries = [...widget.item.entries, ChecklistEntry(text: text.trim())];
    widget.onUpdate(widget.item.withEntries(entries));
    _newItemController.clear();
  }

  void _removeEntry(int i) {
    final entries = [...widget.item.entries]..removeAt(i);
    widget.onUpdate(widget.item.withEntries(entries));
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.item.entries.where((e) => e.checked).length;
    final total = widget.item.entries.length;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withAlpha(20),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.checklist_rounded, size: 15, color: Color(0xFF7C3AED)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(widget.item.title,
                      style: const TextStyle(fontWeight: FontWeight.w600,
                          fontSize: 13, color: Color(0xFF7C3AED))),
                ),
                if (total > 0)
                  Text('$done/$total',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          for (int i = 0; i < widget.item.entries.length; i++)
            InkWell(
              onTap: () => _toggle(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  children: [
                    Icon(
                      widget.item.entries[i].checked
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 18,
                      color: widget.item.entries[i].checked
                          ? const Color(0xFF7C3AED)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.item.entries[i].text,
                        style: TextStyle(
                          fontSize: 13,
                          decoration: widget.item.entries[i].checked
                              ? TextDecoration.lineThrough
                              : null,
                          color: widget.item.entries[i].checked
                              ? Colors.grey.shade400
                              : Colors.black87,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removeEntry(i),
                      child: Icon(Icons.close, size: 14, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Row(
              children: [
                Icon(Icons.add_rounded, size: 18, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _newItemController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Add item…',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: _addEntry,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DateTimeCard extends StatefulWidget {
  final DateTimeItem item;
  const DateTimeCard({super.key, required this.item});

  @override
  State<DateTimeCard> createState() => _DateTimeCardState();
}

class _DateTimeCardState extends State<DateTimeCard> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    if (widget.item.isLive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m:$s $period';
  }

  String _fmtDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final dt = widget.item.isLive ? _now : widget.item.createdAt;
    final mode = widget.item.mode;
    final accentColor = widget.item.isLive
        ? const Color(0xFF1E88E5)
        : const Color(0xFF6D4C41);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.item.isLive ? Icons.radio_button_checked : Icons.push_pin_rounded,
                size: 11,
                color: accentColor,
              ),
              const SizedBox(width: 4),
              Text(
                widget.item.isLive ? 'LIVE' : 'STATIC',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (mode == DateTimeMode.time || mode == DateTimeMode.datetime)
            Text(_fmtTime(dt),
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w300, color: Colors.black87)),
          if (mode == DateTimeMode.date || mode == DateTimeMode.datetime)
            Padding(
              padding: EdgeInsets.only(
                  top: mode == DateTimeMode.datetime ? 2 : 0),
              child: Text(_fmtDate(dt),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ),
        ],
      ),
    );
  }
}

// ── Placeholder card ───────────────────────────────────────────────────────

class PlaceholderCard extends StatelessWidget {
  final PlaceholderItem item;

  const PlaceholderCard({super.key, required this.item});

  static (IconData, String, Color) _meta(PlaceholderType t) => switch (t) {
        PlaceholderType.image => (Icons.image_outlined, 'Picture', const Color(0xFF43A047)),
        PlaceholderType.file  => (Icons.attach_file_rounded, 'File', const Color(0xFFFB8C00)),
        PlaceholderType.link  => (Icons.link_rounded, 'Link', const Color(0xFF5E35B1)),
        PlaceholderType.video => (Icons.play_circle_outline_rounded, 'Video', const Color(0xFFE53935)),
        PlaceholderType.doc   => (Icons.description_outlined, 'Doc', const Color(0xFFEF6C00)),
        PlaceholderType.pdf   => (Icons.picture_as_pdf_rounded, 'PDF', const Color(0xFFD32F2F)),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = _meta(item.placeholderType);
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withAlpha(18), Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80), width: 1.5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: color.withAlpha(160)),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color.withAlpha(160))),
              // Replace button is rendered as a live interactive overlay in
              // whiteboard_screen.dart so it stays correctly positioned at all zoom levels.
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
