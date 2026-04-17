import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/stroke.dart';
import '../painters/whiteboard_painter.dart';
import '../widgets/toolbar.dart';
import '../widgets/left_sidebar.dart';
import '../widgets/bottom_bar.dart';

class WhiteboardScreen extends StatefulWidget {
  const WhiteboardScreen({super.key});

  @override
  State<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends State<WhiteboardScreen> {
  final _transformationController = TransformationController();
  final List<WhiteboardItem> _items = [];
  final List<WhiteboardItem> _redoStack = [];
  Stroke? _activeStroke;

  DrawingTool _tool = DrawingTool.pen;
  Color _color = Colors.black;
  double _strokeWidth = 3.0;
  BackgroundStyle _backgroundStyle = BackgroundStyle.dots;
  double _zoomLevel = 1.0;

  String? _currentFilePath;
  bool _autosaveEnabled = false;
  Timer? _autosaveTimer;

  bool _showInsertPanel = false;
  bool _showMathPanel = false;

  bool _isPanning = false;
  int _pointerCount = 0;
  Offset? _downCanvasPos;

  // Select tool state
  int? _selectedIndex;
  Offset? _selectDragCanvas;

  static const double _canvasSize = 50000.0;
  static const Offset _canvasCenter = Offset(_canvasSize / 2, _canvasSize / 2);

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransform);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      _transformationController.value = Matrix4.translationValues(
        -_canvasCenter.dx + size.width / 2,
        -_canvasCenter.dy + size.height / 2,
        0,
      );
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _transformationController.removeListener(_onTransform);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransform() {
    final z = _transformationController.value.getMaxScaleOnAxis();
    if ((z - _zoomLevel).abs() > 0.005) setState(() => _zoomLevel = z);
  }

  Offset _toCanvas(Offset screen) {
    final m = _transformationController.value.clone()..invert();
    return MatrixUtils.transformPoint(m, screen);
  }

  void _changeTool(DrawingTool t) {
    setState(() {
      _tool = t;
      _selectedIndex = null;
      _selectDragCanvas = null;
    });
  }

  void _addItem(WhiteboardItem item) {
    setState(() {
      _items.add(item);
      _redoStack.clear();
    });
    _scheduleAutosave();
  }

  void _undo() {
    if (_items.isNotEmpty) {
      setState(() {
        _redoStack.add(_items.removeLast());
        _selectedIndex = null;
      });
      _scheduleAutosave();
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      setState(() => _items.add(_redoStack.removeLast()));
      _scheduleAutosave();
    }
  }

