import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/stroke.dart';
import '../painters/whiteboard_painter.dart';
import '../widgets/toolbar.dart';
import '../widgets/left_sidebar.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/insert_panel.dart';
import '../widgets/math_panel.dart';
import '../widgets/text_format_panel.dart';
import '../widgets/frame_picker_panel.dart';
import '../widgets/shape_picker_panel.dart';
import '../widgets/sticky_note_panel.dart';
import '../widgets/sticky_note_stack_view.dart';
import '../widgets/ruler_overlay.dart';
import '../widgets/bord_logo.dart';
import '../widgets/share_button.dart';
import '../widgets/item_cards.dart';
import '../widgets/insert_dialogs.dart';
import '../widgets/selection_hint.dart';

class WhiteboardScreen extends StatefulWidget {
  const WhiteboardScreen({super.key});

  @override
  State<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends State<WhiteboardScreen> {
  final _transformationController = TransformationController();
  final List<WhiteboardItem> _items = [];
  final _rulerKey = GlobalKey<RulerOverlayState>();
  final _boardCaptureKey = GlobalKey();
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
  bool _showFramePanel = false;
  bool _showShapePanel = false;
  bool _showStickyNotePanel = false;

  // Peel-from-stack state
  bool _isPeelingStack = false;
  Offset? _peelCanvasPos;
  Offset? _peelScreenPos;

  double _textFontSize = 16.0;
  bool _textBold = false;
  bool _textItalic = false;
  bool _textUnderline = false;
  bool _textStrikethrough = false;
  TextAlign _textAlign = TextAlign.left;
  String _textFontFamily = '';
  int _textIndentLevel = 0;
  bool _textBullet = false;
  double _textLineHeight = 1.2;
  Offset? _inlineTextCanvasPos;
  final _inlineTextController = TextEditingController();
  final _inlineTextFocus = FocusNode();
  bool _suppressNextTextTap = false;
  Timer? _commitTimer;

  bool _isPanning = false;
  bool _middleButtonPanning = false;
  DrawingTool? _rightButtonPrevTool;
  int _pointerCount = 0;
  Offset? _downCanvasPos;
  final Map<int, Offset> _pointerPositions = {};
  double _trackpadScaleCache = 1.0;

  // Select tool state
  int? _selectedIndex;
  Offset? _selectDragCanvas;

  static const double _canvasSize = 50000.0;
  static const Offset _canvasCenter = Offset(_canvasSize / 2, _canvasSize / 2);

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransform);
    _inlineTextFocus.addListener(_onInlineTextFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      _transformationController.value = Matrix4.translationValues(
        -_canvasCenter.dx + size.width / 2,
        -_canvasCenter.dy + size.height / 2,
        0,
      );
      _promptAutosaveSetup();
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _commitTimer?.cancel();
    _transformationController.removeListener(_onTransform);
    _transformationController.dispose();
    _inlineTextFocus.removeListener(_onInlineTextFocusChange);
    _inlineTextFocus.dispose();
    _inlineTextController.dispose();
    super.dispose();
  }

