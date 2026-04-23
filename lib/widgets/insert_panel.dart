import 'package:flutter/material.dart';

enum InsertDragType { table, checklist, liveTime, liveDate, liveClock, timestamp }

class InsertPanel extends StatefulWidget {
  final VoidCallback onImage;
  final VoidCallback onTable;
  final VoidCallback onAttachment;
  final VoidCallback onLink;
  final VoidCallback onVideo;
  final VoidCallback onPrintout;
  final VoidCallback onPdf;
  final VoidCallback onChecklist;
  final VoidCallback onLiveTime;
  final VoidCallback onLiveDate;
  final VoidCallback onLiveClock;
  final VoidCallback onTimestamp;
  final VoidCallback onGenerate;
  final VoidCallback? onDragStarted;

  const InsertPanel({
    super.key,
    required this.onImage,
    required this.onTable,
    required this.onAttachment,
    required this.onLink,
    required this.onVideo,
    required this.onPrintout,
    required this.onPdf,
    required this.onChecklist,
    required this.onLiveTime,
    required this.onLiveDate,
    required this.onLiveClock,
    required this.onTimestamp,
    required this.onGenerate,
    this.onDragStarted,
  });

  @override
  State<InsertPanel> createState() => _InsertPanelState();
}

class _InsertPanelState extends State<InsertPanel> {
  int _tab = 0;

  // (icon, label, color, onTap, dragType) — null dragType = tap-only
  List<(IconData, String, Color, VoidCallback, InsertDragType?)> get _mediaOptions => [
    (Icons.image_outlined, 'Picture', const Color(0xFF43A047), widget.onImage, null),
    (Icons.table_chart_outlined, 'Table', const Color(0xFF1E88E5), widget.onTable, InsertDragType.table),
    (Icons.attach_file_rounded, 'File', const Color(0xFFFB8C00), widget.onAttachment, null),
    (Icons.link_rounded, 'Link', const Color(0xFF5E35B1), widget.onLink, null),
    (Icons.play_circle_outline_rounded, 'Video', const Color(0xFFE53935), widget.onVideo, null),
    (Icons.description_outlined, 'Doc', const Color(0xFFEF6C00), widget.onPrintout, null),
    (Icons.picture_as_pdf_rounded, 'PDF', const Color(0xFFD32F2F), widget.onPdf, null),
  ];

  List<(IconData, String, Color, VoidCallback, InsertDragType?)> get _widgetOptions => [
    (Icons.checklist_rounded, 'Checklist', const Color(0xFF7C3AED), widget.onChecklist, InsertDragType.checklist),
    (Icons.schedule_rounded, 'Live Time', const Color(0xFF0097A7), widget.onLiveTime, InsertDragType.liveTime),
    (Icons.calendar_today_rounded, 'Live Date', const Color(0xFF00897B), widget.onLiveDate, InsertDragType.liveDate),
    (Icons.watch_later_rounded, 'Live Clock', const Color(0xFF1E88E5), widget.onLiveClock, InsertDragType.liveClock),
    (Icons.push_pin_rounded, 'Timestamp', const Color(0xFF6D4C41), widget.onTimestamp, InsertDragType.timestamp),
  ];

  Widget _tabBtn(int idx, String label) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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

  Widget _cell(IconData icon, String label, Color color, VoidCallback onTap, InsertDragType? dragType) {
    final inner = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withAlpha(38), Colors.white),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
    if (dragType == null) return inner;
    return Draggable<InsertDragType>(
      data: dragType,
      onDragStarted: widget.onDragStarted,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Color.alphaBlend(color.withAlpha(38), Colors.white),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: inner),
      child: inner,
    );
  }

  Widget _grid(List<(IconData, String, Color, VoidCallback, InsertDragType?)> opts) =>
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
        children: [
          for (final (icon, label, color, onTap, dragType) in opts)
            _cell(icon, label, color, onTap, dragType),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 196,
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
          Row(
            children: [
              _tabBtn(0, 'Media'),
              const SizedBox(width: 6),
              _tabBtn(1, 'Widgets'),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: SingleChildScrollView(
              child: _tab == 0 ? _grid(_mediaOptions) : _grid(_widgetOptions),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: widget.onGenerate,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 15, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Generate',
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
      ),
    );
  }
}

class NumberStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const NumberStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_rounded, size: 18),
          onPressed: value > min ? () => onChanged(value - 1) : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        SizedBox(
          width: 32,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        IconButton(
          icon: const Icon(Icons.add_rounded, size: 18),
          onPressed: value < max ? () => onChanged(value + 1) : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}
