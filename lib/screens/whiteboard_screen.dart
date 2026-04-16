import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

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
  }

  void _undo() {
    if (_items.isNotEmpty) {
      setState(() {
        _redoStack.add(_items.removeLast());
        _selectedIndex = null;
      });
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      setState(() => _items.add(_redoStack.removeLast()));
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
  }

  void _deleteSelected() {
    if (_selectedIndex == null) return;
    setState(() {
      _items.removeAt(_selectedIndex!);
      _selectedIndex = null;
      _redoStack.clear();
    });
  }

  // ── Save / Open / New ─────────────────────────────────────────────────────

  Future<void> _saveBoard() async {
    try {
      final matrix = _transformationController.value;
      final data = jsonEncode({
        'version': 1,
        'background': _backgroundStyle.name,
        'items': _items.map((i) => i.toJson()).toList(),
        'transform': {
          'tx': matrix.entry(0, 3),
          'ty': matrix.entry(1, 3),
          'scale': matrix.getMaxScaleOnAxis(),
        },
      });

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save board',
        fileName: 'board.bord',
        type: FileType.custom,
        allowedExtensions: ['bord'],
      );
      if (path == null) return;

      await File(path).writeAsString(data);

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
              setState(() {
                _items.clear();
                _redoStack.clear();
                _selectedIndex = null;
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

    if (_tool == DrawingTool.math) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Math tool coming soon!'),
            duration: Duration(seconds: 2)),
      );
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

            // ── BORD logo — top left ────────────────────────────────────────
            Positioned(
              top: pad.top + 12,
              left: 16,
              child: _BordLogo(),
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
                  onNew: _newBoard,
                  onOpen: _openBoard,
                  onSave: _saveBoard,
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
                onBackgroundStyleChanged: (s) =>
                    setState(() => _backgroundStyle = s),
              ),
            ),

            // ── Select hint ─────────────────────────────────────────────────
            if (_tool == DrawingTool.select && _selectedIndex != null)
              Positioned(
                bottom: pad.bottom + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Drag to move · Delete to remove',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _BordLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
