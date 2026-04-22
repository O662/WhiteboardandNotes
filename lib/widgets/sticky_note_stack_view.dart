import 'package:flutter/material.dart';
import '../models/whiteboard_item.dart';

class StickyNoteStackViewDialog extends StatelessWidget {
  final StickyNoteStackItem stack;
  final void Function(int promotedIndex) onPromote;

  const StickyNoteStackViewDialog({
    super.key,
    required this.stack,
    required this.onPromote,
  });

  static Future<void> show(
    BuildContext context,
    StickyNoteStackItem stack,
    void Function(int) onPromote,
  ) {
    return showDialog(
      context: context,
      builder: (_) => StickyNoteStackViewDialog(stack: stack, onPromote: onPromote),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.layers_rounded, size: 18, color: Color(0xFF666666)),
          const SizedBox(width: 8),
          Text('Stack (${stack.notes.length} notes)'),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: 340,
        child: stack.notes.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'This stack is empty. Drag from it to create notes.',
                  style: TextStyle(color: Color(0xFF888888)),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: stack.notes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final note = stack.notes[i];
                  final isTop = i == 0;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onPromote(i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: note.color,
                        borderRadius: BorderRadius.circular(8),
                        border: isTop
                            ? Border.all(color: Colors.blue.shade400, width: 2)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 6,
                            offset: const Offset(1, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(28),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8)),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 8),
                                if (isTop)
                                  const Text(
                                    'TOP',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                const Spacer(),
                                Text(
                                  '#${i + 1}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0x88000000),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              note.text.isEmpty ? '(blank note)' : note.text,
                              style: TextStyle(
                                fontSize: 13,
                                color: note.text.isEmpty
                                    ? const Color(0x66333333)
                                    : const Color(0xFF333333),
                                fontStyle: note.text.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isTop)
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: 10, bottom: 8),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Tap to bring to top',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
