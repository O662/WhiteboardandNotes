import 'package:flutter/material.dart';
import '../models/stroke.dart';

class WhiteboardLeftSidebar extends StatelessWidget {
  final DrawingTool selectedTool;
  final ValueChanged<DrawingTool> onToolChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onInsert;
  final VoidCallback onMath;
  final VoidCallback onFrame;
  final VoidCallback onShape;
  final VoidCallback onStickyNote;
  final bool mathPanelOpen;
  final bool framePanelOpen;
  final bool shapePanelOpen;
  final bool stickyNotePanelOpen;

  const WhiteboardLeftSidebar({
    super.key,
    required this.selectedTool,
    required this.onToolChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onInsert,
    required this.onMath,
    required this.onFrame,
    required this.onShape,
    required this.onStickyNote,
    this.mathPanelOpen = false,
    this.framePanelOpen = false,
    this.shapePanelOpen = false,
    this.stickyNotePanelOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(28),
              blurRadius: 14,
              offset: const Offset(2, 0))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SideBtn(icon: Icons.undo_rounded, tooltip: 'Undo (Ctrl+Z)', onTap: onUndo),
          _SideBtn(icon: Icons.redo_rounded, tooltip: 'Redo (Ctrl+Y)', onTap: onRedo),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: Divider(height: 1),
          ),
          _SideBtn(
            icon: Icons.crop_square_rounded,
            tooltip: 'Frame',
            selected: framePanelOpen,
            onTap: onFrame,
          ),
          _SideBtn(
            icon: Icons.sticky_note_2_outlined,
            tooltip: 'Sticky Notes',
            selected: stickyNotePanelOpen,
            onTap: onStickyNote,
          ),

          _SideBtn(
            icon: Icons.category_outlined,
            tooltip: 'Shape',
            selected: shapePanelOpen,
            onTap: onShape,
          ),
          _SideBtn(
            icon: Icons.functions_rounded,
            tooltip: 'Math',
            selected: mathPanelOpen,
            onTap: onMath,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: Divider(height: 1),
          ),
          _SideBtn(
            icon: Icons.add_box_outlined,
            tooltip: 'Insert',
            onTap: onInsert,
          ),
        ],
      ),
    );
  }
}

class _SideBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _SideBtn({
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: selected ? Colors.blue.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20,
              color: selected ? Colors.blue : Colors.black87),
        ),
      ),
    );
  }
}
