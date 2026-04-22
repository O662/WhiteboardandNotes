import 'package:flutter/material.dart';

class BordLogo extends StatelessWidget {
  final VoidCallback onNew;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final bool autosaveEnabled;
  final VoidCallback onToggleAutosave;

  const BordLogo({
    super.key,
    required this.onNew,
    required this.onOpen,
    required this.onSave,
    required this.onClear,
    required this.autosaveEnabled,
    required this.onToggleAutosave,
  });

  void _showMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject()! as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
            button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final result = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [
        PopupMenuItem(
          value: 'new',
          child: Row(children: const [
            Icon(Icons.add_rounded, size: 18, color: Colors.black87),
            SizedBox(width: 10),
            Text('New board'),
          ]),
        ),
        PopupMenuItem(
          value: 'open',
          child: Row(children: const [
            Icon(Icons.folder_open_outlined, size: 18, color: Colors.black87),
            SizedBox(width: 10),
            Text('Open board'),
          ]),
        ),
        PopupMenuItem(
          value: 'save',
          child: Row(children: const [
            Icon(Icons.save_outlined, size: 18, color: Colors.black87),
            SizedBox(width: 10),
            Text('Save board'),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'clear',
          child: Row(children: const [
            Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.red),
            SizedBox(width: 10),
            Text('Clear board', style: TextStyle(color: Colors.red)),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'autosave',
          child: Row(children: [
            Icon(
              autosaveEnabled ? Icons.sync_rounded : Icons.sync_disabled_rounded,
              size: 18,
              color: autosaveEnabled ? Colors.blue : Colors.black87,
            ),
            const SizedBox(width: 10),
            Text(
              'Autosave',
              style: TextStyle(
                color: autosaveEnabled ? Colors.blue : Colors.black87,
                fontWeight: autosaveEnabled ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (autosaveEnabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('ON',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700)),
              ),
          ]),
        ),
      ],
    );

    if (result == 'new') onNew();
    if (result == 'open') onOpen();
    if (result == 'save') onSave();
    if (result == 'clear') onClear();
    if (result == 'autosave') onToggleAutosave();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
          children: const [
            Icon(Icons.menu_rounded, size: 18, color: Colors.black87),
            SizedBox(width: 6),
            Text('BORD',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.5,
                    color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}
