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

class WhiteboardScreen extends StatefulWidget {
  const WhiteboardScreen({super.key});

  @override
  State<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends State<WhiteboardScreen> {
  final _transformationController = TransformationController();
  final List<WhiteboardItem> _items = [];
  final _rulerKey = GlobalKey<_RulerOverlayState>();
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
      builder: (_) => _ExportSheet(
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

  void _showFrameMenu() {
    setState(() {
      _showFramePanel = !_showFramePanel;
      if (_showFramePanel) {
        _showInsertPanel = false;
        _showMathPanel = false;
      }
    });
  }

  void _closeFramePanel() => setState(() => _showFramePanel = false);

  void _showShapeMenu() {
    setState(() {
      _showShapePanel = !_showShapePanel;
      if (_showShapePanel) {
        _showInsertPanel = false;
        _showMathPanel = false;
        _showFramePanel = false;
      }
    });
  }

  void _closeShapePanel() => setState(() => _showShapePanel = false);

  Future<void> _configureAndInsertShape(ShapeType type) async {
    double w = ShapeItem.defaultWidth(type).toDouble();
    double h = ShapeItem.defaultHeight(type).toDouble();
    if (h == 0) h = 8;
    bool filled = false;
    Color fillColor = _color.withAlpha(60);
    bool confirmed = false;

    final fillColors = [
      _color.withAlpha(60),
      Colors.red.withAlpha(60),
      Colors.green.withAlpha(60),
      Colors.blue.withAlpha(60),
      Colors.amber.withAlpha(60),
      Colors.purple.withAlpha(60),
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('Insert ${ShapeItem.labelFor(type)}'),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live preview
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: _shapePreviewSize(type, w, h),
                      painter: _ShapePreviewPainter(
                        type: type,
                        strokeColor: _color,
                        strokeWidth: _strokeWidth,
                        filled: filled,
                        fillColor: fillColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Width
                if (type != ShapeType.line) ...[
                  Row(children: [
                    const SizedBox(
                        width: 54,
                        child: Text('Width',
                            style: TextStyle(fontSize: 13))),
                    Expanded(
                      child: Slider(
                        value: w,
                        min: 50,
                        max: 1200,
                        divisions: 115,
                        onChanged: (v) => set(() => w = v),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text('${w.round()}',
                          style: const TextStyle(fontSize: 13),
                          textAlign: TextAlign.right),
                    ),
                  ]),
                  // Height
                  Row(children: [
                    const SizedBox(
                        width: 54,
                        child: Text('Height',
                            style: TextStyle(fontSize: 13))),
                    Expanded(
                      child: Slider(
                        value: h,
                        min: 50,
                        max: 1200,
                        divisions: 115,
                        onChanged: (v) => set(() => h = v),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text('${h.round()}',
                          style: const TextStyle(fontSize: 13),
                          textAlign: TextAlign.right),
                    ),
                  ]),
                ] else ...[
                  // Line — width only
                  Row(children: [
                    const SizedBox(
                        width: 54,
                        child: Text('Length',
                            style: TextStyle(fontSize: 13))),
                    Expanded(
                      child: Slider(
                        value: w,
                        min: 50,
                        max: 1200,
                        divisions: 115,
                        onChanged: (v) => set(() => w = v),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text('${w.round()}',
                          style: const TextStyle(fontSize: 13),
                          textAlign: TextAlign.right),
                    ),
                  ]),
                ],
                // Fill toggle + colors
                if (type != ShapeType.line) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Text('Fill',
                        style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Switch(
                      value: filled,
                      onChanged: (v) => set(() => filled = v),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                    if (filled) ...[
                      const SizedBox(width: 8),
                      for (final c in fillColors)
                        GestureDetector(
                          onTap: () =>
                              set(() => fillColor = c),
                          child: Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: fillColor == c
                                    ? Colors.blue
                                    : Colors.grey.shade400,
                                width: fillColor == c ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ]),
                ],
              ],
            ),
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
    _addItem(ShapeItem(
      position: center - Offset(w / 2, type == ShapeType.line ? 0 : h / 2),
      shapeType: type,
      width: w,
      height: type == ShapeType.line ? 0 : h,
      strokeColor: _color,
      strokeWidth: _strokeWidth,
      filled: filled,
      fillColor: fillColor,
    ));
  }

  Size _shapePreviewSize(ShapeType type, double w, double h) {
    const maxW = 140.0;
    const maxH = 72.0;
    if (type == ShapeType.line) return const Size(maxW, 2);
    final scaleW = w > maxW ? maxW / w : 1.0;
    final scaleH = h > maxH ? maxH / h : 1.0;
    final scale = scaleW < scaleH ? scaleW : scaleH;
    return Size((w * scale).clamp(20, maxW), (h * scale).clamp(10, maxH));
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

    List<bool> selected = List.filled(pageCount, true);
    bool confirmed = false;

    if (pageCount > 1) {
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => AlertDialog(
            title: const Text('Import PDF Pages'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: SizedBox(
              width: 280,
              height: math.min(pageCount * 44.0 + 60, 320),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$pageCount pages — select which to import:',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: pageCount,
                      itemBuilder: (_, i) => CheckboxListTile(
                        dense: true,
                        title: Text('Page ${i + 1}'),
                        value: selected[i],
                        onChanged: (v) => set(() => selected[i] = v ?? false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => set(() => selected = List.filled(pageCount, true)),
                child: const Text('All'),
              ),
              FilledButton(
                onPressed: () {
                  confirmed = true;
                  Navigator.pop(ctx);
                },
                child: const Text('Import'),
              ),
            ],
          ),
        ),
      );
    } else {
      confirmed = true;
    }

    if (!confirmed) {
      await document.dispose();
      return;
    }

    final pagesToImport = [
      for (int i = 0; i < selected.length; i++)
        if (selected[i]) i,
    ];

    if (pagesToImport.isEmpty) {
      await document.dispose();
      return;
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
              item is DateTimeItem)
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
      final ChecklistItem i => _ChecklistCard(
          item: i,
          onUpdate: (updated) {
            setState(() => _items[index] = updated);
            _scheduleAutosave();
          },
        ),
      final DateTimeItem i => _DateTimeCard(item: i),
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
      _handleSelectDown(_downCanvasPos!);
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
      _handleSelectMove(_toCanvas(event.position));
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
    } else if (_tool == DrawingTool.stickyNote) {
      await _showStickyNoteDialog(canvasPos);
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
              child: _RulerOverlay(key: _rulerKey),
            ),

            // ── BORD logo — top left ────────────────────────────────────────
            Positioned(
              top: pad.top + 12,
              left: 16,
              child: _BordLogo(
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
              child: _ShareButton(onTap: _showShareSheet),
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
                  mathPanelOpen: _showMathPanel,
                  framePanelOpen: _showFramePanel,
                  shapePanelOpen: _showShapePanel,
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
                    onInsertEquation: (eq) {
                      _closeMathPanel();
                      _insertEquationText(eq);
                    },
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
                  child: _TextFormatPanel(
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
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeShapePanel,
                  behavior: HitTestBehavior.translucent,
                ),
              ),
              Positioned(
                left: 72,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _ShapePickerPanel(
                    onSelect: (type) {
                      _closeShapePanel();
                      _configureAndInsertShape(type);
                    },
                  ),
                ),
              ),
            ],

            // ── Frame picker barrier + flyout ────────────────────────────────
            if (_showFramePanel) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeFramePanel,
                  behavior: HitTestBehavior.translucent,
                ),
              ),
              Positioned(
                left: 72,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _FramePickerPanel(
                    onSelect: (type) {
                      _closeFramePanel();
                      _insertFrame(type);
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
                    onPdf: () { _closeInsertPanel(); _insertPdf(); },
                    onChecklist: () { _closeInsertPanel(); _insertChecklist(); },
                    onLiveTime: () { _closeInsertPanel(); _insertDateTime(DateTimeMode.time, true); },
                    onLiveDate: () { _closeInsertPanel(); _insertDateTime(DateTimeMode.date, true); },
                    onLiveClock: () { _closeInsertPanel(); _insertDateTime(DateTimeMode.datetime, true); },
                    onTimestamp: () { _closeInsertPanel(); _insertDateTime(DateTimeMode.datetime, false); },
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

// ── Ruler overlay ────────────────────────────────────────────────────────────

enum _RulerDragMode { body, leftHandle, rightHandle }

enum _RulerUnit { mm, cm, inches }

class _RulerData {
  Offset center;
  double angle;
  double length;
  _RulerUnit unit;
  Color color;

  _RulerData({
    required this.center,
    this.angle = 0.0,
    this.length = 320.0,
    this.unit = _RulerUnit.cm,
    this.color = const Color(0xFFF5ECC2),
  });
}

class _RulerOverlay extends StatefulWidget {
  const _RulerOverlay({super.key});

  @override
  State<_RulerOverlay> createState() => _RulerOverlayState();
}

class _RulerOverlayState extends State<_RulerOverlay> {
  final List<_RulerData> _rulers = [];
  _RulerDragMode? _dragMode;
  int? _activeIdx;

  static const double _rulerH = 40.0;
  static const double _handleR = 13.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rulers.isEmpty) {
      final s = MediaQuery.of(context).size;
      _rulers.add(_RulerData(center: Offset(s.width / 2, s.height / 2)));
    }
  }

  void addRuler() {
    final s = MediaQuery.of(context).size;
    setState(() {
      _rulers.add(_RulerData(
        center: Offset(
          s.width / 2 + _rulers.length * 24,
          s.height / 2 + _rulers.length * 24,
        ),
      ));
    });
  }

  void clearRulers() => setState(() => _rulers.clear());

  Offset _leftEnd(_RulerData r) {
    final c = math.cos(r.angle), s = math.sin(r.angle);
    return Offset(r.center.dx - c * r.length / 2, r.center.dy - s * r.length / 2);
  }

  Offset _rightEnd(_RulerData r) {
    final c = math.cos(r.angle), s = math.sin(r.angle);
    return Offset(r.center.dx + c * r.length / 2, r.center.dy + s * r.length / 2);
  }

  bool _hitBody(Offset p, _RulerData r) {
    final cosA = math.cos(r.angle), sinA = math.sin(r.angle);
    final dx = p.dx - r.center.dx, dy = p.dy - r.center.dy;
    return (dx * cosA + dy * sinA).abs() <= r.length / 2 &&
        (-dx * sinA + dy * cosA).abs() <= _rulerH / 2 + 6;
  }

  bool _hitUnitBadge(Offset p, _RulerData r) {
    final cosA = math.cos(r.angle), sinA = math.sin(r.angle);
    final dx = p.dx - r.center.dx, dy = p.dy - r.center.dy;
    final localX = dx * cosA + dy * sinA;
    final localY = -dx * sinA + dy * cosA;
    return localX.abs() <= 14 && (localY - 12).abs() <= 7;
  }

  void _onPanStart(DragStartDetails d) {
    final p = d.localPosition;
    for (int i = _rulers.length - 1; i >= 0; i--) {
      final r = _rulers[i];
      if ((p - _leftEnd(r)).distance <= _handleR * 2.2) {
        setState(() { _activeIdx = i; _dragMode = _RulerDragMode.leftHandle; });
        return;
      }
      if ((p - _rightEnd(r)).distance <= _handleR * 2.2) {
        setState(() { _activeIdx = i; _dragMode = _RulerDragMode.rightHandle; });
        return;
      }
      if (_hitBody(p, r)) {
        setState(() { _activeIdx = i; _dragMode = _RulerDragMode.body; });
        return;
      }
    }
    _activeIdx = null;
    _dragMode = null;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragMode == null || _activeIdx == null) return;
    final delta = d.delta;
    final r = _rulers[_activeIdx!];
    setState(() {
      switch (_dragMode!) {
        case _RulerDragMode.body:
          r.center = r.center + delta;
        case _RulerDragMode.leftHandle:
          final nl = _leftEnd(r) + delta;
          final fr = _rightEnd(r);
          final v = fr - nl;
          final len = v.distance;
          if (len >= 60) {
            r.center = (nl + fr) / 2;
            r.angle = math.atan2(v.dy, v.dx);
            r.length = len;
          }
        case _RulerDragMode.rightHandle:
          final fl = _leftEnd(r);
          final nr = _rightEnd(r) + delta;
          final v = nr - fl;
          final len = v.distance;
          if (len >= 60) {
            r.center = (fl + nr) / 2;
            r.angle = math.atan2(v.dy, v.dx);
            r.length = len;
          }
      }
    });
  }

  void _showRulerContextMenu(BuildContext context, Offset globalPos, _RulerData r) {
    final screenSize = MediaQuery.of(context).size;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx, globalPos.dy,
        screenSize.width - globalPos.dx,
        screenSize.height - globalPos.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      color: Colors.white,
      items: [
        for (final unit in _RulerUnit.values)
          PopupMenuItem(
            value: 'unit_${unit.name}',
            child: Row(children: [
              SizedBox(
                width: 16,
                child: r.unit == unit
                    ? const Icon(Icons.check, size: 14, color: Colors.blue)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(switch (unit) {
                _RulerUnit.mm => 'mm',
                _RulerUnit.cm => 'cm',
                _RulerUnit.inches => 'inches',
              }),
            ]),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'color',
          child: Row(children: [
            Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: r.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Change Color'),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
            SizedBox(width: 10),
            Text('Delete Ruler', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
    ).then((value) {
      if (!mounted) return;
      if (value == null) return;
      if (value.startsWith('unit_')) {
        final unitName = value.substring(5);
        setState(() {
          r.unit = _RulerUnit.values.firstWhere((u) => u.name == unitName);
        });
      } else if (value == 'color') {
        _showColorPicker(context, r);
      } else if (value == 'delete') {
        setState(() => _rulers.remove(r));
      }
    });
  }

  void _showColorPicker(BuildContext context, _RulerData r) {
    const colors = [
      Color(0xFFF5ECC2), Color(0xFFCCE5FF), Color(0xFFCCF0CC),
      Color(0xFFFFCCCC), Color(0xFFFFE0B2), Color(0xFFF8F8F8),
      Color(0xFF8B6914), Color(0xFF1A3A5C),
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ruler Color',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: colors.map((c) => GestureDetector(
                  onTap: () {
                    setState(() => r.color = c);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: r.color == c ? Colors.blue : Colors.grey.shade300,
                        width: r.color == c ? 2.5 : 1,
                      ),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (d) {
          for (final r in _rulers) {
            if (_hitUnitBadge(d.localPosition, r)) {
              setState(() {
                r.unit = _RulerUnit.values[(r.unit.index + 1) % _RulerUnit.values.length];
              });
              return;
            }
          }
          for (final r in _rulers) {
            if (_hitBody(d.localPosition, r)) {
              _showRulerContextMenu(context, d.globalPosition, r);
              return;
            }
          }
        },
        onLongPressStart: (d) {
          for (final r in _rulers) {
            if (_hitBody(d.localPosition, r)) {
              _showRulerContextMenu(context, d.globalPosition, r);
              return;
            }
          }
        },
        onSecondaryTapUp: (d) {
          for (final r in _rulers) {
            if (_hitBody(d.localPosition, r)) {
              _showRulerContextMenu(context, d.globalPosition, r);
              return;
            }
          }
        },
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: (_) => setState(() { _dragMode = null; _activeIdx = null; }),
        onPanCancel: () => setState(() { _dragMode = null; _activeIdx = null; }),
        child: CustomPaint(
          painter: _RulerPainter(
            rulers: _rulers,
            rulerH: _rulerH,
            handleR: _handleR,
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final List<_RulerData> rulers;
  final double rulerH;
  final double handleR;

  const _RulerPainter({
    required this.rulers,
    required this.rulerH,
    required this.handleR,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in rulers) { _paintBody(canvas, r); }
    for (final r in rulers) { _paintHandles(canvas, r); }
  }

  void _paintBody(Canvas canvas, _RulerData r) {
    final halfLen = r.length / 2;
    final halfH = rulerH / 2;

    canvas.save();
    canvas.translate(r.center.dx, r.center.dy);
    canvas.rotate(r.angle);

    final bodyRect = Rect.fromLTRB(-halfLen, -halfH, halfLen, halfH);
    final rr = RRect.fromRectXY(bodyRect, 5, 5);

    canvas.drawRRect(rr.shift(const Offset(0, 2)),
        Paint()..color = const Color(0x35000000));
    canvas.drawRRect(rr, Paint()..color = r.color);
    canvas.drawRRect(
      RRect.fromRectXY(
          Rect.fromLTRB(-halfLen + 2, -halfH + 2, halfLen - 2, -halfH + 7), 3, 3),
      Paint()..color = const Color(0x55FFFFFF),
    );
    canvas.drawRRect(
        rr,
        Paint()
          ..color = const Color(0xFFB59A2A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // Tick marks (assumes 96 logical px per inch)
    const double ppi = 96.0;
    const double ppmm = ppi / 25.4;
    final double tinyPx;
    final int midMult, majorMult;
    final String unitName;
    switch (r.unit) {
      case _RulerUnit.mm:
        tinyPx = ppmm; midMult = 5; majorMult = 10; unitName = 'mm';
      case _RulerUnit.cm:
        tinyPx = ppmm; midMult = 5; majorMult = 10; unitName = 'cm';
      case _RulerUnit.inches:
        tinyPx = ppi / 16; midMult = 4; majorMult = 16; unitName = 'in';
    }

    final n = (r.length / tinyPx).ceil();
    final tickPaint = Paint()..strokeCap = StrokeCap.butt;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= n; i++) {
      final xFromLeft = i * tinyPx;
      if (xFromLeft > r.length) break;
      final x = xFromLeft - halfLen;
      final isMajor = i % majorMult == 0;
      final isMid = !isMajor && i % midMult == 0;
      final tH = isMajor ? halfH * 0.60 : isMid ? halfH * 0.40 : halfH * 0.22;
      final sw = isMajor ? 1.5 : isMid ? 1.0 : 0.7;
      tickPaint..color = const Color(0xFF7A5500)..strokeWidth = sw;
      canvas.drawLine(Offset(x, -halfH + 2), Offset(x, -halfH + 2 + tH), tickPaint);

      if (isMajor && i > 0 && x.abs() < halfLen - 6) {
        final majorIdx = i ~/ majorMult;
        tp.text = TextSpan(
          text: r.unit == _RulerUnit.mm ? '${majorIdx * 10}' : '$majorIdx',
          style: const TextStyle(color: Color(0xFF5C3D00), fontSize: 8, fontWeight: FontWeight.w600),
        );
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, -halfH + 2 + halfH * 0.60 + 1));
      }
    }

    // Unit badge
    canvas.drawRRect(
      RRect.fromRectXY(
          Rect.fromCenter(center: const Offset(0, 12), width: 26, height: 11), 5.5, 5.5),
      Paint()..color = const Color(0xFFDDD0A0),
    );
    final badgeTp = TextPainter(textDirection: TextDirection.ltr);
    badgeTp.text = TextSpan(
      text: unitName,
      style: const TextStyle(color: Color(0xFF5C3D00), fontSize: 9, fontWeight: FontWeight.w700),
    );
    badgeTp.layout();
    badgeTp.paint(canvas, Offset(-badgeTp.width / 2, 12 - badgeTp.height / 2));

    canvas.restore();
  }

  void _paintHandles(Canvas canvas, _RulerData r) {
    final cosA = math.cos(r.angle), sinA = math.sin(r.angle);
    final halfLen = r.length / 2;
    for (final pt in [
      Offset(r.center.dx - cosA * halfLen, r.center.dy - sinA * halfLen),
      Offset(r.center.dx + cosA * halfLen, r.center.dy + sinA * halfLen),
    ]) {
      canvas.drawCircle(pt + const Offset(0, 1), handleR + 1,
          Paint()..color = const Color(0x40000000));
      canvas.drawCircle(pt, handleR, Paint()..color = const Color(0xFF2979FF));
      canvas.drawCircle(pt, handleR,
          Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0);
      canvas.drawLine(Offset(pt.dx - 4, pt.dy), Offset(pt.dx + 4, pt.dy),
          Paint()..color = Colors.white..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────

class _BordLogo extends StatelessWidget {
  final VoidCallback onNew;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final bool autosaveEnabled;
  final VoidCallback onToggleAutosave;

  const _BordLogo({
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

class _ShareButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _ShareButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ios_share_rounded, size: 16, color: Colors.white),
            SizedBox(width: 6),
            Text('Share',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ── Export / share sheet ───────────────────────────────────────────────────

class _ExportSheet extends StatelessWidget {
  final VoidCallback onSavePng;
  final VoidCallback onSavePdf;
  final VoidCallback onShare;
  const _ExportSheet(
      {required this.onSavePng,
      required this.onSavePdf,
      required this.onShare});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Export board',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const Divider(height: 20),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Save as PNG'),
              subtitle: const Text('High-resolution image file'),
              onTap: onSavePng,
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Save as PDF'),
              subtitle: const Text('A4 landscape document'),
              onTap: onSavePdf,
            ),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Share via…'),
              subtitle: const Text('Open system share sheet'),
              onTap: onShare,
            ),
          ],
        ),
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
  final VoidCallback onPdf;
  final VoidCallback onChecklist;
  final VoidCallback onLiveTime;
  final VoidCallback onLiveDate;
  final VoidCallback onLiveClock;
  final VoidCallback onTimestamp;
  final VoidCallback onGenerate;

  const _InsertPanel({
    required this.onImage,
    required this.onTable,
    required this.onAttachment,
    required this.onLink,
    required this.onVideo,
    required this.onPrintout,
    required this.onPdf,
    required this.onChecklist,
    required this.onLiveTime,
    required this.onLiveDate,
    required this.onLiveClock,
    required this.onTimestamp,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final mediaOptions = [
      (Icons.image_outlined, 'Picture', const Color(0xFF43A047), onImage),
      (Icons.table_chart_outlined, 'Table', const Color(0xFF1E88E5), onTable),
      (Icons.attach_file_rounded, 'File', const Color(0xFFFB8C00), onAttachment),
      (Icons.link_rounded, 'Link', const Color(0xFF5E35B1), onLink),
      (Icons.play_circle_outline_rounded, 'Video', const Color(0xFFE53935), onVideo),
      (Icons.description_outlined, 'Doc', const Color(0xFFEF6C00), onPrintout),
      (Icons.picture_as_pdf_rounded, 'PDF', const Color(0xFFD32F2F), onPdf),
    ];

    final widgetOptions = [
      (Icons.checklist_rounded, 'Checklist', const Color(0xFF7C3AED), onChecklist),
      (Icons.schedule_rounded, 'Live Time', const Color(0xFF0097A7), onLiveTime),
      (Icons.calendar_today_rounded, 'Live Date', const Color(0xFF00897B), onLiveDate),
      (Icons.watch_later_rounded, 'Live Clock', const Color(0xFF1E88E5), onLiveClock),
      (Icons.push_pin_rounded, 'Timestamp', const Color(0xFF6D4C41), onTimestamp),
    ];

    Widget sectionGrid(List<(IconData, String, Color, VoidCallback)> opts) =>
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
          children: [
            for (final (icon, label, color, onTap) in opts)
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(color.withAlpha(38), Colors.white),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 24, color: color),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text('Media',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500, letterSpacing: 0.8)),
          ),
          sectionGrid(mediaOptions),
          const SizedBox(height: 10),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text('Widgets',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500, letterSpacing: 0.8)),
          ),
          sectionGrid(widgetOptions),
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
                    Icon(Icons.auto_awesome_rounded, size: 15, color: Colors.white),
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

class _MathPanel extends StatefulWidget {
  final void Function(MathGraphType) onInsert;
  final void Function(String) onInsertEquation;
  const _MathPanel({required this.onInsert, required this.onInsertEquation});

  @override
  State<_MathPanel> createState() => _MathPanelState();
}

class _MathPanelState extends State<_MathPanel> {
  int _tab = 0;

  static const _graphItems = [
    (MathGraphType.xyGraph, 'XY Graph', Icons.grid_on_rounded, Color(0xFF1565C0)),
    (MathGraphType.xyzGraph, '3D Graph', Icons.view_in_ar_rounded, Color(0xFF6A1B9A)),
    (MathGraphType.numberLine, 'Number Line', Icons.horizontal_rule_rounded, Color(0xFF00838F)),
    (MathGraphType.unitCircle, 'Unit Circle', Icons.radio_button_unchecked_rounded, Color(0xFF2E7D32)),
    (MathGraphType.polarGraph, 'Polar', Icons.blur_circular_rounded, Color(0xFF4527A0)),
    (MathGraphType.vennDiagram, 'Venn', Icons.workspaces_outlined, Color(0xFFBF360C)),
  ];

  static const _mathEquations = [
    ('Quadratic Formula',       'x = (−b ± √(b²−4ac)) / 2a'),
    ('Pythagorean Theorem',     'a² + b² = c²'),
    ('Distance Formula',        'd = √((x₂−x₁)² + (y₂−y₁)²)'),
    ('Slope',                   'm = (y₂−y₁) / (x₂−x₁)'),
    ('Circle Area',             'A = πr²'),
    ('Circumference',           'C = 2πr'),
    ("Euler's Identity",        'eⁱᵖ + 1 = 0'),
    ('Log Change of Base',      'logᵦ(x) = ln(x) / ln(b)'),
    ('Law of Cosines',          'c² = a² + b² − 2ab·cos(C)'),
    ('Sine Rule',               'a/sin(A) = b/sin(B) = c/sin(C)'),
    ('Arithmetic Series',       'Sₙ = n/2 · (a₁ + aₙ)'),
    ('Geometric Series',        'Sₙ = a(1−rⁿ) / (1−r)'),
    ('Compound Interest',       'A = P(1 + r/n)ⁿᵗ'),
    ('Point-Slope Form',        'y − y₁ = m(x − x₁)'),
    ('Standard Ellipse',        'x²/a² + y²/b² = 1'),
  ];

  static const _physicsEquations = [
    ("Newton's 2nd Law",        'F = ma'),
    ('Mass–Energy',             'E = mc²'),
    ('Velocity (kinematics)',   'v = v₀ + at'),
    ('Displacement',            'd = v₀t + ½at²'),
    ('Work',                    'W = F·d·cos(θ)'),
    ('Momentum',                'p = mv'),
    ('Kinetic Energy',          'KE = ½mv²'),
    ('Gravitational PE',        'PE = mgh'),
    ("Ohm's Law",               'V = IR'),
    ('Power',                   'P = IV = I²R = V²/R'),
    ("Coulomb's Law",           'F = kq₁q₂ / r²'),
    ('Gravitation',             'F = Gm₁m₂ / r²'),
    ('Ideal Gas Law',           'PV = nRT'),
    ('Wave Speed',              'v = fλ'),
    ("Snell's Law",             'n₁ sin(θ₁) = n₂ sin(θ₂)'),
    ('Centripetal Force',       'Fc = mv² / r'),
    ('Period of Pendulum',      'T = 2π√(L/g)'),
    ('Pressure',                'P = F / A'),
  ];

  // (label shown below symbol, symbol inserted as text, tooltip)
  static const _symbols = [
    // Constants
    ('π',   'π',       'Pi'),
    ('e',   'e',       "Euler's number"),
    ('φ',   'φ',       'Golden ratio'),
    ('τ',   'τ',       'Tau (2π)'),
    ('∞',   '∞',       'Infinity'),
    ('√',   '√',       'Square root'),
    // Calculus — integrals
    ('∫',   '∫',       'Integral'),
    ('∬',   '∬',       'Double integral'),
    ('∭',   '∭',       'Triple integral'),
    ('∮',   '∮',       'Contour integral'),
    // Calculus — derivatives
    ('d/dx',  'd/dx',    'Derivative'),
    ('d²/dx²','d²/dx²',  'Second derivative'),
    ('∂/∂x',  '∂/∂x',    'Partial derivative'),
    ('∇',   '∇',       'Del / Nabla'),
    // Summation / product
    ('Σ',   'Σ',       'Summation'),
    ('Π',   'Π',       'Product'),
    // Operators
    ('±',   '±',       'Plus-minus'),
    ('×',   '×',       'Multiply'),
    ('÷',   '÷',       'Divide'),
    ('≈',   '≈',       'Approximately'),
    ('≠',   '≠',       'Not equal'),
    ('≤',   '≤',       'Less or equal'),
    ('≥',   '≥',       'Greater or equal'),
    ('∝',   '∝',       'Proportional'),
    // Greek letters
    ('α',   'α',       'Alpha'),
    ('β',   'β',       'Beta'),
    ('γ',   'γ',       'Gamma'),
    ('δ',   'δ',       'Delta'),
    ('ε',   'ε',       'Epsilon'),
    ('θ',   'θ',       'Theta'),
    ('λ',   'λ',       'Lambda'),
    ('μ',   'μ',       'Mu'),
    ('σ',   'σ',       'Sigma'),
    ('ω',   'ω',       'Omega'),
    ('Δ',   'Δ',       'Delta (upper)'),
    ('Ω',   'Ω',       'Omega (upper)'),
    // Set theory
    ('∈',   '∈',       'Element of'),
    ('∉',   '∉',       'Not element of'),
    ('⊂',   '⊂',       'Subset'),
    ('∪',   '∪',       'Union'),
    ('∩',   '∩',       'Intersection'),
    ('∀',   '∀',       'For all'),
    ('∃',   '∃',       'There exists'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 272,
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
          // Tab bar
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTabBtn(0, 'Graphs'),
              _buildTabBtn(1, 'Math'),
              _buildTabBtn(2, 'Physics'),
              _buildTabBtn(3, 'Symbols'),
            ],
          ),
          const SizedBox(height: 10),
          // Content
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              child: switch (_tab) {
                0 => _buildGraphsTab(),
                3 => _buildSymbolsTab(),
                _ => _buildEquationsTab(
                    _tab == 1 ? _mathEquations : _physicsEquations),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBtn(int idx, String label) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1565C0) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildGraphsTab() {
    return Column(
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
            for (final (type, label, icon, color) in _graphItems)
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
                  onTap: () => widget.onInsert(type),
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
    );
  }

  Widget _buildEquationsTab(List<(String, String)> equations) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < equations.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
          InkWell(
            onTap: () => widget.onInsertEquation(equations[i].$2),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          equations[i].$1,
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          equations[i].$2,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.add_circle_outline,
                      size: 16, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSymbolsTab() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (label, sym, tip) in _symbols)
          Tooltip(
            message: tip,
            child: InkWell(
              onTap: () => widget.onInsertEquation(sym),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
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

// ── Text format panel ──────────────────────────────────────────────────────

class _TextFormatPanel extends StatelessWidget {
  final double fontSize;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final String fontFamily;
  final Color color;
  final TextAlign textAlign;
  final int indentLevel;
  final bool bullet;
  final double lineHeight;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<bool> onBoldChanged;
  final ValueChanged<bool> onItalicChanged;
  final ValueChanged<bool> onUnderlineChanged;
  final ValueChanged<bool> onStrikethroughChanged;
  final ValueChanged<String> onFontFamilyChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<TextAlign> onAlignChanged;
  final ValueChanged<int> onIndentChanged;
  final ValueChanged<bool> onBulletChanged;
  final ValueChanged<double> onLineHeightChanged;
  final VoidCallback onClearFormatting;

  const _TextFormatPanel({
    required this.fontSize,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strikethrough,
    required this.fontFamily,
    required this.color,
    required this.textAlign,
    required this.indentLevel,
    required this.bullet,
    required this.lineHeight,
    required this.onFontSizeChanged,
    required this.onBoldChanged,
    required this.onItalicChanged,
    required this.onUnderlineChanged,
    required this.onStrikethroughChanged,
    required this.onFontFamilyChanged,
    required this.onColorChanged,
    required this.onAlignChanged,
    required this.onIndentChanged,
    required this.onBulletChanged,
    required this.onLineHeightChanged,
    required this.onClearFormatting,
  });

  static const _fonts = [
    ('System', ''),
    ('Arial', 'Arial'),
    ('Calibri', 'Calibri'),
    ('Courier New', 'Courier New'),
    ('Georgia', 'Georgia'),
    ('Times New Roman', 'Times New Roman'),
    ('Verdana', 'Verdana'),
  ];

  static const _quickColors = [
    Color(0xFF000000),
    Color(0xFFE53935),
    Color(0xFF1E88E5),
  ];

  static const _paletteColors = [
    Color(0xFF000000), Color(0xFF424242), Color(0xFF757575), Color(0xFFBDBDBD), Color(0xFFFFFFFF),
    Color(0xFF8B0000), Color(0xFFE53935), Color(0xFFFF5252), Color(0xFFEC407A), Color(0xFFF48FB1),
    Color(0xFFE65100), Color(0xFFF57C00), Color(0xFFFFD600), Color(0xFFFFEE58), Color(0xFFFFF9C4),
    Color(0xFF1B5E20), Color(0xFF43A047), Color(0xFF26A69A), Color(0xFF00BCD4), Color(0xFFB3E5FC),
    Color(0xFF0D47A1), Color(0xFF1E88E5), Color(0xFF3F51B5), Color(0xFF7B1FA2), Color(0xFFEA80FC),
  ];

  String get _styleLabel {
    if (fontSize >= 48) return 'Title';
    if (fontSize >= 32) return 'Heading 1';
    if (fontSize >= 24) return 'Heading 2';
    if (fontSize >= 18) return 'Heading 3';
    return 'Normal';
  }

  String get _fontLabel => fontFamily.isEmpty ? 'System' : fontFamily;

  IconData get _alignIcon => switch (textAlign) {
        TextAlign.center => Icons.format_align_center,
        TextAlign.right => Icons.format_align_right,
        TextAlign.justify => Icons.format_align_justify,
        _ => Icons.format_align_left,
      };

  void _openPalette(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Text Color',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _paletteColors
                    .map((c) => GestureDetector(
                          onTap: () {
                            onColorChanged(c);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == c
                                    ? Colors.blue
                                    : Colors.grey.shade300,
                                width: color == c ? 2.5 : 1,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(28),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRow1(context),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
            _buildRow2(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRow1(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Style dropdown
        _PillDropdown<double>(
          label: _styleLabel,
          items: const [
            PopupMenuItem(value: 56.0, child: Text('Title', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
            PopupMenuItem(value: 36.0, child: Text('Heading 1', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            PopupMenuItem(value: 28.0, child: Text('Heading 2', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            PopupMenuItem(value: 22.0, child: Text('Heading 3', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
            PopupMenuItem(value: 16.0, child: Text('Normal', style: TextStyle(fontSize: 14))),
          ],
          onSelected: onFontSizeChanged,
        ),
        _divider(),
        // Size stepper
        _SizeStepper(fontSize: fontSize, onChanged: onFontSizeChanged),
        _divider(),
        // B I U S̶
        _FmtToggle(icon: Icons.format_bold, tooltip: 'Bold', active: bold, onTap: () => onBoldChanged(!bold)),
        _FmtToggle(icon: Icons.format_italic, tooltip: 'Italic', active: italic, onTap: () => onItalicChanged(!italic)),
        _FmtToggle(icon: Icons.format_underline, tooltip: 'Underline', active: underline, onTap: () => onUnderlineChanged(!underline)),
        _FmtToggle(icon: Icons.format_strikethrough, tooltip: 'Strikethrough', active: strikethrough, onTap: () => onStrikethroughChanged(!strikethrough)),
        _divider(),
        // Superscript/Subscript (placeholder)
        _FmtBtn(icon: Icons.superscript, tooltip: 'Superscript / Subscript'),
        // Link (placeholder)
        _FmtBtn(icon: Icons.link, tooltip: 'Link'),
        // Clear formatting
        _FmtToggle(icon: Icons.format_clear, tooltip: 'Clear Formatting', active: false, onTap: onClearFormatting),
        // Copy format (placeholder)
        _FmtBtn(icon: Icons.format_paint, tooltip: 'Copy Format'),
        // Cut (placeholder)
        _FmtBtn(icon: Icons.content_cut, tooltip: 'Cut'),
      ],
    );
  }

  Widget _buildRow2(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Font dropdown
        _PillDropdown<String>(
          label: _fontLabel,
          items: [
            for (final (name, family) in _fonts)
              PopupMenuItem(
                value: family,
                child: Text(name,
                    style: TextStyle(
                        fontFamily: family.isEmpty ? null : family,
                        fontSize: 14)),
              ),
          ],
          onSelected: onFontFamilyChanged,
        ),
        _divider(),
        // Quick color swatches
        for (final c in _quickColors)
          GestureDetector(
            onTap: () => onColorChanged(c),
            child: Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: color == c ? Colors.blue : Colors.grey.shade300,
                  width: color == c ? 2.5 : 1.5,
                ),
              ),
            ),
          ),
        // Color wheel
        Tooltip(
          message: 'More colors',
          child: InkWell(
            onTap: () => _openPalette(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                gradient: const SweepGradient(colors: [
                  Colors.red, Colors.orange, Colors.yellow,
                  Colors.green, Colors.blue, Colors.purple, Colors.red,
                ]),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
            ),
          ),
        ),
        // Highlighter (placeholder)
        _FmtBtn(icon: Icons.highlight, tooltip: 'Highlight'),
        _divider(),
        // Indent decrease / increase
        _FmtToggle(
          icon: Icons.format_indent_decrease,
          tooltip: 'Decrease Indent',
          active: false,
          onTap: indentLevel > 0 ? () => onIndentChanged(indentLevel - 1) : () {},
        ),
        _FmtToggle(
          icon: Icons.format_indent_increase,
          tooltip: 'Increase Indent',
          active: false,
          onTap: () => onIndentChanged(indentLevel + 1),
        ),
        _divider(),
        // Alignment dropdown
        PopupMenuButton<TextAlign>(
          tooltip: 'Alignment',
          padding: EdgeInsets.zero,
          icon: Icon(_alignIcon, size: 18, color: Colors.black87),
          onSelected: onAlignChanged,
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: TextAlign.left, child: Row(children: [Icon(Icons.format_align_left, size: 18), SizedBox(width: 8), Text('Left')])),
            PopupMenuItem(value: TextAlign.center, child: Row(children: [Icon(Icons.format_align_center, size: 18), SizedBox(width: 8), Text('Center')])),
            PopupMenuItem(value: TextAlign.right, child: Row(children: [Icon(Icons.format_align_right, size: 18), SizedBox(width: 8), Text('Right')])),
            PopupMenuItem(value: TextAlign.justify, child: Row(children: [Icon(Icons.format_align_justify, size: 18), SizedBox(width: 8), Text('Justify')])),
          ],
        ),
        // Bullet toggle
        _FmtToggle(
          icon: Icons.format_list_bulleted,
          tooltip: 'Bullet List',
          active: bullet,
          onTap: () => onBulletChanged(!bullet),
        ),
        // Line height popup
        PopupMenuButton<double>(
          tooltip: 'Line Height',
          padding: EdgeInsets.zero,
          icon: Icon(Icons.format_line_spacing, size: 18,
              color: lineHeight != 1.2 ? Colors.blue : Colors.black87),
          onSelected: onLineHeightChanged,
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 1.0, child: Text('Single (1.0)')),
            PopupMenuItem(value: 1.2, child: Text('Default (1.2)')),
            PopupMenuItem(value: 1.5, child: Text('1.5')),
            PopupMenuItem(value: 1.8, child: Text('1.8')),
            PopupMenuItem(value: 2.0, child: Text('Double (2.0)')),
          ],
        ),
        _divider(),
        // Copy / Paste (placeholders)
        _FmtBtn(icon: Icons.copy, tooltip: 'Copy'),
        _FmtBtn(icon: Icons.paste, tooltip: 'Paste'),
      ],
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(height: 22, child: VerticalDivider(width: 1, thickness: 1)),
      );
}

// Pill-shaped dropdown button
class _PillDropdown<T> extends StatelessWidget {
  final String label;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  const _PillDropdown({
    required this.label,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (_) => items,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 14, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

// Size stepper: [−] [14] [+] with tappable/editable number
class _SizeStepper extends StatefulWidget {
  final double fontSize;
  final ValueChanged<double> onChanged;

  const _SizeStepper({required this.fontSize, required this.onChanged});

  @override
  State<_SizeStepper> createState() => _SizeStepperState();
}

class _SizeStepperState extends State<_SizeStepper> {
  bool _editing = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.fontSize.toInt().toString());
  }

  @override
  void didUpdateWidget(_SizeStepper old) {
    super.didUpdateWidget(old);
    if (!_editing) _ctrl.text = widget.fontSize.toInt().toString();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _commit() {
    final v = double.tryParse(_ctrl.text);
    if (v != null) {
      widget.onChanged(v.clamp(8.0, 144.0));
    } else {
      _ctrl.text = widget.fontSize.toInt().toString();
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(
          icon: Icons.remove,
          onTap: widget.fontSize > 8
              ? () => widget.onChanged((widget.fontSize - 1).clamp(8.0, 144.0))
              : null,
        ),
        if (_editing)
          SizedBox(
            width: 34,
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 3),
                border: UnderlineInputBorder(),
              ),
              onSubmitted: (_) => _commit(),
              onEditingComplete: _commit,
            ),
          )
        else
          GestureDetector(
            onTap: () {
              _ctrl.text = widget.fontSize.toInt().toString();
              setState(() => _editing = true);
            },
            child: Container(
              width: 34,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.fontSize.toInt().toString(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        _StepBtn(
          icon: Icons.add,
          onTap: widget.fontSize < 144
              ? () => widget.onChanged((widget.fontSize + 1).clamp(8.0, 144.0))
              : null,
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        child: Icon(icon, size: 14,
            color: onTap != null ? Colors.black87 : Colors.black26),
      ),
    );
  }
}

class _FmtToggle extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  const _FmtToggle({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: active ? Colors.blue.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18,
              color: active ? Colors.blue : Colors.black87),
        ),
      ),
    );
  }
}

// Placeholder toolbar button (disabled appearance)
class _FmtBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;

  const _FmtBtn({required this.icon, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: Colors.black38),
      ),
    );
  }
}

// ── Frame picker panel ─────────────────────────────────────────────────────

class _FramePickerPanel extends StatelessWidget {
  final void Function(FrameType) onSelect;
  const _FramePickerPanel({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 272,
      constraints: const BoxConstraints(maxHeight: 580),
      padding: const EdgeInsets.all(14),
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('Standard', const [
              FrameType.a4Portrait,
              FrameType.letter,
              FrameType.ratio16x9,
              FrameType.ratio4x3,
              FrameType.ratio1x1,
            ]),
            const SizedBox(height: 10),
            _section('Devices', const [
              FrameType.mobile,
              FrameType.tablet,
              FrameType.desktop,
            ]),
            const SizedBox(height: 10),
            _section('Notes & Templates', const [
              FrameType.noteBlank,
              FrameType.noteLined,
              FrameType.noteDotted,
              FrameType.noteGrid,
              FrameType.graphPaper,
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<FrameType> types) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF999999),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 7),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.82,
          children: types.map(_cell).toList(),
        ),
      ],
    );
  }

  Widget _cell(FrameType type) {
    final label = FrameItem.labelFor(type);
    final w = FrameItem.defaultWidth(type);
    final h = FrameItem.defaultHeight(type);
    final ar = w / h;
    const maxDim = 40.0;
    final pw = ar >= 1 ? maxDim : maxDim * ar;
    final ph = ar <= 1 ? maxDim : maxDim / ar;

    return InkWell(
      onTap: () => onSelect(type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: pw + 4,
              height: ph + 4,
              child: CustomPaint(
                painter: _FrameIconPainter(type: type),
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrameIconPainter extends CustomPainter {
  final FrameType type;
  const _FrameIconPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // White fill
    canvas.drawRect(rect, Paint()..color = Colors.white);

    // Template preview (simplified)
    _drawTemplatePreview(canvas, size);

    // Device-specific decorations
    _drawDeviceDecor(canvas, size);

    // Border with rounded corners for devices
    final radius = (type == FrameType.mobile || type == FrameType.tablet)
        ? 3.5
        : 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..color = const Color(0xFF333333)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawTemplatePreview(Canvas canvas, Size size) {
    final bg = FrameItem.defaultBackground(type);
    switch (bg) {
      case FrameBackground.blank:
        break;
      case FrameBackground.lined:
        final p = Paint()..color = const Color(0xFFB0C4DE)..strokeWidth = 0.6;
        for (double y = 6; y < size.height - 2; y += 6) {
          canvas.drawLine(Offset(2, y), Offset(size.width - 2, y), p);
        }
      case FrameBackground.dotted:
        final p = Paint()..color = const Color(0xFFAAAAAA);
        for (double x = 4; x < size.width; x += 5) {
          for (double y = 4; y < size.height; y += 5) {
            canvas.drawCircle(Offset(x, y), 0.7, p);
          }
        }
      case FrameBackground.grid:
        final p = Paint()..color = const Color(0xFFCCDDEE)..strokeWidth = 0.5;
        for (double x = 0; x < size.width; x += 6) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        for (double y = 0; y < size.height; y += 6) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
      case FrameBackground.graphPaper:
        final minor = Paint()
          ..color = const Color(0xFFCCEECC)
          ..strokeWidth = 0.3;
        final major = Paint()
          ..color = const Color(0xFF88CC88)
          ..strokeWidth = 0.6;
        for (double x = 0; x < size.width; x += 3) {
          canvas.drawLine(
              Offset(x, 0), Offset(x, size.height),
              x.round() % 15 == 0 ? major : minor);
        }
        for (double y = 0; y < size.height; y += 3) {
          canvas.drawLine(
              Offset(0, y), Offset(size.width, y),
              y.round() % 15 == 0 ? major : minor);
        }
    }
  }

  void _drawDeviceDecor(Canvas canvas, Size size) {
    switch (type) {
      case FrameType.desktop:
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, 7),
          Paint()..color = const Color(0xFF444444),
        );
        final colors = [
          const Color(0xFFFF5F57),
          const Color(0xFFFFBD2E),
          const Color(0xFF28C840),
        ];
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(
              Offset(3.5 + i * 5.5, 3.5), 1.8, Paint()..color = colors[i]);
        }
      case FrameType.mobile:
        // Notch
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(size.width / 2, 2.5),
                width: size.width * 0.35,
                height: 4),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFF333333),
        );
        // Home indicator
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(size.width / 2, size.height - 2.5),
                width: size.width * 0.4,
                height: 2),
            const Radius.circular(1),
          ),
          Paint()..color = const Color(0xFF444444),
        );
      case FrameType.tablet:
        // Camera
        canvas.drawCircle(
            Offset(size.width / 2, 2.5), 1.2, Paint()..color = const Color(0xFF555555));
        // Home circle
        canvas.drawCircle(
          Offset(size.width / 2, size.height - 3.5),
          2.5,
          Paint()
            ..color = const Color(0xFF888888)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(_FrameIconPainter old) => type != old.type;
}

// ── Shape picker panel ─────────────────────────────────────────────────────

class _ShapePickerPanel extends StatelessWidget {
  final void Function(ShapeType) onSelect;
  const _ShapePickerPanel({required this.onSelect});

  static const _shapes = ShapeType.values;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
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
          const Text(
            'SHAPES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF999999),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: _shapes.map(_cell).toList(),
          ),
        ],
      ),
    );
  }

  Widget _cell(ShapeType type) {
    return InkWell(
      onTap: () => onSelect(type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 36,
              child: CustomPaint(
                painter: _ShapeIconPainter(type: type),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ShapeItem.labelFor(type),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shape icon painter (picker thumbnails) ─────────────────────────────────

class _ShapeIconPainter extends CustomPainter {
  final ShapeType type;
  const _ShapeIconPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 4.0;
    final rect = Rect.fromLTWH(pad, pad, size.width - pad * 2, size.height - pad * 2);
    final paint = Paint()
      ..color = const Color(0xFF444444)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (type) {
      case ShapeType.rectangle:
        canvas.drawRect(rect, paint);
      case ShapeType.ellipse:
        canvas.drawOval(rect, paint);
      case ShapeType.triangle:
        canvas.drawPath(_tri(rect), paint);
      case ShapeType.diamond:
        canvas.drawPath(_diamond(rect), paint);
      case ShapeType.star:
        canvas.drawPath(_star(rect), paint);
      case ShapeType.hexagon:
        canvas.drawPath(_hex(rect), paint);
      case ShapeType.arrow:
        canvas.drawPath(_arrow(rect), paint);
      case ShapeType.line:
        canvas.drawLine(
          Offset(rect.left, rect.center.dy),
          Offset(rect.right, rect.center.dy),
          paint..strokeWidth = 2.5,
        );
    }
  }

  Path _tri(Rect r) => Path()
    ..moveTo(r.center.dx, r.top)
    ..lineTo(r.right, r.bottom)
    ..lineTo(r.left, r.bottom)
    ..close();

  Path _diamond(Rect r) => Path()
    ..moveTo(r.center.dx, r.top)
    ..lineTo(r.right, r.center.dy)
    ..lineTo(r.center.dx, r.bottom)
    ..lineTo(r.left, r.center.dy)
    ..close();

  Path _star(Rect r) {
    final cx = r.center.dx;
    final cy = r.center.dy;
    final outer = math.min(r.width, r.height) / 2;
    final inner = outer * 0.42;
    final p = Path();
    for (int i = 0; i < 10; i++) {
      final a = (i * math.pi / 5) - math.pi / 2;
      final rad = i.isEven ? outer : inner;
      final pt = Offset(cx + rad * math.cos(a), cy + rad * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  Path _hex(Rect r) {
    final cx = r.center.dx;
    final cy = r.center.dy;
    final rx = r.width / 2;
    final ry = r.height / 2;
    final p = Path();
    for (int i = 0; i < 6; i++) {
      final a = (i * math.pi / 3) - math.pi / 6;
      final pt = Offset(cx + rx * math.cos(a), cy + ry * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  Path _arrow(Rect r) {
    final headW = r.width * 0.38;
    final shaftH = r.height * 0.42;
    final st = r.top + (r.height - shaftH) / 2;
    final sb = st + shaftH;
    return Path()
      ..moveTo(r.left, st)
      ..lineTo(r.right - headW, st)
      ..lineTo(r.right - headW, r.top)
      ..lineTo(r.right, r.center.dy)
      ..lineTo(r.right - headW, r.bottom)
      ..lineTo(r.right - headW, sb)
      ..lineTo(r.left, sb)
      ..close();
  }

  @override
  bool shouldRepaint(_ShapeIconPainter old) => type != old.type;
}

// ── Shape preview painter (inside config dialog) ───────────────────────────

class _ShapePreviewPainter extends CustomPainter {
  final ShapeType type;
  final Color strokeColor;
  final double strokeWidth;
  final bool filled;
  final Color fillColor;

  const _ShapePreviewPainter({
    required this.type,
    required this.strokeColor,
    required this.strokeWidth,
    required this.filled,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final sp = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth.clamp(1.0, 4.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final fp = filled
        ? (Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true)
        : null;

    void draw(Path path) {
      if (fp != null) canvas.drawPath(path, fp);
      canvas.drawPath(path, sp);
    }

    final icon = _ShapeIconPainter(type: type);
    switch (type) {
      case ShapeType.rectangle:
        if (fp != null) canvas.drawRect(rect, fp);
        canvas.drawRect(rect, sp);
      case ShapeType.ellipse:
        if (fp != null) canvas.drawOval(rect, fp);
        canvas.drawOval(rect, sp);
      case ShapeType.triangle:
        draw(icon._tri(rect));
      case ShapeType.diamond:
        draw(icon._diamond(rect));
      case ShapeType.star:
        draw(icon._star(rect));
      case ShapeType.hexagon:
        draw(icon._hex(rect));
      case ShapeType.arrow:
        draw(icon._arrow(rect));
      case ShapeType.line:
        canvas.drawLine(rect.centerLeft, rect.centerRight,
            sp..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_ShapePreviewPainter old) =>
      type != old.type ||
      strokeColor != old.strokeColor ||
      strokeWidth != old.strokeWidth ||
      filled != old.filled ||
      fillColor != old.fillColor;
}

// ── Checklist card ─────────────────────────────────────────────────────────

class _ChecklistCard extends StatefulWidget {
  final ChecklistItem item;
  final void Function(ChecklistItem) onUpdate;
  const _ChecklistCard({required this.item, required this.onUpdate});

  @override
  State<_ChecklistCard> createState() => _ChecklistCardState();
}

class _ChecklistCardState extends State<_ChecklistCard> {
  final _newItemController = TextEditingController();

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  void _toggle(int i) {
    final entries = [...widget.item.entries];
    entries[i] = entries[i].copyWith(checked: !entries[i].checked);
    widget.onUpdate(widget.item.withEntries(entries));
  }

  void _addEntry(String text) {
    if (text.trim().isEmpty) return;
    final entries = [...widget.item.entries, ChecklistEntry(text: text.trim())];
    widget.onUpdate(widget.item.withEntries(entries));
    _newItemController.clear();
  }

  void _removeEntry(int i) {
    final entries = [...widget.item.entries]..removeAt(i);
    widget.onUpdate(widget.item.withEntries(entries));
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.item.entries.where((e) => e.checked).length;
    final total = widget.item.entries.length;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withAlpha(20),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.checklist_rounded, size: 15, color: Color(0xFF7C3AED)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(widget.item.title,
                      style: const TextStyle(fontWeight: FontWeight.w600,
                          fontSize: 13, color: Color(0xFF7C3AED))),
                ),
                if (total > 0)
                  Text('$done/$total',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          for (int i = 0; i < widget.item.entries.length; i++)
            InkWell(
              onTap: () => _toggle(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  children: [
                    Icon(
                      widget.item.entries[i].checked
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 18,
                      color: widget.item.entries[i].checked
                          ? const Color(0xFF7C3AED)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.item.entries[i].text,
                        style: TextStyle(
                          fontSize: 13,
                          decoration: widget.item.entries[i].checked
                              ? TextDecoration.lineThrough
                              : null,
                          color: widget.item.entries[i].checked
                              ? Colors.grey.shade400
                              : Colors.black87,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removeEntry(i),
                      child: Icon(Icons.close, size: 14, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: Row(
              children: [
                Icon(Icons.add_rounded, size: 18, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _newItemController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Add item…',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: _addEntry,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date/Time display card ──────────────────────────────────────────────────

class _DateTimeCard extends StatefulWidget {
  final DateTimeItem item;
  const _DateTimeCard({required this.item});

  @override
  State<_DateTimeCard> createState() => _DateTimeCardState();
}

class _DateTimeCardState extends State<_DateTimeCard> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    if (widget.item.isLive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m:$s $period';
  }

  String _fmtDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final dt = widget.item.isLive ? _now : widget.item.createdAt;
    final mode = widget.item.mode;
    final accentColor = widget.item.isLive
        ? const Color(0xFF1E88E5)
        : const Color(0xFF6D4C41);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.item.isLive ? Icons.radio_button_checked : Icons.push_pin_rounded,
                size: 11,
                color: accentColor,
              ),
              const SizedBox(width: 4),
              Text(
                widget.item.isLive ? 'LIVE' : 'STATIC',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (mode == DateTimeMode.time || mode == DateTimeMode.datetime)
            Text(_fmtTime(dt),
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w300, color: Colors.black87)),
          if (mode == DateTimeMode.date || mode == DateTimeMode.datetime)
            Padding(
              padding: EdgeInsets.only(
                  top: mode == DateTimeMode.datetime ? 2 : 0),
              child: Text(_fmtDate(dt),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ),
        ],
      ),
    );
  }
}