  void _onInlineTextFocusChange() {
    if (!_inlineTextFocus.hasFocus && _inlineTextCanvasPos != null) {
      _commitTimer?.cancel();
      _commitTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted && !_inlineTextFocus.hasFocus && _inlineTextCanvasPos != null) {
          _commitInlineText();
        }
      });
    }
  }

  void _refocusTextIfEditing() {
    if (_inlineTextCanvasPos != null) {
      _commitTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _inlineTextCanvasPos != null) {
          _inlineTextFocus.requestFocus();
        }
      });
    }
  }

  void _commitInlineText() {
    final text = _inlineTextController.text;
    final pos = _inlineTextCanvasPos;
    if (_inlineTextCanvasPos != null) {
      setState(() => _inlineTextCanvasPos = null);
    }
    _inlineTextController.clear();
    if (text.isNotEmpty && pos != null) {
      _addItem(TextItem(
        position: pos,
        text: text,
        color: _color,
        fontSize: _textFontSize,
        fontWeight: _textBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: _textItalic ? FontStyle.italic : FontStyle.normal,
        fontFamily: _textFontFamily,
        underline: _textUnderline,
        strikethrough: _textStrikethrough,
        textAlign: _textAlign,
        indentLevel: _textIndentLevel,
        bullet: _textBullet,
        lineHeight: _textLineHeight,
      ));
    }
  }

  Offset _toScreen(Offset canvas) =>
      MatrixUtils.transformPoint(_transformationController.value, canvas);

  void _onTransform() {
    final z = _transformationController.value.entry(0, 0);
    if ((z - _zoomLevel).abs() > 0.005) setState(() => _zoomLevel = z);
  }

  Offset _toCanvas(Offset screen) {
    final m = _transformationController.value.clone()..invert();
    return MatrixUtils.transformPoint(m, screen);
  }

  void _changeTool(DrawingTool t) {
    if (t != DrawingTool.text) _commitInlineText();
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

  void _zoomBy(double factor, {Offset? focalPoint}) {
    final size = MediaQuery.of(context).size;
    final focal = focalPoint ?? Offset(size.width / 2, size.height / 2);

    final matrix = _transformationController.value;
    final currentScale = matrix.entry(0, 0);
    final newScale = (currentScale * factor).clamp(0.1, 10.0);
    final ratio = newScale / currentScale;

    final tx = matrix.entry(0, 3);
    final ty = matrix.entry(1, 3);
    final newTx = focal.dx + ratio * (tx - focal.dx);
    final newTy = focal.dy + ratio * (ty - focal.dy);

    final next = Matrix4.translationValues(newTx, newTy, 0);
    next.setEntry(0, 0, newScale);
    next.setEntry(1, 1, newScale);
    _transformationController.value = next;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && event.scrollDelta.dy != 0) {
      final factor = math.exp(-event.scrollDelta.dy / 200.0);
      _zoomBy(factor, focalPoint: event.localPosition);
    }
  }

  void _onPointerPanZoomStart(PointerPanZoomStartEvent event) {
    _trackpadScaleCache = 1.0;
    if (_activeStroke != null) setState(() => _activeStroke = null);
  }

  void _onPointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    var matrix = _transformationController.value;

    // Two-finger drag → pan
    final d = event.panDelta;
    if (d != Offset.zero) {
      matrix = Matrix4.translationValues(d.dx, d.dy, 0.0) * matrix;
    }

    // Pinch → zoom around the gesture focal point
    final scaleRatio = _trackpadScaleCache > 0
        ? event.scale / _trackpadScaleCache
        : 1.0;
    if ((scaleRatio - 1.0).abs() > 0.001) {
      final currentScale = matrix.entry(0, 0);
      final newScale = (currentScale * scaleRatio).clamp(0.1, 10.0);
      final ratio = newScale / currentScale;
      final fp = event.localPosition;
      final next = Matrix4.translationValues(
        fp.dx + ratio * (matrix.entry(0, 3) - fp.dx),
        fp.dy + ratio * (matrix.entry(1, 3) - fp.dy),
        0,
      );
      next.setEntry(0, 0, newScale);
      next.setEntry(1, 1, newScale);
      matrix = next;
    }

    _trackpadScaleCache = event.scale;
    _transformationController.value = matrix;
  }

  void _onPointerPanZoomEnd(PointerPanZoomEndEvent event) {
    _trackpadScaleCache = 1.0;
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

  void _handleSelectDown(Offset canvasPos, Offset screenPos) {
    for (int i = _items.length - 1; i >= 0; i--) {
      if (_items[i].bounds.inflate(8).contains(canvasPos)) {
        final isStack = _items[i] is StickyNoteStackItem;
        setState(() {
          _selectedIndex = i;
          _selectDragCanvas = canvasPos;
          _isPeelingStack = isStack;
          if (isStack) {
            _peelCanvasPos = canvasPos;
            _peelScreenPos = screenPos;
          }
        });
        return;
      }
    }
    setState(() {
      _selectedIndex = null;
      _selectDragCanvas = null;
      _isPeelingStack = false;
      _peelCanvasPos = null;
      _peelScreenPos = null;
    });
  }

  void _handleSelectMove(Offset canvasPos, Offset screenPos) {
    if (_selectedIndex == null || _selectDragCanvas == null) return;
    if (_isPeelingStack) {
      setState(() {
        _peelCanvasPos = canvasPos;
        _peelScreenPos = screenPos;
      });
      return;
    }
    final delta = canvasPos - _selectDragCanvas!;
    setState(() {
      _items[_selectedIndex!] = _items[_selectedIndex!].movedBy(delta);
      _selectDragCanvas = canvasPos;
    });
  }

  void _handleSelectUp() {
    if (_isPeelingStack &&
        _peelCanvasPos != null &&
        _selectedIndex != null &&
        _selectDragCanvas != null) {
      final dist = (_peelCanvasPos! - _selectDragCanvas!).distance;
      if (dist > 12) {
        final stack = _items[_selectedIndex!] as StickyNoteStackItem;
        final topNote =
            stack.notes.isNotEmpty ? stack.notes.first : null;
        _addItem(StickyNoteItem(
          position: _peelCanvasPos!,
          text: topNote?.text ?? '',
          color: topNote?.color ?? stack.color,
        ));
      }
    } else if (_selectedIndex != null && !_isPeelingStack) {
      _tryMergeStickyNote(_selectedIndex!);
    }
    setState(() {
      _selectDragCanvas = null;
      _isPeelingStack = false;
      _peelCanvasPos = null;
      _peelScreenPos = null;
    });
    _scheduleAutosave();
  }

  void _tryMergeStickyNote(int draggedIndex) {
    final dragged = _items[draggedIndex];
    if (dragged is! StickyNoteItem) return;

    for (int i = _items.length - 1; i >= 0; i--) {
      if (i == draggedIndex) continue;
      final other = _items[i];
      if (!dragged.bounds.inflate(-20).overlaps(other.bounds)) continue;

      if (other is StickyNoteItem) {
        final stack = StickyNoteStackItem(
          position: other.position,
          color: other.color,
          notes: [
            (text: dragged.text, color: dragged.color),
            (text: other.text, color: other.color),
          ],
        );
        setState(() {
          _items.removeAt(draggedIndex);
          final otherIdx = _items.indexOf(other);
          _items[otherIdx] = stack;
          _selectedIndex = otherIdx;
        });
        return;
      }

      if (other is StickyNoteStackItem) {
        final updated = StickyNoteStackItem(
          position: other.position,
          color: other.color,
          notes: [
            (text: dragged.text, color: dragged.color),
            ...other.notes,
          ],
        );
        setState(() {
          _items.removeAt(draggedIndex);
          final otherIdx = _items.indexOf(other);
          _items[otherIdx] = updated;
          _selectedIndex = otherIdx;
        });
        return;
      }
    }
  }

  void _handleLassoSelect(List<Offset> polygon) {
    if (polygon.length < 3) return;
    for (int i = _items.length - 1; i >= 0; i--) {
      if (_pointInPolygon(_items[i].bounds.center, polygon)) {
        setState(() {
          _selectedIndex = i;
          _tool = DrawingTool.select;
        });
        return;
      }
    }
    setState(() => _selectedIndex = null);
  }

  void _handleRectSelect(List<Offset> points) {
    if (points.length < 2) return;
    final rect = Rect.fromPoints(points.first, points.last);
    for (int i = _items.length - 1; i >= 0; i--) {
      if (rect.overlaps(_items[i].bounds)) {
        setState(() {
          _selectedIndex = i;
          _tool = DrawingTool.select;
        });
        return;
      }
    }
    setState(() => _selectedIndex = null);
  }

  bool _pointInPolygon(Offset point, List<Offset> polygon) {
    int count = 0;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].dx, yi = polygon[i].dy;
      final xj = polygon[j].dx, yj = polygon[j].dy;
      if (((yi > point.dy) != (yj > point.dy)) &&
          point.dx < (xj - xi) * (point.dy - yi) / (yj - yi) + xi) {
        count++;
      }
    }
    return count.isOdd;
  }

  // ── Stroke eraser ──────────────────────────────────────────────────────────

  void _applyStrokeErase(Offset pos) {
    final radius = math.max(10.0, _strokeWidth * 3);
    bool changed = false;
    final newItems = <WhiteboardItem>[];
    for (final item in _items) {
      if (item case StrokeItem(:final stroke)) {
        final segments = _eraseFromStroke(stroke, pos, radius);
        if (segments.length == 1 && segments[0].points.length == stroke.points.length) {
          newItems.add(item);
        } else {
          changed = true;
          newItems.addAll(segments.map(StrokeItem.new));
        }
      } else {
        newItems.add(item);
      }
    }
    if (changed) {
      setState(() {
        _items..clear()..addAll(newItems);
        _redoStack.clear();
      });
      _scheduleAutosave();
    }
  }

  List<Stroke> _eraseFromStroke(Stroke stroke, Offset pos, double radius) {
    final segments = <List<Offset>>[];
    List<Offset>? current;
    for (final point in stroke.points) {
      if ((point - pos).distance > radius) {
        (current ??= []).add(point);
      } else if (current != null) {
        segments.add(current);
        current = null;
      }
    }
    if (current != null) segments.add(current);
    return segments.map((pts) => stroke.copyWith(points: pts)).toList();
  }

  // ── Line delete ────────────────────────────────────────────────────────────

  void _handleLineDelete(Offset pos) {
    const threshold = 20.0;
    for (int i = _items.length - 1; i >= 0; i--) {
      if (_items[i] case StrokeItem(:final stroke)) {
        if (_strokeHitTest(stroke, pos, threshold)) {
          setState(() {
            _items.removeAt(i);
            _redoStack.clear();
          });
          _scheduleAutosave();
          return;
        }
      }
    }
  }

  bool _strokeHitTest(Stroke stroke, Offset pos, double threshold) {
    for (int i = 0; i < stroke.points.length; i++) {
      if ((stroke.points[i] - pos).distance <= threshold) return true;
      if (i > 0 && _distPointToSegment(pos, stroke.points[i - 1], stroke.points[i]) <= threshold) {
        return true;
      }
    }
    return false;
  }

  double _distPointToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
    final proj = a + ab * t.clamp(0.0, 1.0);
    return (p - proj).distance;
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

  void _bringToFront(int index) {
    if (index < 0 || index >= _items.length - 1) return;
    setState(() {
      _items.add(_items.removeAt(index));
      _selectedIndex = _items.length - 1;
      _redoStack.clear();
    });
    _scheduleAutosave();
  }

  void _sendToBack(int index) {
    if (index <= 0 || index >= _items.length) return;
    setState(() {
      _items.insert(0, _items.removeAt(index));
      _selectedIndex = 0;
      _redoStack.clear();
    });
    _scheduleAutosave();
  }

  void _bringForward(int index) {
    if (index < 0 || index >= _items.length - 1) return;
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(index + 1, item);
      _selectedIndex = index + 1;
      _redoStack.clear();
    });
    _scheduleAutosave();
  }

  void _sendBackward(int index) {
    if (index <= 0 || index >= _items.length) return;
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(index - 1, item);
      _selectedIndex = index - 1;
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
        'scale': matrix.entry(0, 0),
      },
    };
  }

  Future<void> _saveBoard() async {
    try {
      final data = jsonEncode(_boardData());
      String? finalPath;

      if (Platform.isAndroid || Platform.isIOS) {
        final defaultName = _currentFilePath != null
            ? _currentFilePath!.split('/').last.replaceAll('.bord', '')
            : 'board';
        final name = await _promptFilename(initial: defaultName);
        if (name == null) return;
        final sanitized = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
        if (sanitized.isEmpty) return;
        final dir = await getApplicationDocumentsDirectory();
        finalPath = '${dir.path}/$sanitized.bord';
      } else {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Save board',
          fileName: 'board.bord',
          type: FileType.custom,
          allowedExtensions: ['bord'],
        );
        if (path == null) return;
        finalPath = path.endsWith('.bord') ? path : '$path.bord';
      }

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

  Future<String?> _promptFilename({required String initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save board'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'File name',
            suffixText: '.bord',
          ),
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
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

        if (!mounted) return;
        if (bordFiles.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No saved boards found')),
          );
          return;
        }

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
        if (file.path == null) throw Exception('Could not read file');
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

      final t = json['transform'] as Map<String, dynamic>;
      final scale = (t['scale'] as num).toDouble();
      final m = Matrix4.identity()
        ..setEntry(0, 0, scale)
        ..setEntry(1, 1, scale)
        ..setEntry(2, 2, 1)
        ..setEntry(0, 3, (t['tx'] as num).toDouble())
        ..setEntry(1, 3, (t['ty'] as num).toDouble());

      setState(() {
        _currentFilePath = filePath;
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
              Navigator.pop(ctx);
              _autosaveTimer?.cancel();
              setState(() {
                _items.clear();
                _redoStack.clear();
                _selectedIndex = null;
                _currentFilePath = null;
                _autosaveEnabled = false;
              });
              _zoomReset();
              _promptAutosaveSetup();
            },
            child: const Text('New board'),
          ),
        ],
      ),
    );
  }

  Future<void> _promptAutosaveSetup() async {
    if (!mounted) return;

    if (Platform.isAndroid || Platform.isIOS) {
      final controller = TextEditingController(text: 'board');
      final save = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Save your board'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Name your board to enable autosave.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Board name',
                  suffixText: '.bord',
                ),
                autofocus: true,
                onSubmitted: (_) => Navigator.pop(ctx, true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continue without Autosave'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save & Autosave'),
            ),
          ],
        ),
      );
      if (save == true && mounted) {
        final name = controller.text.trim();
        final sanitized = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
        if (sanitized.isNotEmpty) {
          final dir = await getApplicationDocumentsDirectory();
          final path = '${dir.path}/$sanitized.bord';
          await File(path).writeAsString(jsonEncode(_boardData()));
          if (mounted) setState(() { _currentFilePath = path; _autosaveEnabled = true; });
        }
      }
    } else {
      final save = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Save your board'),
          content: const Text('Choose a save location to enable autosave.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continue without Autosave'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Choose Location'),
            ),
          ],
        ),
      );
      if (save == true && mounted) {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Save board',
          fileName: 'board.bord',
          type: FileType.custom,
          allowedExtensions: ['bord'],
        );
        if (path != null && mounted) {
          final finalPath = path.endsWith('.bord') ? path : '$path.bord';
          await File(finalPath).writeAsString(jsonEncode(_boardData()));
          setState(() { _currentFilePath = finalPath; _autosaveEnabled = true; });
        }
      }
    }
  }

  // ── Viewport helper ───────────────────────────────────────────────────────

  Offset get _viewportCenter {
    final size = MediaQuery.of(context).size;
    final m = _transformationController.value.clone()..invert();
    return MatrixUtils.transformPoint(m, Offset(size.width / 2, size.height / 2));
  }

  // ── Share / Export ──────────────────────────────────────────────────────────

  Rect _computeContentBounds() {
    if (_items.isEmpty) return const Rect.fromLTWH(0, 0, 1200, 900);
    var bounds = _items.first.bounds;
    for (final item in _items.skip(1)) {
      bounds = bounds.expandToInclude(item.bounds);
    }
    return bounds.inflate(50);
  }

  Future<Uint8List?> _captureAsImage() async {
    final contentBounds = _computeContentBounds();
    final screenSize = MediaQuery.of(context).size;
    final scale = math.min(
          screenSize.width / contentBounds.width,
          screenSize.height / contentBounds.height,
        ) *
        0.95;
    final tx = screenSize.width / 2 - scale * contentBounds.center.dx;
    final ty = screenSize.height / 2 - scale * contentBounds.center.dy;
    final fitMatrix = Matrix4.diagonal3Values(scale, scale, 1.0);
    fitMatrix.setTranslationRaw(tx, ty, 0.0);

    final savedMatrix = _transformationController.value.clone();
    setState(() => _transformationController.value = fitMatrix);
    await WidgetsBinding.instance.endOfFrame;

    try {
      final boundary = _boardCaptureKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      if (mounted) setState(() => _transformationController.value = savedMatrix);
    }
  }

  Future<Uint8List> _buildPdf(Uint8List pngBytes) async {
    final doc = pw.Document();
    final img = pw.MemoryImage(pngBytes);
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(16),
      build: (ctx) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
    ));
    return doc.save();
  }

  Future<void> _exportAsPng() async {
    final bytes = await _captureAsImage();
    if (bytes == null || !mounted) return;
    if (Platform.isWindows) {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PNG',
        fileName: 'board.png',
        type: FileType.custom,
        allowedExtensions: ['png'],
      );
      if (path != null) {
        await File(path).writeAsBytes(bytes);
        if (mounted) _showSnack('Saved to $path');
      }
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/board_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      if (mounted) _showSnack('Saved to ${file.path}');
    }
  }

  Future<void> _exportAsPdf() async {
    final png = await _captureAsImage();
    if (png == null || !mounted) return;
    final pdfBytes = await _buildPdf(png);
    if (Platform.isWindows) {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF',
        fileName: 'board.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (path != null) {
        await File(path).writeAsBytes(pdfBytes);
        if (mounted) _showSnack('Saved to $path');
      }
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/board_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(pdfBytes);
      if (mounted) _showSnack('Saved to ${file.path}');
    }
  }

  Future<void> _shareViaOs() async {
    final bytes = await _captureAsImage();
    if (bytes == null || !mounted) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/board_share.png');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'BORD export'),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ExportSheet(
        onSavePng: () {
          Navigator.pop(context);
          _exportAsPng();
        },
        onSavePdf: () {
          Navigator.pop(context);
          _exportAsPdf();
        },
        onShare: () {
          Navigator.pop(context);
          _shareViaOs();
        },
      ),
    );
  }

  // ── Insert ─────────────────────────────────────────────────────────────────

  void _closeAllPanels() {
    _showInsertPanel = false;
    _showMathPanel = false;
    _showFramePanel = false;
    _showShapePanel = false;
    _showStickyNotePanel = false;
  }

  void _showInsertMenu() {
    setState(() { final open = !_showInsertPanel; _closeAllPanels(); _showInsertPanel = open; });
  }

  void _closeInsertPanel() => setState(() => _showInsertPanel = false);

  void _toggleMathPanel() {
    setState(() { final open = !_showMathPanel; _closeAllPanels(); _showMathPanel = open; });
  }

  void _closeMathPanel() => setState(() => _showMathPanel = false);

  void _showFrameMenu() {
    setState(() { final open = !_showFramePanel; _closeAllPanels(); _showFramePanel = open; });
  }

  void _closeFramePanel() => setState(() => _showFramePanel = false);

  void _showShapeMenu() {
    setState(() { final open = !_showShapePanel; _closeAllPanels(); _showShapePanel = open; });
  }

  void _closeShapePanel() => setState(() => _showShapePanel = false);

  void _showStickyNoteMenu() {
    setState(() { final open = !_showStickyNotePanel; _closeAllPanels(); _showStickyNotePanel = open; });
  }

  void _closeStickyNotePanel() => setState(() => _showStickyNotePanel = false);

  Future<void> _configureAndInsertShape(ShapeType type) async {
    final result = await showShapeConfigDialog(context, type, _color, _strokeWidth);
    if (result == null) return;
    final center = _viewportCenter;
    _addItem(ShapeItem(
      position: center - Offset(result.width / 2, type == ShapeType.line ? 0 : result.height / 2),
      shapeType: type,
      width: result.width,
      height: type == ShapeType.line ? 0 : result.height,
      strokeColor: _color,
      strokeWidth: _strokeWidth,
      filled: result.filled,
      fillColor: result.fillColor,
    ));
  }

  void _insertFrame(FrameType type) {
    final w = FrameItem.defaultWidth(type);
    final h = FrameItem.defaultHeight(type);
    final center = _viewportCenter;
    _addItem(FrameItem(
      position: center - Offset(w / 2, h / 2),
      frameType: type,
    ));
  }

  void _insertMathGraph(MathGraphType type) {
    final center = _viewportCenter;
    final temp = MathGraphItem(graphType: type, position: Offset.zero);
    _addItem(MathGraphItem(
      graphType: type,
      position: center - Offset(temp.width / 2, temp.height / 2),
    ));
  }

  void _insertEquationText(String equation) {
    final center = _viewportCenter;
    _addItem(TextItem(
      position: center - const Offset(0, 12),
      text: equation,
      color: Colors.black,
      fontSize: 22.0,
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

  void _placeShape(ShapeType type, Offset screenPoint) {
    final pos = _toCanvas(screenPoint);
    const size = 150.0;
    _addItem(ShapeItem(
      position: pos - Offset(size / 2, type == ShapeType.line ? 0 : size / 2),
      shapeType: type,
      width: size,
      height: type == ShapeType.line ? 0 : size,
      strokeColor: _color,
      strokeWidth: _strokeWidth,
      filled: false,
      fillColor: Colors.transparent,
    ));
  }

  void _placeFrame(FrameType type, Offset screenPoint) {
    final pos = _toCanvas(screenPoint);
    final w = FrameItem.defaultWidth(type);
    final h = FrameItem.defaultHeight(type);
    _addItem(FrameItem(
      position: pos - Offset(w / 2, h / 2),
      frameType: type,
    ));
  }

  void _placeInsertItem(InsertDragType type, Offset screenPoint) {
    final pos = _toCanvas(screenPoint);
    switch (type) {
      case InsertDragType.table:
        const rows = 3, cols = 3;
        final w = (cols * 100.0).clamp(200.0, 800.0);
        final h = rows * 36.0 + 4.0;
        _addItem(TableItem.empty(position: pos - Offset(w / 2, h / 2), rows: rows, cols: cols));
      case InsertDragType.checklist:
        _addItem(ChecklistItem(position: pos - const Offset(ChecklistItem.cardWidth / 2, 63)));
      case InsertDragType.liveTime:
        final w = DateTimeItem.widthFor(DateTimeMode.time);
        final h = DateTimeItem.heightFor(DateTimeMode.time);
        _addItem(DateTimeItem(position: pos - Offset(w / 2, h / 2), mode: DateTimeMode.time, isLive: true, createdAt: DateTime.now()));
      case InsertDragType.liveDate:
        final w = DateTimeItem.widthFor(DateTimeMode.date);
        final h = DateTimeItem.heightFor(DateTimeMode.date);
        _addItem(DateTimeItem(position: pos - Offset(w / 2, h / 2), mode: DateTimeMode.date, isLive: true, createdAt: DateTime.now()));
      case InsertDragType.liveClock:
        final w = DateTimeItem.widthFor(DateTimeMode.datetime);
        final h = DateTimeItem.heightFor(DateTimeMode.datetime);
        _addItem(DateTimeItem(position: pos - Offset(w / 2, h / 2), mode: DateTimeMode.datetime, isLive: true, createdAt: DateTime.now()));
      case InsertDragType.timestamp:
        final w = DateTimeItem.widthFor(DateTimeMode.datetime);
        final h = DateTimeItem.heightFor(DateTimeMode.datetime);
        _addItem(DateTimeItem(position: pos - Offset(w / 2, h / 2), mode: DateTimeMode.datetime, isLive: false, createdAt: DateTime.now()));
    }
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

  void _insertChecklist() {
    final center = _viewportCenter;
    _addItem(ChecklistItem(
      position: center - const Offset(ChecklistItem.cardWidth / 2, 63),
    ));
  }

  void _insertDateTime(DateTimeMode mode, bool isLive) {
    final center = _viewportCenter;
    final w = DateTimeItem.widthFor(mode);
    final h = DateTimeItem.heightFor(mode);
    _addItem(DateTimeItem(
      position: center - Offset(w / 2, h / 2),
      mode: mode,
      isLive: isLive,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> _insertTable() async {
    final result = await showInsertTableDialog(context);
    if (result == null) return;
    final center = _viewportCenter;
    final w = (result.cols * 100.0).clamp(200.0, 800.0);
    final h = result.rows * 36.0 + 4.0;
    _addItem(TableItem.empty(
      position: center - Offset(w / 2, h / 2),
      rows: result.rows,
      cols: result.cols,
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
    final result = await showInsertLinkDialog(context);
    if (result == null) return;
    final center = _viewportCenter;
    _addItem(LinkItem(
      position: center - const Offset(LinkItem.cardWidth / 2, LinkItem.cardHeight / 2),
      url: result.url,
      label: result.label,
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

  Future<void> _insertPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    final pdfPath = result.files.single.path!;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Opening PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    late final PdfDocument document;
    try {
      document = await PdfDocument.openFile(pdfPath);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF: $e')),
        );
      }
      return;
    }

    final pageCount = document.pages.length;
    if (!mounted) {
      await document.dispose();
      return;
    }
    Navigator.of(context).pop();

    List<int> pagesToImport;
    if (pageCount > 1) {
      final chosen = await showImportPdfPagesDialog(context, pageCount);
      if (chosen == null || chosen.isEmpty) {
        await document.dispose();
        return;
      }
      pagesToImport = chosen;
    } else {
      pagesToImport = [0];
    }

    if (!mounted) {
      await document.dispose();
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Rendering pages...'),
              ],
            ),
          ),
        ),
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final pdfBaseName = pdfPath.hashCode.abs();
    final center = _viewportCenter;
    double nextY = center.dy;
    bool firstPage = true;

    try {
      for (final pageIndex in pagesToImport) {
        final page = document.pages[pageIndex];
        const renderWidth = 800.0;
        final scale = renderWidth / page.width;
        final renderHeight = page.height * scale;

        final pdfImage = await page.render(
          fullWidth: renderWidth,
          fullHeight: renderHeight,
          backgroundColor: Colors.white,
        );
        if (pdfImage == null) continue;

        final uiImage = await pdfImage.createImage();
        final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        uiImage.dispose();
        pdfImage.dispose();
        if (byteData == null) continue;

        final tempFile = File('${tempDir.path}/pdf_${pdfBaseName}_p${pageIndex + 1}.png');
        await tempFile.writeAsBytes(byteData.buffer.asUint8List());

        final x = center.dx - renderWidth / 2;
        if (firstPage) {
          nextY = center.dy - renderHeight / 2;
          firstPage = false;
        }

        _addItem(ImageItem(
          position: Offset(x, nextY),
          path: tempFile.path,
          width: renderWidth,
          height: renderHeight,
        ));

        nextY += renderHeight + 20;
      }
    } finally {
      await document.dispose();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _editTable(int index) async {
    final table = _items[index] as TableItem;
    final updatedCells = await showEditTableDialog(context, table);
    if (updatedCells == null) return;
    setState(() => _items[index] = table.withCells(updatedCells));
    _scheduleAutosave();
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
    final scale = matrix.entry(0, 0);
    return Stack(
      children: [
        for (final (index, item) in _items.indexed)
          if (item is ImageItem ||
              item is TableItem ||
              item is AttachmentItem ||
              item is LinkItem ||
              item is VideoItem ||
              item is PrintoutItem ||
              item is MathGraphItem ||
              item is ChecklistItem ||
              item is DateTimeItem ||
              item is TextItem)
            _buildRichOverlayItem(item, index, matrix, scale),
      ],
    );
  }

  Widget _buildTextOverlayContent(TextItem item, double scale) {
    final scaledSize = item.fontSize * scale;
    final indent = item.indentLevel * TextItem.indentStep * scale;
    final decoration = TextDecoration.combine([
      if (item.underline) TextDecoration.underline,
      if (item.strikethrough) TextDecoration.lineThrough,
    ]);
    final style = TextStyle(
      color: item.color,
      fontSize: scaledSize,
      fontWeight: item.fontWeight,
      fontStyle: item.fontStyle,
      fontFamily: item.fontFamily.isEmpty ? null : item.fontFamily,
      decoration: (item.underline || item.strikethrough) ? decoration : null,
      decorationColor: item.color,
      height: item.lineHeight,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (indent > 0) SizedBox(width: indent),
        if (item.bullet)
          Text('• ', style: style),
        Flexible(child: Text(item.text, style: style, textAlign: item.textAlign)),
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
      final ImageItem i => ImageCard(item: i),
      final TableItem i => TableCard(item: i, scale: scale),
      final AttachmentItem i => AttachmentCard(item: i),
      final LinkItem i => LinkCard(item: i),
      final VideoItem i => VideoCard(item: i),
      final PrintoutItem i => PrintoutCard(item: i),
      final MathGraphItem i => MathGraphCard(item: i),
      final ChecklistItem i => ChecklistCard(
          item: i,
          onUpdate: (updated) {
            setState(() => _items[index] = updated);
            _scheduleAutosave();
          },
        ),
      final DateTimeItem i => DateTimeCard(item: i),
      final TextItem i => _buildTextOverlayContent(i, scale),
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

  Widget _buildGhostNote(Color color) {
    return Container(
      width: 120,
      height: 96,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(50),
              blurRadius: 10,
              offset: const Offset(2, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 18,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(28),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(3)),
            ),
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

  bool get _isTapTool => _tool == DrawingTool.text;

  void _onPointerDown(PointerDownEvent event) {
    // Middle mouse: temporary pan (handled before pointer-count tracking)
    if ((event.buttons & kMiddleMouseButton) != 0) {
      setState(() {
        _middleButtonPanning = true;
        _activeStroke = null;
      });
      return;
    }

    // Right mouse: temporary stroke-eraser while button is held
    if ((event.buttons & kSecondaryMouseButton) != 0 && _isDrawingTool) {
      _rightButtonPrevTool = _tool;
      setState(() => _tool = DrawingTool.strokeEraser);
      _applyStrokeErase(_toCanvas(event.position));
      return;
    }

    _suppressNextTextTap = false;
    if (_inlineTextCanvasPos != null) {
      _commitInlineText();
      _suppressNextTextTap = true;
    }
    _pointerCount++;
    _pointerPositions[event.pointer] = event.position;
    _downCanvasPos = _toCanvas(event.position);

    if (_pointerCount > 1 || _tool == DrawingTool.pan) {
      setState(() {
        _activeStroke = null;
        _isPanning = true;
      });
      return;
    }

    if (_tool == DrawingTool.select) {
      _handleSelectDown(_downCanvasPos!, event.position);
      return;
    }

    if (_tool == DrawingTool.lassoSelect) {
      setState(() {
        _isPanning = false;
        _activeStroke = Stroke(
          points: [_downCanvasPos!],
          color: const Color(0xFF1E88E5),
          strokeWidth: 1.5,
          tool: DrawingTool.lassoSelect,
        );
      });
      return;
    }

    if (_tool == DrawingTool.rectSelect) {
      setState(() {
        _isPanning = false;
        _activeStroke = Stroke(
          points: [_downCanvasPos!],
          color: const Color(0xFF1E88E5),
          strokeWidth: 1.5,
          tool: DrawingTool.rectSelect,
        );
      });
      return;
    }

    if (_tool == DrawingTool.strokeEraser) {
      _applyStrokeErase(_downCanvasPos!);
      return;
    }

    if (_tool == DrawingTool.lineDelete) {
      _handleLineDelete(_downCanvasPos!);
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

  void _applyTwoFingerGesture(PointerMoveEvent event) {
    final prevPos = _pointerPositions[event.pointer];
    final currPos = event.position;
    final otherEntry = _pointerPositions.entries
        .firstWhere((e) => e.key != event.pointer, orElse: () => const MapEntry(-1, Offset.zero));
    if (prevPos == null || otherEntry.key == -1) return;

    final otherPos = otherEntry.value;
    final prevDist = (prevPos - otherPos).distance;
    final currDist = (currPos - otherPos).distance;
    final scaleFactor = prevDist > 5.0 ? (currDist / prevDist) : 1.0;

    final prevMid = (prevPos + otherPos) / 2;
    final currMid = (currPos + otherPos) / 2;

    final matrix = _transformationController.value;
    final currentScale = matrix.entry(0, 0);
    final newScale = (currentScale * scaleFactor).clamp(0.1, 10.0);
    final ratio = newScale / currentScale;

    final tx = matrix.entry(0, 3);
    final ty = matrix.entry(1, 3);
    // Scale around prevMid then translate canvas so prevMid lands at currMid
    final newTx = currMid.dx + ratio * (tx - prevMid.dx);
    final newTy = currMid.dy + ratio * (ty - prevMid.dy);

    final next = Matrix4.translationValues(newTx, newTy, 0);
    next.setEntry(0, 0, newScale);
    next.setEntry(1, 1, newScale);
    _transformationController.value = next;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_middleButtonPanning) {
      final d = event.delta;
      _transformationController.value =
          Matrix4.translationValues(d.dx, d.dy, 0.0) *
              _transformationController.value;
      return;
    }
    if (_isPanning) {
      if (_pointerCount >= 2) {
        _applyTwoFingerGesture(event);
      } else if (_tool == DrawingTool.pan) {
        final d = event.delta;
        _transformationController.value =
            Matrix4.translationValues(d.dx, d.dy, 0.0) *
                _transformationController.value;
      }
      _pointerPositions[event.pointer] = event.position;
      return;
    }

    if (_tool == DrawingTool.select) {
      _handleSelectMove(_toCanvas(event.position), event.position);
      return;
    }

    if (_tool == DrawingTool.strokeEraser) {
      _applyStrokeErase(_toCanvas(event.position));
      return;
    }

    if (_tool == DrawingTool.lineDelete) {
      _handleLineDelete(_toCanvas(event.position));
      return;
    }

    if (_activeStroke == null) return;
    final pos = _toCanvas(event.position);
    setState(() {
      if (_tool == DrawingTool.shape ||
          _tool == DrawingTool.frame ||
          _tool == DrawingTool.ruler ||
          _tool == DrawingTool.rectSelect) {
        _activeStroke = _activeStroke!
            .copyWith(points: [_activeStroke!.points.first, pos]);
      } else {
        _activeStroke = _activeStroke!
            .copyWith(points: [..._activeStroke!.points, pos]);
      }
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_middleButtonPanning) {
      setState(() => _middleButtonPanning = false);
      return;
    }
    if (_rightButtonPrevTool != null) {
      setState(() {
        _tool = _rightButtonPrevTool!;
        _rightButtonPrevTool = null;
      });
      return;
    }
    _pointerPositions.remove(event.pointer);
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
      if (s.tool == DrawingTool.lassoSelect) {
        _handleLassoSelect(s.points);
      } else if (s.tool == DrawingTool.rectSelect) {
        _handleRectSelect(s.points);
      } else if (s.points.isNotEmpty) {
        _addItem(StrokeItem(s));
      }
    }
    _downCanvasPos = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_middleButtonPanning) {
      setState(() => _middleButtonPanning = false);
      return;
    }
    if (_rightButtonPrevTool != null) {
      setState(() {
        _tool = _rightButtonPrevTool!;
        _rightButtonPrevTool = null;
      });
      return;
    }
    _pointerPositions.remove(event.pointer);
    _pointerCount = (_pointerCount - 1).clamp(0, 10);
    setState(() {
      _activeStroke = null;
      _selectDragCanvas = null;
      if (_pointerCount == 0) _isPanning = false;
    });
    _downCanvasPos = null;
  }

  TextItem? _findTextItemAt(Offset canvasPos) {
    for (var i = _items.length - 1; i >= 0; i--) {
      final item = _items[i];
      if (item is TextItem && item.bounds.inflate(6).contains(canvasPos)) {
        return item;
      }
    }
    return null;
  }

  Future<void> _handleTap(Offset canvasPos) async {
    if (_tool == DrawingTool.text) {
      final existing = _findTextItemAt(canvasPos);
      if (existing != null) {
        // Edit the tapped text item regardless of suppress flag
        _suppressNextTextTap = false;
        setState(() {
          _items.remove(existing);
          _inlineTextCanvasPos = existing.position;
          _inlineTextController.text = existing.text;
          _textFontSize = existing.fontSize;
          _textBold = existing.fontWeight == FontWeight.bold;
          _textItalic = existing.fontStyle == FontStyle.italic;
          _textUnderline = existing.underline;
          _textStrikethrough = existing.strikethrough;
          _textFontFamily = existing.fontFamily;
          _textAlign = existing.textAlign;
          _color = existing.color;
          _textIndentLevel = existing.indentLevel;
          _textBullet = existing.bullet;
          _textLineHeight = existing.lineHeight;
        });
        _inlineTextFocus.requestFocus();
      } else if (_suppressNextTextTap) {
        _suppressNextTextTap = false;
      } else {
        setState(() {
          _inlineTextCanvasPos = canvasPos;
          _inlineTextController.clear();
        });
        _inlineTextFocus.requestFocus();
      }
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
          if (_inlineTextCanvasPos != null) return;
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
            // ── Content layer (canvas + overlays, captured for export) ──────
            RepaintBoundary(
              key: _boardCaptureKey,
              child: Stack(children: [
            // ── Canvas ─────────────────────────────────────────────────────
            Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              onPointerSignal: _onPointerSignal,
              onPointerPanZoomStart: _onPointerPanZoomStart,
              onPointerPanZoomUpdate: _onPointerPanZoomUpdate,
              onPointerPanZoomEnd: _onPointerPanZoomEnd,
              child: InteractiveViewer(
                transformationController: _transformationController,
                panEnabled: false,
                scaleEnabled: false,
                boundaryMargin: EdgeInsets.all(double.infinity),
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

            // ── Annotation overlay (strokes always above rich items) ────────
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _transformationController,
                builder: (context, _) => SizedBox.expand(
                  child: CustomPaint(
                    painter: AnnotationPainter(
                      items: _items,
                      activeStroke: _activeStroke,
                      transformMatrix: _transformationController.value,
                      selectedIndex: _selectedIndex,
                    ),
                  ),
                ),
              ),
            ),
              ]), // inner Stack
            ), // RepaintBoundary

            // ── Ruler overlay (Offstage preserves state across tool switches) ─
            Offstage(
              offstage: _tool != DrawingTool.ruler,
              child: RulerOverlay(key: _rulerKey),
            ),

            // ── BORD logo — top left ────────────────────────────────────────
            Positioned(
              top: pad.top + 12,
              left: 16,
              child: BordLogo(
              onNew: _newBoard,
              onOpen: _openBoard,
              onSave: _saveBoard,
              onClear: _clear,
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
                  onColorChanged: (c) {
                    if (!_isDrawingTool) _changeTool(DrawingTool.pen);
                    setState(() => _color = c);
                  },
                  onStrokeWidthChanged: (w) =>
                      setState(() => _strokeWidth = w),
                  onAddRuler: () => _rulerKey.currentState?.addRuler(),
                  onClearRulers: () => _rulerKey.currentState?.clearRulers(),
                ),
              ),
            ),

            // ── Share — top right ───────────────────────────────────────────
            Positioned(
              top: pad.top + 12,
              right: 16,
              child: ShareButton(onTap: _showShareSheet),
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
                  onInsert: _showInsertMenu,
                  onMath: _toggleMathPanel,
                  onFrame: _showFrameMenu,
                  onShape: _showShapeMenu,
                  onStickyNote: _showStickyNoteMenu,
                  mathPanelOpen: _showMathPanel,
                  framePanelOpen: _showFramePanel,
                  shapePanelOpen: _showShapePanel,
                  stickyNotePanelOpen: _showStickyNotePanel,
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
                child: Center(child: SelectionHint(
                  item: _items[_selectedIndex!],
                  onOpenLink: _openLink,
                  onOpenFile: _openFile,
                  onEditTable: () => _editTable(_selectedIndex!),
                  onBringToFront: () => _bringToFront(_selectedIndex!),
                  onBringForward: () => _bringForward(_selectedIndex!),
                  onSendBackward: () => _sendBackward(_selectedIndex!),
                  onSendToBack: () => _sendToBack(_selectedIndex!),
                )),
              ),

            // ── Peel ghost ───────────────────────────────────────────────────
            if (_isPeelingStack && _peelScreenPos != null)
              Positioned(
                left: _peelScreenPos!.dx - 60,
                top: _peelScreenPos!.dy - 48,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.85,
                    child: _buildGhostNote(
                      (_selectedIndex != null &&
                              _items[_selectedIndex!] is StickyNoteStackItem)
                          ? (_items[_selectedIndex!] as StickyNoteStackItem)
                              .displayColor
                          : const Color(0xFFFFF9C4),
                    ),
                  ),
                ),
              ),

            // ── View Notes button (stack selected) ──────────────────────────
            if (_tool == DrawingTool.select &&
                _selectedIndex != null &&
                _selectedIndex! < _items.length &&
                _items[_selectedIndex!] is StickyNoteStackItem)
              Builder(builder: (ctx) {
                final stack =
                    _items[_selectedIndex!] as StickyNoteStackItem;
                final screenPos = _toScreen(stack.position);
                return Positioned(
                  left: screenPos.dx,
                  top: screenPos.dy - 36,
                  child: GestureDetector(
                    onTap: () => StickyNoteStackViewDialog.show(
                      context,
                      stack,
                      (i) => setState(() {
                        _items[_selectedIndex!] =
                            stack.withNotesReordered(i);
                        _scheduleAutosave();
                      }),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.layers_rounded,
                              size: 14, color: Color(0xFF555555)),
                          const SizedBox(width: 4),
                          Text(
                            stack.notes.isEmpty
                                ? 'Stack'
                                : '${stack.notes.length} notes',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

            // ── Math panel barrier + flyout ──────────────────────────────────
            if (_showMathPanel) ...[
              Positioned(
                left: 64, top: 0, right: 0, bottom: 0,
                child: GestureDetector(
                  onTap: _closeMathPanel,
                  behavior: HitTestBehavior.opaque,
                ),
              ),
              Positioned(
                left: 72,
                top: 0,
                bottom: 0,
                child: Center(
                  child: MathPanel(
                    onInsert: (type) {
                      _closeMathPanel();
                      _insertMathGraph(type);
                    },
                    onInsertEquation: (eq) {
                      _closeMathPanel();
                      _insertEquationText(eq);
                    },
                    onDragStarted: _closeMathPanel,
                  ),
                ),
              ),
            ],

            // ── Text format panel — below toolbar when text tool active ────────
            if (_tool == DrawingTool.text)
              Positioned(
                top: pad.top + 70,
                left: 0,
                right: 0,
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) {
                    _commitTimer?.cancel();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _inlineTextCanvasPos != null) {
                        _inlineTextFocus.requestFocus();
                      }
                    });
                  },
                  child: Center(
                  child: TextFormatPanel(
                    fontSize: _textFontSize,
                    bold: _textBold,
                    italic: _textItalic,
                    underline: _textUnderline,
                    strikethrough: _textStrikethrough,
                    fontFamily: _textFontFamily,
                    color: _color,
                    textAlign: _textAlign,
                    indentLevel: _textIndentLevel,
                    bullet: _textBullet,
                    lineHeight: _textLineHeight,
                    onFontSizeChanged: (v) { setState(() => _textFontSize = v); _refocusTextIfEditing(); },
                    onBoldChanged: (v) { setState(() => _textBold = v); _refocusTextIfEditing(); },
                    onItalicChanged: (v) { setState(() => _textItalic = v); _refocusTextIfEditing(); },
                    onUnderlineChanged: (v) { setState(() => _textUnderline = v); _refocusTextIfEditing(); },
                    onStrikethroughChanged: (v) { setState(() => _textStrikethrough = v); _refocusTextIfEditing(); },
                    onFontFamilyChanged: (v) { setState(() => _textFontFamily = v); _refocusTextIfEditing(); },
                    onColorChanged: (c) { setState(() => _color = c); _refocusTextIfEditing(); },
                    onAlignChanged: (a) { setState(() => _textAlign = a); _refocusTextIfEditing(); },
                    onIndentChanged: (v) { setState(() => _textIndentLevel = v.clamp(0, 8)); _refocusTextIfEditing(); },
                    onBulletChanged: (v) { setState(() => _textBullet = v); _refocusTextIfEditing(); },
                    onLineHeightChanged: (v) { setState(() => _textLineHeight = v); _refocusTextIfEditing(); },
                    onClearFormatting: () {
                      setState(() {
                        _textBold = false;
                        _textItalic = false;
                        _textUnderline = false;
                        _textStrikethrough = false;
                        _textAlign = TextAlign.left;
                        _textFontSize = 16.0;
                        _textFontFamily = '';
                        _textIndentLevel = 0;
                        _textBullet = false;
                        _textLineHeight = 1.2;
                      });
                      _refocusTextIfEditing();
                    },
                  ),
                  ),
                ),
              ),

            // ── Inline text editor ──────────────────────────────────────────
            if (_inlineTextCanvasPos != null)
              AnimatedBuilder(
                animation: _transformationController,
                builder: (ctx, _) {
                  final screenPos = _toScreen(_inlineTextCanvasPos!);
                  final scaledSize = (_textFontSize * _zoomLevel).clamp(8.0, 120.0);
                  return Positioned(
                    left: screenPos.dx,
                    top: screenPos.dy,
                    child: IntrinsicWidth(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 80, maxWidth: 500),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Indent offset
                            if (_textIndentLevel > 0)
                              SizedBox(width: _textIndentLevel * 24.0 * _zoomLevel),
                            // Bullet prefix
                            if (_textBullet)
                              Padding(
                                padding: EdgeInsets.only(top: 2 * _zoomLevel, right: 4 * _zoomLevel),
                                child: Text('•',
                                    style: TextStyle(
                                      fontSize: scaledSize,
                                      color: _color,
                                      fontWeight: _textBold ? FontWeight.bold : FontWeight.normal,
                                      height: _textLineHeight,
                                    )),
                              ),
                            Flexible(
                              child: TextField(
                                controller: _inlineTextController,
                                focusNode: _inlineTextFocus,
                                autofocus: true,
                                maxLines: null,
                                style: TextStyle(
                                  fontSize: scaledSize,
                                  color: _color,
                                  fontWeight: _textBold ? FontWeight.bold : FontWeight.normal,
                                  fontStyle: _textItalic ? FontStyle.italic : FontStyle.normal,
                                  fontFamily: _textFontFamily.isEmpty ? null : _textFontFamily,
                                  height: _textLineHeight,
                                  decoration: (_textUnderline || _textStrikethrough)
                                      ? TextDecoration.combine([
                                          if (_textUnderline) TextDecoration.underline,
                                          if (_textStrikethrough) TextDecoration.lineThrough,
                                        ])
                                      : null,
                                  decorationColor: _color,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(2),
                                    borderSide: BorderSide(color: Colors.blue.withAlpha(180), width: 1.5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(2),
                                    borderSide: const BorderSide(color: Color(0xFF2979FF), width: 1.5),
                                  ),
                                  hintText: 'Type here…',
                                  hintStyle: TextStyle(fontSize: scaledSize, color: Colors.black26),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

            // ── Shape picker barrier + flyout ────────────────────────────────
            if (_showShapePanel) ...[
              Positioned(
                left: 64, top: 0, right: 0, bottom: 0,
                child: GestureDetector(
                  onTap: _closeShapePanel,
                  behavior: HitTestBehavior.opaque,
                ),
              ),
              Positioned(
                left: 72,
                top: 0,
                bottom: 0,
                child: Center(
                  child: ShapePickerPanel(
                    onSelect: (type) {
                      _closeShapePanel();
                      _configureAndInsertShape(type);
                    },
                    onDragStarted: _closeShapePanel,
                  ),
                ),
              ),
            ],

            // ── Frame picker barrier + flyout ────────────────────────────────
            if (_showFramePanel) ...[
              Positioned(
                left: 64, top: 0, right: 0, bottom: 0,
                child: GestureDetector(
                  onTap: _closeFramePanel,
                  behavior: HitTestBehavior.opaque,
                ),
              ),
              Positioned(
                left: 72,
                top: 0,
                bottom: 0,
                child: Center(
                  child: FramePickerPanel(
                    onSelect: (type) {
                      _closeFramePanel();
                      _insertFrame(type);
                    },
                    onDragStarted: _closeFramePanel,
                  ),
                ),
              ),
            ],

            // ── Insert panel barrier + flyout ────────────────────────────────
            if (_showInsertPanel) ...[
              Positioned(
                left: 64, top: 0, right: 0, bottom: 0,
                child: GestureDetector(
                  onTap: _closeInsertPanel,
                  behavior: HitTestBehavior.opaque,
                ),
              ),
              Positioned(
                left: 72,
                top: 0,
                bottom: 0,
                child: Center(
                  child: InsertPanel(
                    onImage: () { _closeInsertPanel(); _insertImage(); },
                    onTable: () { _closeInsertPanel(); _insertTable(); },
                    onAttachment: () { _closeInsertPanel(); _insertAttachment(); },
                    onLink: () { _closeInsertPanel(); _insertLink(); },
                    onVideo: () { _closeInsertPanel(); _insertVideo(); },
                    onPrintout: () { _closeInsertPanel(); _insertPrintout(); },
                    onPdf: () { _closeInsertPanel(); _insertPdf(); },
                    onChecklist: () { _closeInsertPanel(); _insertChecklist(); },
                    onLiveTime: () { _closeInsertPanel(); _insertDateTime(DateTimeMode.time, true); },
                    onLiveDate: () { _closeInsertPanel(); _insertDateTime(DateTimeMode.date, true); },
                    onLiveClock: () { _closeInsertPanel(); _insertDateTime(DateTimeMode.datetime, true); },
                    onTimestamp: () { _closeInsertPanel(); _insertDateTime(DateTimeMode.datetime, false); },
                    onDragStarted: _closeInsertPanel,
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

            // ── Sticky note panel barrier + flyout ──────────────────────────
            if (_showStickyNotePanel) ...[
              Positioned(
                left: 64, top: 0, right: 0, bottom: 0,
                child: GestureDetector(
                  onTap: _closeStickyNotePanel,
                  behavior: HitTestBehavior.opaque,
                ),
              ),
              Positioned(
                left: 72,
                top: 0,
                bottom: 0,
                child: Center(child: const StickyNotePickerPanel()),
              ),
            ],

            // ── Drop targets (above panels so barriers don't block them) ────
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
            Positioned.fill(
              child: DragTarget<ShapeType>(
                onAcceptWithDetails: (details) {
                  _placeShape(details.data, details.offset);
                  _closeShapePanel();
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
            Positioned.fill(
              child: DragTarget<FrameType>(
                onAcceptWithDetails: (details) {
                  _placeFrame(details.data, details.offset);
                  _closeFramePanel();
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
            Positioned.fill(
              child: DragTarget<InsertDragType>(
                onAcceptWithDetails: (details) {
                  _placeInsertItem(details.data, details.offset);
                  _closeInsertPanel();
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

            // ── Drag-target for sticky note panel drops ──────────────────────
            Positioned.fill(
              child: DragTarget<StickyNotePickData>(
                onAcceptWithDetails: (details) {
                  final pos = _toCanvas(details.offset);
                  if (details.data.type == StickyNotePickType.single) {
                    _addItem(StickyNoteItem(
                        position: pos, text: '', color: details.data.color));
                  } else {
                    _addItem(StickyNoteStackItem(
                        position: pos, color: details.data.color));
                  }
                  _closeStickyNotePanel();
                },
                builder: (ctx, candidate, rejected) =>
                    const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
