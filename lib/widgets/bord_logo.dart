import 'package:flutter/material.dart';

class BordLogo extends StatelessWidget {
  final VoidCallback onNew;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final bool autosaveEnabled;
  final VoidCallback onToggleAutosave;
  final VoidCallback onHome;
  final String? boardName;
  final String? filePath;
  final void Function(String) onRename;
  final VoidCallback onChangeSaveLocation;

  const BordLogo({
    super.key,
    required this.onNew,
    required this.onOpen,
    required this.onSave,
    required this.onClear,
    required this.autosaveEnabled,
    required this.onToggleAutosave,
    required this.onHome,
    required this.onRename,
    required this.onChangeSaveLocation,
    this.boardName,
    this.filePath,
  });

  void _showMenu(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Board menu',
      barrierColor: Colors.black.withAlpha(38),
      transitionDuration: const Duration(milliseconds: 210),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.93, end: 1.0).animate(curved),
            alignment: Alignment.topLeft,
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, _) => Padding(
        padding: EdgeInsets.only(
          top: mediaQuery.padding.top + 58,
          left: 16,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: _BoardMenuPanel(
            boardName: boardName,
            filePath: filePath,
            autosaveEnabled: autosaveEnabled,
            onHome: () { Navigator.pop(ctx); onHome(); },
            onNew: () { Navigator.pop(ctx); onNew(); },
            onOpen: () { Navigator.pop(ctx); onOpen(); },
            onSave: () { Navigator.pop(ctx); onSave(); },
            onClear: () { Navigator.pop(ctx); onClear(); },
            onToggleAutosave: () { Navigator.pop(ctx); onToggleAutosave(); },
            onRename: (name) { Navigator.pop(ctx); onRename(name); },
            onChangeSaveLocation: () { Navigator.pop(ctx); onChangeSaveLocation(); },
          ),
        ),
      ),
    );
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
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.menu_rounded, size: 18, color: Colors.black87),
            SizedBox(width: 6),
            Text(
              'BORD',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.5,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Board menu panel ──────────────────────────────────────────────────────────

class _BoardMenuPanel extends StatefulWidget {
  final String? boardName;
  final String? filePath;
  final bool autosaveEnabled;
  final VoidCallback onHome;
  final VoidCallback onNew;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final VoidCallback onToggleAutosave;
  final void Function(String) onRename;
  final VoidCallback onChangeSaveLocation;

  const _BoardMenuPanel({
    this.boardName,
    this.filePath,
    required this.autosaveEnabled,
    required this.onHome,
    required this.onNew,
    required this.onOpen,
    required this.onSave,
    required this.onClear,
    required this.onToggleAutosave,
    required this.onRename,
    required this.onChangeSaveLocation,
  });

  @override
  State<_BoardMenuPanel> createState() => _BoardMenuPanelState();
}

class _BoardMenuPanelState extends State<_BoardMenuPanel> {
  bool _editingName = false;
  late final TextEditingController _nameController;
  final _nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.boardName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _editingName = true;
      _nameController.text = widget.boardName ?? '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocus.requestFocus();
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });
  }

  void _commitRename() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      widget.onRename(name);
    } else {
      setState(() => _editingName = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = widget.filePath != null;
    final displayPath = hasFile ? _shortenPath(widget.filePath!) : null;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 290,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(32),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Board identity header ─────────────────────────────
              _buildHeader(hasFile, displayPath),

              _divider(),

              // ── File actions ──────────────────────────────────────
              _MenuRow(
                icon: Icons.add_rounded,
                label: 'New Board',
                onTap: widget.onNew,
              ),
              _hairline(),
              _MenuRow(
                icon: Icons.folder_open_outlined,
                label: 'Open Board',
                onTap: widget.onOpen,
              ),
              _hairline(),
              _MenuRow(
                icon: Icons.save_alt_rounded,
                label: 'Save Board',
                onTap: widget.onSave,
              ),

              _divider(),

              // ── Autosave ──────────────────────────────────────────
              _AutosaveRow(
                enabled: widget.autosaveEnabled,
                onToggle: widget.onToggleAutosave,
              ),

              _divider(),

              // ── Danger ────────────────────────────────────────────
              _MenuRow(
                icon: Icons.delete_sweep_outlined,
                label: 'Clear Board',
                onTap: widget.onClear,
                color: const Color(0xFFD93025),
              ),

              _divider(),

              // ── Home ──────────────────────────────────────────────
              _MenuRow(
                icon: Icons.home_outlined,
                label: 'Home',
                onTap: widget.onHome,
                color: const Color(0xFF555566),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool hasFile, String? displayPath) {
    return Container(
      color: const Color(0xFFF7F7F9),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Board name row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // BORD dot indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: hasFile
                      ? const Color(0xFF34C759)
                      : const Color(0xFFFFCC00),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _editingName
                    ? TextField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111122),
                          height: 1.2,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: 'Board name',
                          hintStyle: TextStyle(
                            color: Color(0xFFAAAAAA),
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        onSubmitted: (_) => _commitRename(),
                        textInputAction: TextInputAction.done,
                      )
                    : Text(
                        widget.boardName ?? 'Untitled Board',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111122),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              const SizedBox(width: 6),
              if (_editingName)
                GestureDetector(
                  onTap: _commitRename,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111122),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: _startEditing,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: Colors.black.withAlpha(110),
                    ),
                  ),
                ),
            ],
          ),

          // File path row
          const SizedBox(height: 8),
          GestureDetector(
            onTap: widget.onChangeSaveLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: hasFile
                    ? Colors.black.withAlpha(8)
                    : Colors.blue.withAlpha(14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasFile
                      ? Colors.black.withAlpha(16)
                      : Colors.blue.withAlpha(40),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasFile
                        ? Icons.folder_outlined
                        : Icons.folder_off_outlined,
                    size: 13,
                    color: hasFile
                        ? Colors.black.withAlpha(100)
                        : Colors.blue.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      displayPath ?? 'Tap to choose a save location',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasFile
                            ? Colors.black.withAlpha(110)
                            : Colors.blue.shade600,
                        fontWeight: hasFile
                            ? FontWeight.normal
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: hasFile
                        ? Colors.black.withAlpha(60)
                        : Colors.blue.shade400,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFFEEEEF2),
      );

  Widget _hairline() => const Divider(
        height: 1,
        thickness: 0.5,
        indent: 46,
        color: Color(0xFFEEEEF2),
      );
}

