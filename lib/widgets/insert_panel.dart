import 'package:flutter/material.dart';

class InsertPanel extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    final mediaOptions = [
      (Icons.image_outlined, 'Picture', const Color(0xFF43A047), onImage),
      (Icons.table_chart_outlined, 'Table', const Color(0xFF1E88E5), onTable),
      (Icons.attach_file_rounded, 'File', const Color(0xFFFB8C00), onAttachment),
      (Icons.link_rounded, 'Link', const Color(0xFF5E35B1), onLink),
      (Icons.play_circle_outline_rounded, 'Video', const Color(0xFFE53935), onVideo),
      (Icons.description_outlined, 'Doc', const Color(0xFFEF6C00), onPrintout),
      (Icons.picture_as_pdf_rounded, 'PDF', const Color(0xFFD32F2F), onPdf),
    ];

    final widgetOptions = [
      (Icons.checklist_rounded, 'Checklist', const Color(0xFF7C3AED), onChecklist),
      (Icons.schedule_rounded, 'Live Time', const Color(0xFF0097A7), onLiveTime),
      (Icons.calendar_today_rounded, 'Live Date', const Color(0xFF00897B), onLiveDate),
      (Icons.watch_later_rounded, 'Live Clock', const Color(0xFF1E88E5), onLiveClock),
      (Icons.push_pin_rounded, 'Timestamp', const Color(0xFF6D4C41), onTimestamp),
    ];

    Widget sectionGrid(List<(IconData, String, Color, VoidCallback)> opts) =>
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
          children: [
            for (final (icon, label, color, onTap) in opts)
              InkWell(
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
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text('Media',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500, letterSpacing: 0.8)),
          ),
          sectionGrid(mediaOptions),
          const SizedBox(height: 10),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text('Widgets',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500, letterSpacing: 0.8)),
          ),
          sectionGrid(widgetOptions),
          const SizedBox(height: 10),
          InkWell(
            onTap: onGenerate,
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
