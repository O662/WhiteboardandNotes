import 'package:flutter/material.dart';

class PageStrip extends StatelessWidget {
  final List<String> pageNames;
  final int currentIndex;
  final ValueChanged<int> onSwitch;
  final VoidCallback onAdd;
  final ValueChanged<int> onDelete;
  final ValueChanged<int> onRename;

  const PageStrip({
    super.key,
    required this.pageNames,
    required this.currentIndex,
    required this.onSwitch,
    required this.onAdd,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(28),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < pageNames.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 16,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(horizontal: 2),
              ),
            _PageTab(
              name: pageNames[i],
              isActive: i == currentIndex,
              showDelete: pageNames.length > 1,
              onTap: () => onSwitch(i),
              onDelete: () => onDelete(i),
              onRename: () => onRename(i),
            ),
          ],
          Container(
            width: 1,
            height: 16,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          Tooltip(
            message: 'Add page',
            child: InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.add, size: 16, color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageTab extends StatelessWidget {
  final String name;
  final bool isActive;
  final bool showDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _PageTab({
    required this.name,
    required this.isActive,
    required this.showDelete,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onRename,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: isActive
              ? BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive
                      ? Colors.blue.shade700
                      : Colors.black87,
                ),
              ),
              if (showDelete) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child:
                        Icon(Icons.close, size: 12, color: Colors.black38),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