  void _clear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear whiteboard?'),
        content: const Text('All content will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() {
                _items.clear();
                _redoStack.clear();
                _selectedIndex = null;
              });
              _scheduleAutosave();
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _zoomBy(double factor) {
    final size = MediaQuery.of(context).size;
    final focalX = size.width / 2;
    final focalY = size.height / 2;

    final matrix = _transformationController.value;
    final currentScale = matrix.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.1, 10.0);
    final ratio = newScale / currentScale;

    final tx = matrix.entry(0, 3);
    final ty = matrix.entry(1, 3);
    final newTx = focalX + ratio * (tx - focalX);
    final newTy = focalY + ratio * (ty - focalY);

    final next = Matrix4.translationValues(newTx, newTy, 0);
    next.setEntry(0, 0, newScale);
    next.setEntry(1, 1, newScale);
    _transformationController.value = next;
  }

  void _zoomReset() {
    final size = MediaQuery.of(context).size;
    _transformationController.value = Matrix4.translationValues(
      -_canvasCenter.dx + size.width / 2,
      -_canvasCenter.dy + size.height / 2,
      0,
    );
  }

  // ── Select/move ────────────────────────────────────────────────────────────

  void _handleSelectDown(Offset canvasPos) {
    for (int i = _items.length - 1; i >= 0; i--) {
      if (_items[i].bounds.inflate(8).contains(canvasPos)) {
        setState(() {
          _selectedIndex = i;
          _selectDragCanvas = canvasPos;
        });
        return;
      }
    }
    setState(() {
      _selectedIndex = null;
      _selectDragCanvas = null;
    });
  }

  void _handleSelectMove(Offset canvasPos) {
    if (_selectedIndex == null || _selectDragCanvas == null) return;
    final delta = canvasPos - _selectDragCanvas!;
    setState(() {
      _items[_selectedIndex!] = _items[_selectedIndex!].movedBy(delta);
      _selectDragCanvas = canvasPos;
    });
  }

  void _handleSelectUp() {
    setState(() => _selectDragCanvas = null);
    _scheduleAutosave();
  }

  void _deleteSelected() {
    if (_selectedIndex == null) return;
    setState(() {
      _items.removeAt(_selectedIndex!);
      _selectedIndex = null;
      _redoStack.clear();
    });
    _scheduleAutosave();
  }

  // ── Save / Open / New ─────────────────────────────────────────────────────

  Map<String, dynamic> _boardData() {
    final matrix = _transformationController.value;
    return {
      'version': 1,
      'background': _backgroundStyle.name,
      'items': _items.map((i) => i.toJson()).toList(),
      'transform': {
        'tx': matrix.entry(0, 3),
        'ty': matrix.entry(1, 3),
        'scale': matrix.getMaxScaleOnAxis(),
      },
    };
  }

  Future<void> _saveBoard() async {
    try {
      final data = jsonEncode(_boardData());
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save board',
        fileName: 'board.bord',
        type: FileType.custom,
        allowedExtensions: ['bord'],
      );
      if (path == null) return;

      final String finalPath =
          path.endsWith('.bord') ? path : '$path.bord';
      await File(finalPath).writeAsString(data);
      setState(() => _currentFilePath = finalPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Board saved'),
              duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _saveToCurrentPath() async {
    if (_currentFilePath == null) return;
    try {
      await File(_currentFilePath!).writeAsString(jsonEncode(_boardData()));
    } catch (_) {}
  }

  void _scheduleAutosave() {
    if (!_autosaveEnabled || _currentFilePath == null) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 2), _saveToCurrentPath);
  }

  Future<void> _toggleAutosave() async {
    if (_autosaveEnabled) {
      _autosaveTimer?.cancel();
      setState(() => _autosaveEnabled = false);
    } else {
      if (_currentFilePath == null) {
        await _saveBoard();
        if (_currentFilePath == null) return;
      }
      setState(() => _autosaveEnabled = true);
    }
  }

  Future<void> _openBoard() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Open board',
        type: FileType.custom,
        allowedExtensions: ['bord'],
      );
      if (result == null || result.files.single.path == null) return;

      final content =
          await File(result.files.single.path!).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      final items = (json['items'] as List)
          .map((i) => WhiteboardItem.fromJson(i as Map<String, dynamic>))
          .toList();

      final bg = BackgroundStyle.values.firstWhere(
        (s) => s.name == json['background'],
        orElse: () => BackgroundStyle.dots,
      );

      final t = json['transform'] as Map<String, dynamic>;
      final scale = (t['scale'] as num).toDouble();
      final m = Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setEntry(2, 2, 1)
        ..setEntry(0, 3, (t['tx'] as num).toDouble())
        ..setEntry(1, 3, (t['ty'] as num).toDouble());

      setState(() {
        _currentFilePath = result.files.single.path!;
        _items
          ..clear()
          ..addAll(items);
        _backgroundStyle = bg;
        _selectedIndex = null;
        _redoStack.clear();
      });
      _transformationController.value = m;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Open failed: $e')),
        );
      }
    }
  }

  void _newBoard() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New board'),
        content:
            const Text('Start a new board? Unsaved changes will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              _autosaveTimer?.cancel();
              setState(() {
                _items.clear();
                _redoStack.clear();
                _selectedIndex = null;
                _currentFilePath = null;
                _autosaveEnabled = false;
              });
              _zoomReset();
              Navigator.pop(ctx);
            },
            child: const Text('New board'),
          ),
        ],
      ),
    );
  }

  // ── Viewport helper ───────────────────────────────────────────────────────

  Offset get _viewportCenter {
    final size = MediaQuery.of(context).size;
    final m = _transformationController.value.clone()..invert();
    return MatrixUtils.transformPoint(m, Offset(size.width / 2, size.height / 2));
  }

  // ── Insert ─────────────────────────────────────────────────────────────────

  void _showInsertMenu() {
    setState(() => _showInsertPanel = !_showInsertPanel);
  }

  void _closeInsertPanel() {
    setState(() => _showInsertPanel = false);
  }

  void _toggleMathPanel() {
    setState(() {
      _showMathPanel = !_showMathPanel;
      if (_showMathPanel) _showInsertPanel = false;
    });
  }

  void _closeMathPanel() => setState(() => _showMathPanel = false);

  void _insertMathGraph(MathGraphType type) {
    final center = _viewportCenter;
    final temp = MathGraphItem(graphType: type, position: Offset.zero);
    _addItem(MathGraphItem(
      graphType: type,
      position: center - Offset(temp.width / 2, temp.height / 2),
    ));
  }

  void _placeMathGraph(MathGraphType type, Offset screenPoint) {
    final canvasCenter = _toCanvas(screenPoint);
    final temp = MathGraphItem(graphType: type, position: Offset.zero);
    _addItem(MathGraphItem(
      graphType: type,
      position: canvasCenter - Offset(temp.width / 2, temp.height / 2),
    ));
  }

  Future<void> _insertImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final center = _viewportCenter;
    _addItem(ImageItem(
      position: center - const Offset(200, 150),
      path: result.files.single.path!,
    ));
  }

  Future<void> _insertTable() async {
    int rows = 3, cols = 3;
    bool confirmed = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Insert Table'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const SizedBox(width: 40, child: Text('Rows')),
                const SizedBox(width: 16),
                _NumberStepper(
                    value: rows,
                    min: 1,
                    max: 20,
                    onChanged: (v) => set(() => rows = v)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                const SizedBox(width: 40, child: Text('Cols')),
                const SizedBox(width: 16),
                _NumberStepper(
                    value: cols,
                    min: 1,
                    max: 10,
                    onChanged: (v) => set(() => cols = v)),
              ]),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                confirmed = true;
                Navigator.pop(ctx);
              },
              child: const Text('Insert'),
            ),
          ],
        ),
      ),
    );

    if (!confirmed) return;
    final center = _viewportCenter;
    final w = (cols * 100.0).clamp(200.0, 800.0);
    final h = rows * 36.0 + 4.0;
    _addItem(TableItem.empty(
      position: center - Offset(w / 2, h / 2),
      rows: rows,
      cols: cols,
    ));
  }

  Future<void> _insertAttachment() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    final center = _viewportCenter;
    _addItem(AttachmentItem(
      position: center - const Offset(
          AttachmentItem.cardWidth / 2, AttachmentItem.cardHeight / 2),
      path: result.files.single.path!,
      filename: result.files.single.name,
    ));
  }

  Future<void> _insertLink() async {
    String url = '', label = '';
    bool confirmed = false;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insert Link'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://...',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => url = v,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => label = v,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (url.isNotEmpty) {
                confirmed = true;
                Navigator.pop(ctx);
              }
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );

    if (!confirmed || url.isEmpty) return;
    final center = _viewportCenter;
    _addItem(LinkItem(
      position: center -
          const Offset(LinkItem.cardWidth / 2, LinkItem.cardHeight / 2),
      url: url,
      label: label.isEmpty ? url : label,
    ));
  }

  Future<void> _insertVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.single.path == null) return;
    final center = _viewportCenter;
    _addItem(VideoItem(
      position: center - const Offset(200, 130),
      path: result.files.single.path!,
      filename: result.files.single.name,
    ));
  }

  Future<void> _insertPrintout() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'pptx', 'ppt', 'docx', 'doc'],
    );
    if (result == null || result.files.single.path == null) return;
    final center = _viewportCenter;
    _addItem(PrintoutItem(
      position: center - const Offset(210, 297),
      path: result.files.single.path!,
      filename: result.files.single.name,
    ));
  }

  Future<void> _editTable(int index) async {
    final table = _items[index] as TableItem;
    final cells = List.generate(
        table.rows, (r) => List<String>.from(table.cells[r]));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Edit Table'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int r = 0; r < table.rows; r++)
                  Row(
                    children: [
                      for (int c = 0; c < table.cols; c++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: TextField(
                              controller:
                                  TextEditingController(text: cells[r][c]),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                border: const OutlineInputBorder(),
                                fillColor: r == 0
                                    ? Colors.grey.shade100
                                    : null,
                                filled: r == 0,
                              ),
                              style: TextStyle(
                                fontWeight: r == 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                              onChanged: (v) => cells[r][c] = v,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                setState(() => _items[index] = table.withCells(cells));
                _scheduleAutosave();
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open: $url')),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openFile(String path) async {
    final uri = Uri.file(path);
    if (!await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open: $path')),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ── Rich item overlay ──────────────────────────────────────────────────────

  Widget _buildRichOverlay() {
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    return Stack(
      children: [
        for (final (index, item) in _items.indexed)
          if (item is ImageItem ||
              item is TableItem ||
              item is AttachmentItem ||
              item is LinkItem ||
              item is VideoItem ||
              item is PrintoutItem ||
              item is MathGraphItem)
            _buildRichOverlayItem(item, index, matrix, scale),
      ],
    );
  }

  Widget _buildRichOverlayItem(
      WhiteboardItem item, int index, Matrix4 matrix, double scale) {
    final tl = MatrixUtils.transformPoint(matrix, item.bounds.topLeft);
    final screenW = item.bounds.width * scale;
    final screenH = item.bounds.height * scale;
    final isSelected = _selectedIndex == index;

    final Widget content = switch (item) {
      final ImageItem i => _ImageCard(item: i),
      final TableItem i => _TableCard(item: i, scale: scale),
      final AttachmentItem i => _AttachmentCard(item: i),
      final LinkItem i => _LinkCard(item: i),
      final VideoItem i => _VideoCard(item: i),
      final PrintoutItem i => _PrintoutCard(item: i),
      final MathGraphItem i => _MathGraphCard(item: i),
      _ => const SizedBox.shrink(),
    };

    return Positioned(
      left: tl.dx,
      top: tl.dy,
      width: screenW,
      height: screenH,
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                border:
                    Border.all(color: const Color(0xFF2979FF), width: 2),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSelected ? 3 : 0),
          child: content,
        ),
      ),
    );
  }

  // ── Selection hint ─────────────────────────────────────────────────────────

  Widget _buildSelectionHint() {
    final item = _items[_selectedIndex!];
    final actions = <Widget>[];

    const sep = Text(' · ',
        style: TextStyle(color: Colors.white54, fontSize: 13));
    const actionStyle = TextStyle(
        color: Color(0xFF90CAF9),
        fontSize: 13,
        decoration: TextDecoration.underline,
        decorationColor: Color(0xFF90CAF9));

    if (item is LinkItem) {
      final link = item;
      actions.addAll([
        sep,
        GestureDetector(
          onTap: () => _openLink(link.url),
          child: const Text('Open link', style: actionStyle),
        ),
      ]);
    } else if (item is AttachmentItem) {
      final att = item;
      actions.addAll([
        sep,
        GestureDetector(
          onTap: () => _openFile(att.path),
          child: const Text('Open file', style: actionStyle),
        ),
      ]);
    } else if (item is VideoItem) {
      final vid = item;
      actions.addAll([
        sep,
        GestureDetector(
          onTap: () => _openFile(vid.path),
          child: const Text('Play video', style: actionStyle),
        ),
      ]);
    } else if (item is TableItem) {
      final idx = _selectedIndex!;
      actions.addAll([
        sep,
        GestureDetector(
          onTap: () => _editTable(idx),
          child: const Text('Edit table', style: actionStyle),
        ),
      ]);
    } else if (item is PrintoutItem) {
      final pr = item;
      actions.addAll([
        sep,
        GestureDetector(
          onTap: () => _openFile(pr.path),
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
          ...actions,
          const Text(' · ',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const Text('Delete to remove',
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  // ── Pointer helpers ────────────────────────────────────────────────────────

  bool get _isDrawingTool =>
      _tool == DrawingTool.pen ||
      _tool == DrawingTool.highlighter ||
      _tool == DrawingTool.eraser ||
      _tool == DrawingTool.shape ||
      _tool == DrawingTool.frame;

  bool get _isTapTool =>
      _tool == DrawingTool.text || _tool == DrawingTool.stickyNote;

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    _downCanvasPos = _toCanvas(event.position);

    if (_pointerCount > 1 || _tool == DrawingTool.pan) {
      setState(() {
        _activeStroke = null;
        _isPanning = true;
      });
      return;
    }
    if (event.buttons == kMiddleMouseButton) return;

    if (_tool == DrawingTool.select) {
      _handleSelectDown(_downCanvasPos!);
      return;
    }

    if (_isTapTool || _tool == DrawingTool.math) return;

    if (_isDrawingTool) {
      setState(() {
        _isPanning = false;
        _activeStroke = Stroke(
          points: [_downCanvasPos!],
          color: _color,
          strokeWidth:
              _tool == DrawingTool.eraser ? _strokeWidth * 3 : _strokeWidth,
          tool: _tool,
        );
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isPanning) return;

    if (_tool == DrawingTool.select) {
      _handleSelectMove(_toCanvas(event.position));
      return;
    }

    if (_activeStroke == null) return;
    final pos = _toCanvas(event.position);
    setState(() {
      if (_tool == DrawingTool.shape || _tool == DrawingTool.frame) {
        _activeStroke = _activeStroke!
            .copyWith(points: [_activeStroke!.points.first, pos]);
      } else {
        _activeStroke = _activeStroke!
            .copyWith(points: [..._activeStroke!.points, pos]);
      }
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointerCount = (_pointerCount - 1).clamp(0, 10);
    if (_pointerCount == 0) _isPanning = false;

    if (_tool == DrawingTool.select) {
      _handleSelectUp();
      _downCanvasPos = null;
      return;
    }

    final upPos = _toCanvas(event.position);
    final isSmallMovement =
        _downCanvasPos != null && (_downCanvasPos! - upPos).distance < 8;

    if (_isTapTool && isSmallMovement && _downCanvasPos != null) {
      _handleTap(_downCanvasPos!);
      _downCanvasPos = null;
      return;
    }

    if (_activeStroke != null) {
      final s = _activeStroke!;
      setState(() => _activeStroke = null);
      if (s.points.isNotEmpty) _addItem(StrokeItem(s));
    }
    _downCanvasPos = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerCount = (_pointerCount - 1).clamp(0, 10);
    setState(() {
      _activeStroke = null;
      _selectDragCanvas = null;
      if (_pointerCount == 0) _isPanning = false;
    });
    _downCanvasPos = null;
  }

  Future<void> _handleTap(Offset canvasPos) async {
    if (_tool == DrawingTool.text) {
      await _showTextDialog(canvasPos);
    } else if (_tool == DrawingTool.stickyNote) {
      await _showStickyNoteDialog(canvasPos);
    }
  }

  Future<void> _showTextDialog(Offset pos) async {
    String text = '';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Text'),
        content: TextField(
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(
              hintText: 'Type something...', border: OutlineInputBorder()),
          onChanged: (v) => text = v,
          onSubmitted: (_) => Navigator.pop(ctx),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (text.isNotEmpty) {
      _addItem(TextItem(position: pos, text: text, color: _color));
    }
  }

  Future<void> _showStickyNoteDialog(Offset pos) async {
    String text = '';
    Color noteColor = const Color(0xFFFFF9C4);
    final noteColors = [
      const Color(0xFFFFF9C4),
      const Color(0xFFB3E5FC),
      const Color(0xFFC8E6C9),
      const Color(0xFFFFCDD2),
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Sticky Note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                autofocus: true,
                maxLines: 4,
                decoration: const InputDecoration(
                    hintText: 'Note text...', border: OutlineInputBorder()),
                onChanged: (v) => text = v,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Color:', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  for (final c in noteColors)
                    GestureDetector(
                      onTap: () => setDialogState(() => noteColor = c),
                      child: Container(
                        width: 26,
                        height: 26,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: noteColor == c
                                ? Colors.blue
                                : Colors.grey.shade400,
                            width: noteColor == c ? 2.5 : 1,
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
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (text.isNotEmpty) {
      _addItem(StickyNoteItem(position: pos, text: text, color: noteColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          final ctrl = HardwareKeyboard.instance.isControlPressed;
          final shift = HardwareKeyboard.instance.isShiftPressed;
          if (ctrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
            shift ? _redo() : _undo();
          } else if (ctrl && event.logicalKey == LogicalKeyboardKey.keyY) {
            _redo();
          } else if (ctrl && event.logicalKey == LogicalKeyboardKey.keyS) {
            _saveBoard();
          } else if (event.logicalKey == LogicalKeyboardKey.delete ||
              event.logicalKey == LogicalKeyboardKey.backspace) {
            _deleteSelected();
          }
        },
        child: Stack(
          children: [
            // ── Canvas ─────────────────────────────────────────────────────
            Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: InteractiveViewer(
                transformationController: _transformationController,
                panEnabled: _tool == DrawingTool.pan,
                scaleEnabled: true,
                minScale: 0.1,
                maxScale: 10.0,
                panAxis: PanAxis.free,
                interactionEndFrictionCoefficient: double.infinity,
                child: SizedBox(
                  width: _canvasSize,
                  height: _canvasSize,
                  child: CustomPaint(
                    painter: WhiteboardPainter(
                      items: _items,
                      activeStroke: _activeStroke,
                      backgroundStyle: _backgroundStyle,
                      transformationController: _transformationController,
                      screenSize: MediaQuery.of(context).size,
                      selectedIndex: _selectedIndex,
                    ),
                  ),
                ),
              ),
            ),

            // ── Rich item overlay ───────────────────────────────────────────
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _transformationController,
                builder: (context, _) => _buildRichOverlay(),
              ),
            ),

            // ── BORD logo — top left ────────────────────────────────────────
            Positioned(
              top: pad.top + 12,
              left: 16,
              child: _BordLogo(
              onNew: _newBoard,
              onOpen: _openBoard,
              onSave: _saveBoard,
              autosaveEnabled: _autosaveEnabled,
              onToggleAutosave: _toggleAutosave,
            ),
            ),

            // ── Main toolbar — top center ───────────────────────────────────
            Positioned(
              top: pad.top + 12,
              left: 0,
              right: 0,
              child: Center(
                child: WhiteboardToolbar(
                  selectedTool: _tool,
                  selectedColor: _color,
                  strokeWidth: _strokeWidth,
                  onToolChanged: _changeTool,
                  onColorChanged: (c) => setState(() => _color = c),
                  onStrokeWidthChanged: (w) =>
                      setState(() => _strokeWidth = w),
                ),
              ),
            ),

            // ── Share — top right ───────────────────────────────────────────
            Positioned(
              top: pad.top + 12,
              right: 16,
              child: _ShareButton(),
            ),

            // ── Left sidebar — vertically centered ─────────────────────────
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: WhiteboardLeftSidebar(
                  selectedTool: _tool,
                  onToolChanged: _changeTool,
                  onUndo: _undo,
                  onRedo: _redo,
                  onClear: _clear,
                  onInsert: _showInsertMenu,
                  onMath: _toggleMathPanel,
                  mathPanelOpen: _showMathPanel,
                ),
              ),
            ),

            // ── Bottom bar — bottom right ───────────────────────────────────
            Positioned(
              bottom: pad.bottom + 16,
              right: 16,
              child: WhiteboardBottomBar(
                zoomLevel: _zoomLevel,
                backgroundStyle: _backgroundStyle,
                onZoomIn: () => _zoomBy(1.25),
                onZoomOut: () => _zoomBy(0.8),
                onZoomReset: _zoomReset,
                onBackgroundStyleChanged: (s) {
                  setState(() => _backgroundStyle = s);
                  _scheduleAutosave();
                },
              ),
            ),

            // ── Select hint ─────────────────────────────────────────────────
            if (_tool == DrawingTool.select && _selectedIndex != null)
              Positioned(
                bottom: pad.bottom + 16,
                left: 0,
                right: 0,
                child: Center(child: _buildSelectionHint()),
              ),

            // ── Math graph drop target ───────────────────────────────────────
            Positioned.fill(
              child: DragTarget<MathGraphType>(
                onAcceptWithDetails: (details) {
                  _placeMathGraph(details.data, details.offset);
                  _closeMathPanel();
                },
                builder: (ctx, candidateData, _) => IgnorePointer(
                  ignoring: candidateData.isEmpty,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    color: candidateData.isNotEmpty
                        ? Colors.blue.withAlpha(12)
                        : Colors.transparent,
                  ),
                ),
              ),
            ),

            // ── Math panel barrier + flyout ──────────────────────────────────
            if (_showMathPanel) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeMathPanel,
                  behavior: HitTestBehavior.translucent,
                ),
              ),
              Positioned(
                left: 72,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _MathPanel(
                    onInsert: (type) {
                      _closeMathPanel();
                      _insertMathGraph(type);
                    },
                  ),
                ),
              ),
            ],

            // ── Insert panel barrier + flyout ────────────────────────────────
            if (_showInsertPanel) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeInsertPanel,
                  behavior: HitTestBehavior.translucent,
                ),
              ),
              Positioned(
                left: 72,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _InsertPanel(
                    onImage: () { _closeInsertPanel(); _insertImage(); },
                    onTable: () { _closeInsertPanel(); _insertTable(); },
                    onAttachment: () { _closeInsertPanel(); _insertAttachment(); },
                    onLink: () { _closeInsertPanel(); _insertLink(); },
                    onVideo: () { _closeInsertPanel(); _insertVideo(); },
                    onPrintout: () { _closeInsertPanel(); _insertPrintout(); },
                    onGenerate: () {
                      _closeInsertPanel();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('AI generation coming soon!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BordLogo extends StatelessWidget {
  final VoidCallback onNew;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final bool autosaveEnabled;
  final VoidCallback onToggleAutosave;

  const _BordLogo({
    required this.onNew,
    required this.onOpen,
    required this.onSave,
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

class _ShareButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.blue.withAlpha(80),
              blurRadius: 12,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.ios_share_rounded, size: 16, color: Colors.white),
          SizedBox(width: 6),
          Text('Share',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

// ── Insert panel (flyout) ──────────────────────────────────────────────────

class _InsertPanel extends StatelessWidget {
  final VoidCallback onImage;
  final VoidCallback onTable;
  final VoidCallback onAttachment;
  final VoidCallback onLink;
  final VoidCallback onVideo;
  final VoidCallback onPrintout;
  final VoidCallback onGenerate;

  const _InsertPanel({
    required this.onImage,
    required this.onTable,
    required this.onAttachment,
    required this.onLink,
    required this.onVideo,
    required this.onPrintout,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      (Icons.image_outlined, 'Picture', const Color(0xFF43A047), onImage),
      (Icons.table_chart_outlined, 'Table', const Color(0xFF1E88E5), onTable),
      (Icons.attach_file_rounded, 'File', const Color(0xFFFB8C00), onAttachment),
      (Icons.link_rounded, 'Link', const Color(0xFF5E35B1), onLink),
      (Icons.play_circle_outline_rounded, 'Video', const Color(0xFFE53935), onVideo),
      (Icons.description_outlined, 'Doc', const Color(0xFFEF6C00), onPrintout),
    ];

    return Container(
      width: 196,
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
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
            children: [
              for (final (icon, label, color, onTap) in options)
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                          color.withAlpha(38), Colors.white),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 26, color: color),
                        const SizedBox(height: 5),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onGenerate,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 15, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Generate',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Number stepper ─────────────────────────────────────────────────────────

class _NumberStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_rounded, size: 18),
          onPressed: value > min ? () => onChanged(value - 1) : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        SizedBox(
          width: 32,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        IconButton(
          icon: const Icon(Icons.add_rounded, size: 18),
          onPressed: value < max ? () => onChanged(value + 1) : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

// ── Rich item cards ────────────────────────────────────────────────────────

class _ImageCard extends StatelessWidget {
  final ImageItem item;
  const _ImageCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final file = File(item.path);
    if (!file.existsSync()) {
      return Container(
        color: Colors.grey.shade100,
        child: Center(
            child: Icon(Icons.broken_image_outlined,
                color: Colors.grey.shade400, size: 40)),
      );
    }
    return Image.file(file, fit: BoxFit.contain, gaplessPlayback: true);
  }
}

class _TableCard extends StatelessWidget {
  final TableItem item;
  final double scale;
  const _TableCard({required this.item, required this.scale});

  @override
  Widget build(BuildContext context) {
    final fontSize = (12.0 / scale).clamp(10.0, 16.0);
    return Container(
      color: Colors.white,
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade400, width: 0.5),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          for (int r = 0; r < item.rows; r++)
            TableRow(
              decoration: BoxDecoration(
                  color: r == 0 ? Colors.grey.shade100 : Colors.white),
              children: [
                for (int c = 0; c < item.cols; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    child: Text(
                      item.cells[r][c].isEmpty && r == 0
                          ? 'Col ${c + 1}'
                          : item.cells[r][c],
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight:
                            r == 0 ? FontWeight.w600 : FontWeight.normal,
                        color: item.cells[r][c].isEmpty && r == 0
                            ? Colors.grey.shade400
                            : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  final AttachmentItem item;
  const _AttachmentCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final ext = item.filename.contains('.')
        ? item.filename.split('.').last.toUpperCase()
        : 'FILE';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.shade200),
            ),
            alignment: Alignment.center,
            child: Text(ext,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.filename,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Select → Open file',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Icon(Icons.open_in_new_rounded,
              size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final LinkItem item;
  const _LinkCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: Colors.blue.shade50, shape: BoxShape.circle),
            child: Icon(Icons.link_rounded,
                color: Colors.blue.shade600, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.black87),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(item.url,
                    style:
                        TextStyle(fontSize: 11, color: Colors.blue.shade400),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.open_in_new_rounded,
              size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final VideoItem item;
  const _VideoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_rounded,
              size: 56, color: Colors.white70),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(item.filename,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 4),
          Text('Select → Play video',
              style:
                  TextStyle(color: Colors.white.withAlpha(100), fontSize: 11)),
        ],
      ),
    );
  }
}

class _PrintoutCard extends StatelessWidget {
  final PrintoutItem item;
  const _PrintoutCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final ext = item.extension;
    final isPdf = ext == 'pdf';
    final color = isPdf ? Colors.red.shade600 : Colors.blue.shade600;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8)),
            ),
            child: Row(children: [
              Icon(
                  isPdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.description_outlined,
                  color: color,
                  size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.filename,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: color),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.description_outlined,
                      size: 64,
                      color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(ext.toUpperCase(),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade400)),
                  const SizedBox(height: 4),
                  Text('Select → Open file',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade400)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Math panel ─────────────────────────────────────────────────────────────

class _MathPanel extends StatelessWidget {
  final void Function(MathGraphType) onInsert;
  const _MathPanel({required this.onInsert});

  static const _items = [
    (MathGraphType.xyGraph, 'XY Graph', Icons.grid_on_rounded, Color(0xFF1565C0)),
    (MathGraphType.xyzGraph, '3D Graph', Icons.view_in_ar_rounded, Color(0xFF6A1B9A)),
    (MathGraphType.numberLine, 'Number Line', Icons.horizontal_rule_rounded, Color(0xFF00838F)),
    (MathGraphType.unitCircle, 'Unit Circle', Icons.radio_button_unchecked_rounded, Color(0xFF2E7D32)),
    (MathGraphType.polarGraph, 'Polar', Icons.blur_circular_rounded, Color(0xFF4527A0)),
    (MathGraphType.vennDiagram, 'Venn', Icons.workspaces_outlined, Color(0xFFBF360C)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 196,
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
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
            children: [
              for (final (type, label, icon, color) in _items)
                Draggable<MathGraphType>(
                  data: type,
                  feedback: Material(
                    color: Colors.transparent,
                    child: _MathTile(label: label, icon: icon, color: color, size: 82),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _MathTile(label: label, icon: icon, color: color),
                  ),
                  child: GestureDetector(
                    onTap: () => onInsert(type),
                    child: _MathTile(label: label, icon: icon, color: color),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF6A1B9A)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calculate_outlined, size: 15, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Formula',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MathTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double size;
  const _MathTile({
    required this.label,
    required this.icon,
    required this.color,
    this.size = 82,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withAlpha(38), Colors.white),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Math graph canvas card ─────────────────────────────────────────────────

class _MathGraphCard extends StatelessWidget {
  final MathGraphItem item;
  const _MathGraphCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: CustomPaint(painter: _painterFor(item.graphType)),
      ),
    );
  }

  static CustomPainter _painterFor(MathGraphType t) => switch (t) {
        MathGraphType.xyGraph => const _XYGraphPainter(),
        MathGraphType.xyzGraph => const _XYZGraphPainter(),
        MathGraphType.numberLine => const _NumberLinePainter(),
        MathGraphType.unitCircle => const _UnitCirclePainter(),
        MathGraphType.polarGraph => const _PolarGraphPainter(),
        MathGraphType.vennDiagram => const _VennDiagramPainter(),
      };
}

// ── Graph painters ─────────────────────────────────────────────────────────

class _XYGraphPainter extends CustomPainter {
  const _XYGraphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final unit = size.width / 10;
    final fs = (size.width * 0.032).clamp(8.0, 14.0);

    final gridP = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 0.5;
    for (int i = -5; i <= 5; i++) {
      canvas.drawLine(Offset(cx + i * unit, 0), Offset(cx + i * unit, size.height), gridP);
      canvas.drawLine(Offset(0, cy + i * unit), Offset(size.width, cy + i * unit), gridP);
    }

    final axP = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = (size.width * 0.004).clamp(1.0, 2.0)
      ..style = PaintingStyle.stroke;
    final m = unit * 0.5;
    canvas.drawLine(Offset(m, cy), Offset(size.width - m, cy), axP);
    canvas.drawLine(Offset(cx, m), Offset(cx, size.height - m), axP);

    final arrP = Paint()..color = const Color(0xFF1565C0)..style = PaintingStyle.fill;
    final a = unit * 0.22;
    _arrow(canvas, arrP, Offset(size.width - m, cy), Offset(1, 0), a);
    _arrow(canvas, arrP, Offset(m, cy), Offset(-1, 0), a);
    _arrow(canvas, arrP, Offset(cx, m), Offset(0, -1), a);
    _arrow(canvas, arrP, Offset(cx, size.height - m), Offset(0, 1), a);

    final tickP = Paint()
      ..color = const Color(0xFF555555)
      ..strokeWidth = (size.width * 0.003).clamp(0.5, 1.5);
    final t = unit * 0.12;
    for (int i = -4; i <= 4; i++) {
      if (i == 0) continue;
      canvas.drawLine(Offset(cx + i * unit, cy - t), Offset(cx + i * unit, cy + t), tickP);
      canvas.drawLine(Offset(cx - t, cy - i * unit), Offset(cx + t, cy - i * unit), tickP);
      if (i % 2 == 0) {
        _label(canvas, '$i', Offset(cx + i * unit, cy + unit * 0.26), fs, const Color(0xFF555555));
        _label(canvas, '$i', Offset(cx - unit * 0.3, cy - i * unit), fs, const Color(0xFF555555));
      }
    }
    _label(canvas, 'x', Offset(size.width - m + unit * 0.25, cy - unit * 0.3), fs * 1.1, const Color(0xFF1565C0), bold: true);
    _label(canvas, 'y', Offset(cx + unit * 0.22, m - unit * 0.2), fs * 1.1, const Color(0xFF1565C0), bold: true);
  }

  void _arrow(Canvas c, Paint p, Offset tip, Offset dir, double s) {
    final perp = Offset(-dir.dy, dir.dx);
    c.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((tip - dir * s + perp * s * 0.5).dx, (tip - dir * s + perp * s * 0.5).dy)
        ..lineTo((tip - dir * s - perp * s * 0.5).dx, (tip - dir * s - perp * s * 0.5).dy)
        ..close(),
      p,
    );
  }

  void _label(Canvas c, String text, Offset center, double fs, Color color, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fs, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_XYGraphPainter o) => false;
}

class _XYZGraphPainter extends CustomPainter {
  const _XYZGraphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.62);
    final axLen = size.width * 0.38;
    final unit = axLen / 4;
    final fs = (size.width * 0.033).clamp(8.0, 14.0);

    const xDir = Offset(0.866, 0.5);
    const yDir = Offset(-0.866, 0.5);
    const zDir = Offset(0.0, -1.0);

    final gridP = Paint()
      ..color = const Color(0xFFDDDDDD)
      ..strokeWidth = (size.width * 0.003).clamp(0.5, 1.0);
    for (int i = 1; i <= 4; i++) {
      canvas.drawLine(origin + xDir * (i * unit), origin + xDir * (i * unit) + yDir * axLen, gridP);
      canvas.drawLine(origin + yDir * (i * unit), origin + yDir * (i * unit) + xDir * axLen, gridP);
    }

    final aw = (size.width * 0.005).clamp(1.0, 2.5);
    _axis(canvas, origin, origin + xDir * axLen, const Color(0xFFD32F2F), aw);
    _axis(canvas, origin, origin + yDir * axLen, const Color(0xFF388E3C), aw);
    _axis(canvas, origin, origin + zDir * axLen, const Color(0xFF1565C0), aw);

    _label(canvas, 'X', origin + xDir * (axLen + unit * 0.35), fs * 1.1, const Color(0xFFD32F2F));
    _label(canvas, 'Y', origin + yDir * (axLen + unit * 0.35), fs * 1.1, const Color(0xFF388E3C));
    _label(canvas, 'Z', origin + zDir * (axLen + unit * 0.35), fs * 1.1, const Color(0xFF1565C0));

    canvas.drawCircle(origin, size.width * 0.012, Paint()..color = const Color(0xFF333333));
  }

  void _axis(Canvas c, Offset from, Offset to, Color color, double w) {
    c.drawLine(from, to, Paint()..color = color..strokeWidth = w..style = PaintingStyle.stroke);
    final d = (to - from) / (to - from).distance;
    final perp = Offset(-d.dy, d.dx);
    final s = w * 3.0;
    c.drawPath(
      Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo((to - d * s + perp * s * 0.5).dx, (to - d * s + perp * s * 0.5).dy)
        ..lineTo((to - d * s - perp * s * 0.5).dx, (to - d * s - perp * s * 0.5).dy)
        ..close(),
      Paint()..color = color..style = PaintingStyle.fill,
    );
  }

  void _label(Canvas c, String text, Offset center, double fs, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fs, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_XYZGraphPainter o) => false;
}

class _NumberLinePainter extends CustomPainter {
  const _NumberLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final margin = size.width * 0.07;
    final x0 = margin;
    final x1 = size.width - margin;
    final unit = (x1 - x0) / 10;
    final ox = x0 + 5 * unit;
    final fs = (size.height * 0.22).clamp(8.0, 14.0);
    final tickH = size.height * 0.18;
    final lw = (size.height * 0.04).clamp(1.0, 2.5);

    canvas.drawLine(Offset(x0, cy), Offset(x1, cy),
        Paint()..color = const Color(0xFF1565C0)..strokeWidth = lw..style = PaintingStyle.stroke);

    final ap = Paint()..color = const Color(0xFF1565C0)..style = PaintingStyle.fill;
    final a = size.height * 0.14;
    canvas.drawPath(Path()..moveTo(x1, cy)..lineTo(x1 - a, cy - a * 0.5)..lineTo(x1 - a, cy + a * 0.5)..close(), ap);
    canvas.drawPath(Path()..moveTo(x0, cy)..lineTo(x0 + a, cy - a * 0.5)..lineTo(x0 + a, cy + a * 0.5)..close(), ap);

    final tickP = Paint()..color = const Color(0xFF333333)..strokeWidth = (size.height * 0.025).clamp(0.5, 1.5);
    for (int i = -5; i <= 5; i++) {
      final x = ox + i * unit;
      final h = i == 0 ? tickH * 1.5 : tickH;
      canvas.drawLine(Offset(x, cy - h), Offset(x, cy + h), tickP);
      final tp = TextPainter(
        text: TextSpan(text: '$i', style: TextStyle(color: i == 0 ? const Color(0xFF1565C0) : const Color(0xFF333333), fontSize: fs, fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, cy + tickH + size.height * 0.05));
    }
  }

  @override
  bool shouldRepaint(_NumberLinePainter o) => false;
}

class _UnitCirclePainter extends CustomPainter {
  const _UnitCirclePainter();

  static const _keyDegs = [0, 30, 45, 60, 90, 120, 135, 150, 180, 210, 225, 240, 270, 300, 315, 330];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.37;
    final fs = (size.width * 0.029).clamp(7.0, 12.0);

    canvas.drawCircle(Offset(cx, cy), r * 0.5,
        Paint()..color = const Color(0xFFEEEEEE)..strokeWidth = 0.5..style = PaintingStyle.stroke);

    final axP = Paint()..color = const Color(0xFF888888)..strokeWidth = (size.width * 0.003).clamp(0.5, 1.5)..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - r * 1.25, cy), Offset(cx + r * 1.25, cy), axP);
    canvas.drawLine(Offset(cx, cy - r * 1.25), Offset(cx, cy + r * 1.25), axP);

    final spokeP = Paint()..color = const Color(0xFFDDDDDD)..strokeWidth = 0.5;
    for (final deg in _keyDegs) {
      final rad = deg * math.pi / 180;
      canvas.drawLine(Offset(cx, cy), Offset(cx + r * math.cos(rad), cy - r * math.sin(rad)), spokeP);
    }

    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = const Color(0xFF1565C0)..strokeWidth = (size.width * 0.005).clamp(1.0, 2.5)..style = PaintingStyle.stroke);

    final dotP = Paint()..color = const Color(0xFF1565C0);
    for (final deg in _keyDegs) {
      final rad = deg * math.pi / 180;
      canvas.drawCircle(Offset(cx + r * math.cos(rad), cy - r * math.sin(rad)), size.width * 0.012, dotP);
    }

    const labeled = {0: '0°', 90: '90°', 180: '180°', 270: '270°', 30: '30°', 45: '45°', 60: '60°'};
    for (final e in labeled.entries) {
      final rad = e.key * math.pi / 180;
      final lr = r * 1.16;
      _label(canvas, e.value, Offset(cx + lr * math.cos(rad), cy - lr * math.sin(rad)), fs, const Color(0xFF555555));
    }
    _label(canvas, '(1,0)', Offset(cx + r + size.width * 0.01, cy - fs), fs * 0.82, const Color(0xFF333333));
    _label(canvas, '(0,1)', Offset(cx + size.width * 0.04, cy - r - fs * 0.6), fs * 0.82, const Color(0xFF333333));
    _label(canvas, '(-1,0)', Offset(cx - r - size.width * 0.04, cy - fs), fs * 0.82, const Color(0xFF333333));
    _label(canvas, '(0,-1)', Offset(cx + size.width * 0.02, cy + r + fs * 0.6), fs * 0.82, const Color(0xFF333333));
  }

  void _label(Canvas c, String text, Offset center, double fs, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fs)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_UnitCirclePainter o) => false;
}

class _PolarGraphPainter extends CustomPainter {
  const _PolarGraphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width * 0.41;
    final ringStep = maxR / 4;
    final fs = (size.width * 0.027).clamp(7.0, 11.0);

    final gridP = Paint()..color = const Color(0xFFCCCCCC)..strokeWidth = (size.width * 0.003).clamp(0.5, 1.0)..style = PaintingStyle.stroke;
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(Offset(cx, cy), i * ringStep, gridP);
    }
    for (int deg = 0; deg < 360; deg += 30) {
      final rad = deg * math.pi / 180;
      canvas.drawLine(Offset(cx, cy), Offset(cx + maxR * math.cos(rad), cy - maxR * math.sin(rad)), gridP);
    }

    final axP = Paint()..color = const Color(0xFF555555)..strokeWidth = (size.width * 0.004).clamp(0.8, 1.8)..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - maxR, cy), Offset(cx + maxR, cy), axP);
    canvas.drawLine(Offset(cx, cy - maxR), Offset(cx, cy + maxR), axP);

    const angleLabels = {0: '0', 30: 'π/6', 60: 'π/3', 90: 'π/2', 120: '2π/3', 150: '5π/6', 180: 'π', 210: '7π/6', 240: '4π/3', 270: '3π/2', 300: '5π/3', 330: '11π/6'};
    for (final e in angleLabels.entries) {
      final rad = e.key * math.pi / 180;
      final lr = maxR + size.width * 0.07;
      _label(canvas, e.value, Offset(cx + lr * math.cos(rad), cy - lr * math.sin(rad)), fs, const Color(0xFF555555));
    }
    for (int i = 1; i <= 4; i++) {
      _label(canvas, '$i', Offset(cx + i * ringStep, cy - fs * 0.7), fs, const Color(0xFF888888));
    }
    canvas.drawCircle(Offset(cx, cy), size.width * 0.01, Paint()..color = const Color(0xFF333333));
  }

  void _label(Canvas c, String text, Offset center, double fs, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fs)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_PolarGraphPainter o) => false;
}

class _VennDiagramPainter extends CustomPainter {
  const _VennDiagramPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final r = size.width * 0.28;
    final cxA = size.width / 2 - size.width * 0.12;
    final cxB = size.width / 2 + size.width * 0.12;
    final fs = (size.width * 0.038).clamp(9.0, 15.0);
    final sw = (size.width * 0.004).clamp(1.0, 2.0);

    canvas.drawRRect(
      RRect.fromLTRBR(size.width * 0.04, size.height * 0.08, size.width * 0.96, size.height * 0.92, const Radius.circular(6)),
      Paint()..color = const Color(0xFFBBBBBB)..strokeWidth = (size.width * 0.003).clamp(0.5, 1.5)..style = PaintingStyle.stroke,
    );

    canvas.drawCircle(Offset(cxA, cy), r, Paint()..color = const Color(0x331565C0)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cxA, cy), r, Paint()..color = const Color(0xFF1565C0)..strokeWidth = sw..style = PaintingStyle.stroke);
    canvas.drawCircle(Offset(cxB, cy), r, Paint()..color = const Color(0x33E65100)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cxB, cy), r, Paint()..color = const Color(0xFFE65100)..strokeWidth = sw..style = PaintingStyle.stroke);

    _label(canvas, 'A', Offset(cxA - r * 0.44, cy), fs * 1.2, const Color(0xFF1565C0), bold: true);
    _label(canvas, 'B', Offset(cxB + r * 0.44, cy), fs * 1.2, const Color(0xFFE65100), bold: true);
    _label(canvas, 'A∩B', Offset(size.width / 2, cy), fs * 0.8, const Color(0xFF555555));
    _label(canvas, 'U', Offset(size.width * 0.08, size.height * 0.15), fs * 0.85, const Color(0xFF888888));
  }

  void _label(Canvas c, String text, Offset center, double fs, Color color, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fs, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_VennDiagramPainter o) => false;
}
