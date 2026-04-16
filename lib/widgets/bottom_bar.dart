import 'package:flutter/material.dart';
import '../painters/whiteboard_painter.dart';

class WhiteboardBottomBar extends StatelessWidget {
  final double zoomLevel;
  final BackgroundStyle backgroundStyle;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomReset;
  final ValueChanged<BackgroundStyle> onBackgroundStyleChanged;

  const WhiteboardBottomBar({
    super.key,
    required this.zoomLevel,
    required this.backgroundStyle,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onZoomReset,
    required this.onBackgroundStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (zoomLevel * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(28),
              blurRadius: 12,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Background style toggle
          Tooltip(
            message: 'Background: ${backgroundStyle.name}',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                final next = BackgroundStyle.values[
                    (backgroundStyle.index + 1) % BackgroundStyle.values.length];
                onBackgroundStyleChanged(next);
              },
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Icon(_bgIcon(backgroundStyle),
                    size: 18,
                    color: backgroundStyle != BackgroundStyle.blank
                        ? Colors.blue
                        : Colors.black54),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(width: 1, height: 18, color: Colors.grey.shade300),
          const SizedBox(width: 4),
          // Zoom controls
          _ZoomBtn(icon: Icons.remove, tooltip: 'Zoom out', onTap: onZoomOut),
          InkWell(
            onTap: onZoomReset,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text('$pct%',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87)),
            ),
          ),
          _ZoomBtn(icon: Icons.add, tooltip: 'Zoom in', onTap: onZoomIn),
          const SizedBox(width: 4),
          Container(width: 1, height: 18, color: Colors.grey.shade300),
          const SizedBox(width: 4),
          // Help
          Tooltip(
            message: 'Keyboard shortcuts',
            child: InkWell(
              onTap: () => _showHelp(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade400),
                ),
                alignment: Alignment.center,
                child: const Text('?',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _bgIcon(BackgroundStyle s) => switch (s) {
        BackgroundStyle.blank => Icons.crop_square_rounded,
        BackgroundStyle.dots => Icons.grain_rounded,
        BackgroundStyle.grid => Icons.grid_on_rounded,
      };

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keyboard Shortcuts'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Shortcut('Ctrl + Z', 'Undo'),
            _Shortcut('Ctrl + Y  /  Ctrl + Shift + Z', 'Redo'),
            _Shortcut('Scroll', 'Zoom in / out'),
            _Shortcut('Middle mouse drag', 'Pan canvas'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ZoomBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, size: 16, color: Colors.black87),
          ),
        ),
      );
}

class _Shortcut extends StatelessWidget {
  final String keys;
  final String description;
  const _Shortcut(this.keys, this.description);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child:
                  Text(keys, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            ),
            const SizedBox(width: 8),
            Text(description, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );
}
