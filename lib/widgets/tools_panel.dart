import 'package:flutter/material.dart';
import '../models/stroke.dart';

class ToolsPanel extends StatelessWidget {
  final DrawingTool selectedTool;
  final ValueChanged<DrawingTool> onToolChanged;
  final VoidCallback onAddRuler;
  final VoidCallback onClearRulers;

  const ToolsPanel({
    super.key,
    required this.selectedTool,
    required this.onToolChanged,
    required this.onAddRuler,
    required this.onClearRulers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
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
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Tools',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
          ),
          _ToolItem(
            icon: Icons.straighten_rounded,
            color: const Color(0xFF1E88E5),
            label: 'Ruler',
            selected: selectedTool == DrawingTool.ruler,
            onTap: () {
              onToolChanged(DrawingTool.ruler);
              onAddRuler();
            },
            trailing: selectedTool == DrawingTool.ruler
                ? TextButton(
                    onPressed: onClearRulers,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Clear',
                        style: TextStyle(fontSize: 11, color: Colors.black38)),
                  )
                : null,
          ),
          _ToolItem(
            icon: Icons.ads_click_rounded,
            color: const Color(0xFFE53935),
            label: 'Laser Pointer',
            selected: selectedTool == DrawingTool.laser,
            onTap: () => onToolChanged(DrawingTool.laser),
          ),
        ],
      ),
    );
  }
}

class _ToolItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ToolItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? color : Colors.black87)),
            ),
            if (selected && trailing == null)
              Icon(Icons.check_rounded, size: 15, color: color),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
