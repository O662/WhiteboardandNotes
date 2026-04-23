import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../painters/whiteboard_painter.dart';
import 'whiteboard_screen.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  static const double _cx = 25000.0;
  static const double _cy = 25000.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 36),
                  _buildNewBoardButton(context),
                  const SizedBox(height: 32),
                  _buildTemplatesSection(context),
                  const SizedBox(height: 24),
                  _buildOpenBoardButton(context),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 14,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            'BORD',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 1.5,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'What are you working on?',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Start fresh, pick a template, or continue where you left off.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildNewBoardButton(BuildContext context) {
    return Material(
      color: const Color(0xFF1D4ED8),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openNew(context),
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withAlpha(40),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Board',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Start with a blank infinite canvas',
                    style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplatesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Templates',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _templateCard(
              context,
              icon: Icons.notes_rounded,
              title: 'Note Taking',
              subtitle: 'Lined page ready to fill',
              cardColor: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF2563EB),
              items: _noteTakingItems(),
              background: BackgroundStyle.dots,
            ),
            _templateCard(
              context,
              icon: Icons.lightbulb_outline_rounded,
              title: 'Brainstorming',
              subtitle: 'Central idea with sticky notes',
              cardColor: const Color(0xFFFFFBEB),
              iconColor: const Color(0xFFD97706),
              items: _brainstormingItems(),
              background: BackgroundStyle.dots,
            ),
            _templateCard(
              context,
              icon: Icons.groups_outlined,
              title: 'Meeting Notes',
              subtitle: 'Agenda, notes & action items',
              cardColor: const Color(0xFFF0FDF4),
              iconColor: const Color(0xFF16A34A),
              items: _meetingNotesItems(),
              background: BackgroundStyle.blank,
            ),
            _templateCard(
              context,
              icon: Icons.checklist_rounded,
              title: 'Project Planning',
              subtitle: 'Kanban-style task board',
              cardColor: const Color(0xFFFDF4FF),
              iconColor: const Color(0xFF9333EA),
              items: _projectPlanningItems(),
              background: BackgroundStyle.dots,
            ),
          ],
        ),
      ],
    );
  }

  Widget _templateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color cardColor,
    required Color iconColor,
    required List<WhiteboardItem> items,
    required BackgroundStyle background,
  }) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _openTemplate(context, items: items, background: background),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenBoardButton(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _openExisting(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.folder_open_outlined, color: Color(0xFF374151), size: 20),
              SizedBox(width: 10),
              Text(
                'Open Existing Board',
                style: TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openNew(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WhiteboardScreen()),
    );
  }

  void _openTemplate(
    BuildContext context, {
    required List<WhiteboardItem> items,
    required BackgroundStyle background,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WhiteboardScreen(
          initialItems: items,
          initialBackground: background,
          skipAutosavePrompt: true,
        ),
      ),
    );
  }

  Future<void> _openExisting(BuildContext context) async {
    try {
      String? filePath;
      String content;

      if (Platform.isAndroid || Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        final bordFiles = dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.bord'))
            .toList()
          ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

        if (bordFiles.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No saved boards found')),
            );
          }
          return;
        }

        if (!context.mounted) return;
        final chosen = await showDialog<File>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Open board'),
            children: bordFiles.map((f) {
              final name = f.path.split('/').last.replaceAll('.bord', '');
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, f),
                child: Text(name),
              );
            }).toList(),
          ),
        );
        if (chosen == null) return;
        filePath = chosen.path;
        content = await chosen.readAsString();
      } else {
        final result = await FilePicker.platform.pickFiles(
          dialogTitle: 'Open board',
          type: FileType.custom,
          allowedExtensions: ['bord'],
        );
        if (result == null) return;
        final file = result.files.single;
        if (file.path == null) return;
        filePath = file.path;
        content = await File(file.path!).readAsString();
      }

      final json = jsonDecode(content) as Map<String, dynamic>;
      final items = (json['items'] as List)
          .map((i) => WhiteboardItem.fromJson(i as Map<String, dynamic>))
          .toList();
      final bg = BackgroundStyle.values.firstWhere(
        (s) => s.name == json['background'],
        orElse: () => BackgroundStyle.dots,
      );

      Matrix4? transform;
      if (json.containsKey('transform')) {
        final t = json['transform'] as Map<String, dynamic>;
        final scale = (t['scale'] as num).toDouble();
        transform = Matrix4.identity()
          ..setEntry(0, 0, scale)
          ..setEntry(1, 1, scale)
          ..setEntry(2, 2, 1)
          ..setEntry(0, 3, (t['tx'] as num).toDouble())
          ..setEntry(1, 3, (t['ty'] as num).toDouble());
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WhiteboardScreen(
              initialItems: items,
              initialBackground: bg,
              initialFilePath: filePath,
              initialTransform: transform,
              skipAutosavePrompt: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Open failed: $e')),
        );
      }
    }
  }

  // ── Template item factories ────────────────────────────────────────────────

  static List<WhiteboardItem> _noteTakingItems() {
    const fx = _cx - 297.5;
    const fy = _cy - 421.0;
    return [
      FrameItem(
        position: const Offset(fx, fy),
        frameType: FrameType.noteLined,
      ),
      TextItem(
        position: const Offset(fx + 20, fy - 38),
        text: 'My Notes',
        color: const Color(0xFF111827),
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    ];
  }

  static List<WhiteboardItem> _brainstormingItems() {
    return [
      ShapeItem(
        position: const Offset(_cx - 130, _cy - 45),
        shapeType: ShapeType.ellipse,
        width: 260,
        height: 90,
        strokeColor: const Color(0xFF2563EB),
        strokeWidth: 2.5,
        filled: true,
        fillColor: const Color(0xFFBFDBFE),
      ),
      TextItem(
        position: const Offset(_cx - 52, _cy - 14),
        text: 'Main Idea',
        color: const Color(0xFF1E40AF),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      StickyNoteItem(
        position: const Offset(_cx - 520, _cy - 260),
        text: 'Idea 1',
        color: const Color(0xFFFFF9C4),
      ),
      StickyNoteItem(
        position: const Offset(_cx + 280, _cy - 260),
        text: 'Idea 2',
        color: const Color(0xFFBBDEFB),
      ),
      StickyNoteItem(
        position: const Offset(_cx - 520, _cy + 170),
        text: 'Idea 3',
        color: const Color(0xFFC8E6C9),
      ),
      StickyNoteItem(
        position: const Offset(_cx + 280, _cy + 170),
        text: 'Idea 4',
        color: const Color(0xFFFFCDD2),
      ),
    ];
  }

  static List<WhiteboardItem> _meetingNotesItems() {
    const fx = _cx - 297.5;
    const fy = _cy - 421.0;
    return [
      FrameItem(
        position: const Offset(fx, fy),
        frameType: FrameType.noteLined,
      ),
      TextItem(
        position: const Offset(fx + 20, fy + 16),
        text: 'Meeting Title',
        color: const Color(0xFF111827),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      TextItem(
        position: const Offset(fx + 20, fy + 60),
        text: 'Date:                              Attendees:',
        color: const Color(0xFF4B5563),
        fontSize: 12,
      ),
      TextItem(
        position: const Offset(fx + 20, fy + 130),
        text: 'Agenda',
        color: const Color(0xFF111827),
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      TextItem(
        position: const Offset(fx + 20, fy + 162),
        text: '1. \n2. \n3. ',
        color: const Color(0xFF4B5563),
        fontSize: 12,
        lineHeight: 1.8,
      ),
      TextItem(
        position: const Offset(fx + 20, fy + 310),
        text: 'Notes',
        color: const Color(0xFF111827),
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
      TextItem(
        position: const Offset(fx + 20, fy + 560),
        text: 'Action Items',
        color: const Color(0xFF111827),
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    ];
  }

  static List<WhiteboardItem> _projectPlanningItems() {
    return [
      TextItem(
        position: const Offset(_cx - 140, _cy - 320),
        text: 'Project Name',
        color: const Color(0xFF111827),
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
      ChecklistItem(
        position: const Offset(_cx - 380, _cy - 240),
        title: 'To Do',
        entries: [
          ChecklistEntry(text: 'Task 1', checked: false),
          ChecklistEntry(text: 'Task 2', checked: false),
          ChecklistEntry(text: 'Task 3', checked: false),
        ],
      ),
      ChecklistItem(
        position: const Offset(_cx - 120, _cy - 240),
        title: 'In Progress',
        entries: [
          ChecklistEntry(text: 'Task 4', checked: false),
          ChecklistEntry(text: 'Task 5', checked: false),
        ],
      ),
      ChecklistItem(
        position: const Offset(_cx + 140, _cy - 240),
        title: 'Done',
        entries: [
          ChecklistEntry(text: 'Task 6', checked: true),
        ],
      ),
    ];
  }
}
