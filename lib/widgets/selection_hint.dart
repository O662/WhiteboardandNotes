import 'package:flutter/material.dart';

import '../models/whiteboard_item.dart';

class SelectionHint extends StatelessWidget {
  final WhiteboardItem item;
  final void Function(String url) onOpenLink;
  final void Function(String path) onOpenFile;
  final VoidCallback onEditTable;
  final VoidCallback onBringToFront;
  final VoidCallback onBringForward;
  final VoidCallback onSendBackward;
  final VoidCallback onSendToBack;

  const SelectionHint({
    super.key,
    required this.item,
    required this.onOpenLink,
    required this.onOpenFile,
    required this.onEditTable,
    required this.onBringToFront,
    required this.onBringForward,
    required this.onSendBackward,
    required this.onSendToBack,
  });

  Widget _layerBtn(IconData icon, String tooltip, VoidCallback onTap) =>
      Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(icon, size: 17, color: Colors.white70),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const sep = Text(' · ',
        style: TextStyle(color: Colors.white54, fontSize: 13));
    const actionStyle = TextStyle(
        color: Color(0xFF90CAF9),
        fontSize: 13,
        decoration: TextDecoration.underline,
        decorationColor: Color(0xFF90CAF9));

    final actions = <Widget>[];

    if (item is LinkItem) {
      final link = item as LinkItem;
      actions.addAll([
        sep,
        GestureDetector(
          onTap: () => onOpenLink(link.url),
          child: const Text('Open link', style: actionStyle),
        ),
      ]);
    } else if (item is AttachmentItem) {
      final att = item as AttachmentItem;
      actions.addAll([
        sep,
        GestureDetector(
          onTap: () => onOpenFile(att.path),
          child: const Text('Open file', style: actionStyle),
        ),
      ]);
    } else if (item is VideoItem) {
      final vid = item as VideoItem;
      actions.addAll([
        sep,
        GestureDetector(
          onTap: () => onOpenFile(vid.path),
          child: const Text('Play video', style: actionStyle),
        ),
      ]);
    } else if (item is TableItem) {
      actions.addAll([
        sep,
        GestureDetector(
          onTap: onEditTable,
          child: const Text('Edit table', style: actionStyle),
        ),
      ]);
    } else if (item is PrintoutItem) {
      final pr = item as PrintoutItem;
      actions.addAll([
        sep,
        GestureDetector(
          onTap: () => onOpenFile(pr.path),
          child: const Text('Open file', style: actionStyle),
        ),
      ]);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Drag to move',
              style: TextStyle(color: Colors.white, fontSize: 13)),
          sep,
          _layerBtn(Icons.flip_to_back, 'Send to back', onSendToBack),
          _layerBtn(Icons.keyboard_arrow_down, 'Send backward', onSendBackward),
          _layerBtn(Icons.keyboard_arrow_up, 'Bring forward', onBringForward),
          _layerBtn(Icons.flip_to_front, 'Bring to front', onBringToFront),
          ...actions,
          sep,
          const Text('Delete to remove',
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}