// ── Reusable menu row ─────────────────────────────────────────────────────────

class _MenuRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0xFF111122);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        color: _pressed ? const Color(0xFFF0F0F4) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(widget.icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Autosave toggle row ───────────────────────────────────────────────────────

class _AutosaveRow extends StatefulWidget {
  final bool enabled;
  final VoidCallback onToggle;

  const _AutosaveRow({required this.enabled, required this.onToggle});

  @override
  State<_AutosaveRow> createState() => _AutosaveRowState();
}

class _AutosaveRowState extends State<_AutosaveRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onToggle();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        color: _pressed ? const Color(0xFFF0F0F4) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(
              active ? Icons.sync_rounded : Icons.sync_disabled_rounded,
              size: 18,
              color: active
                  ? const Color(0xFF007AFF)
                  : const Color(0xFF888898),
            ),
            const SizedBox(width: 12),
            Text(
              'Autosave',
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.w500,
                color: active
                    ? const Color(0xFF007AFF)
                    : const Color(0xFF111122),
              ),
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFE5F2FF)
                    : const Color(0xFFF0F0F4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? const Color(0xFF99CCFF)
                      : const Color(0xFFDDDDE8),
                  width: 1,
                ),
              ),
              child: Text(
                active ? 'ON' : 'OFF',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: active
                      ? const Color(0xFF007AFF)
                      : const Color(0xFF888898),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Path display helper ───────────────────────────────────────────────────────

String _shortenPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/').where((p) => p.isNotEmpty).toList();
  if (parts.length <= 2) return normalized.split('/').last;
  return '.../${parts[parts.length - 2]}/${parts.last}';
}
