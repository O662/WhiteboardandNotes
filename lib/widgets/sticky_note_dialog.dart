import 'package:flutter/material.dart';

/// Result returned when the user taps "Add".
typedef StickyNoteResult = ({String text, Color color});

class StickyNoteDialog extends StatefulWidget {
  const StickyNoteDialog({super.key});

  /// Convenience: show the dialog and return the result, or null if cancelled.
  static Future<StickyNoteResult?> show(BuildContext context) {
    return showDialog<StickyNoteResult>(
      context: context,
      builder: (_) => const StickyNoteDialog(),
    );
  }

  @override
  State<StickyNoteDialog> createState() => _StickyNoteDialogState();
}

class _StickyNoteDialogState extends State<StickyNoteDialog> {
  static const _colors = [
    Color(0xFFFFF9C4),
    Color(0xFFB3E5FC),
    Color(0xFFC8E6C9),
    Color(0xFFFFCDD2),
  ];

  String _text = '';
  Color _color = const Color(0xFFFFF9C4);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Sticky Note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Note text...',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _text = v,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Color:', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              for (final c in _colors)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == c ? Colors.blue : Colors.grey.shade400,
                        width: _color == c ? 2.5 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (text: _text, color: _color)),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
