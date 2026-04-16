import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../models/stroke.dart';
import '../painters/whiteboard_painter.dart';
import '../widgets/toolbar.dart';

class WhiteboardScreen extends StatefulWidget {
  const WhiteboardScreen({super.key});

  @override
  State<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends State<WhiteboardScreen> {
  final _transformationController = TransformationController();
  final List<Stroke> _strokes = [];
  Stroke? _activeStroke;

  DrawingTool _tool = DrawingTool.pen;
  Color _color = Colors.black;
  double _strokeWidth = 3.0;

  // Track whether the user is currently panning (two-finger / middle-mouse)
  bool _isPanning = false;
  int _pointerCount = 0;

  // Canvas is effectively infinite — we place a very large fixed-size child
  // so InteractiveViewer has something to clip against, but drawing coordinates
  // are stored in canvas space, not screen space.
  static const double _canvasSize = 50000.0;
  static const Offset _canvasCenter = Offset(_canvasSize / 2, _canvasSize / 2);

  @override
  void initState() {
    super.initState();
    // Start centered
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
    _transformationController.dispose();
    super.dispose();
  }

  Offset _toCanvasOffset(Offset screenOffset) {
    final matrix = _transformationController.value.clone()..invert();
    final transformed = MatrixUtils.transformPoint(matrix, screenOffset);
    return transformed;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    if (_pointerCount > 1) {
      // Multi-touch → pan mode; cancel active stroke
      setState(() {
        _activeStroke = null;
        _isPanning = true;
      });
      return;
    }

    // Middle mouse button → pan (handled by InteractiveViewer natively via panEnabled)
    if (event.buttons == kMiddleMouseButton) return;

    final canvasPos = _toCanvasOffset(event.position);
    setState(() {
      _isPanning = false;
      _activeStroke = Stroke(
        points: [canvasPos],
        color: _color,
        strokeWidth: _tool == DrawingTool.eraser ? _strokeWidth * 3 : _strokeWidth,
        tool: _tool,
      );
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isPanning || _activeStroke == null) return;
    final canvasPos = _toCanvasOffset(event.position);
    setState(() {
      _activeStroke = _activeStroke!.copyWith(
        points: [..._activeStroke!.points, canvasPos],
      );
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointerCount = (_pointerCount - 1).clamp(0, 10);
    if (_pointerCount == 0) _isPanning = false;

    if (_activeStroke != null) {
      setState(() {
        _strokes.add(_activeStroke!);
        _activeStroke = null;
      });
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerCount = (_pointerCount - 1).clamp(0, 10);
    setState(() {
      _activeStroke = null;
      if (_pointerCount == 0) _isPanning = false;
    });
  }

  void _undo() {
    if (_strokes.isNotEmpty) setState(() => _strokes.removeLast());
  }

  void _clear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear whiteboard?'),
        content: const Text('All strokes will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() => _strokes.clear());
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.keyZ &&
              HardwareKeyboard.instance.isControlPressed) {
            _undo();
          }
        },
        child: Stack(
          children: [
            Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: InteractiveViewer(
                transformationController: _transformationController,
                // Pan with two fingers on tablet; mouse drag on desktop
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.1,
                maxScale: 10.0,
                // Disable default pan so single-touch draws; re-enable via _isPanning
                panAxis: PanAxis.free,
                // Intercept single-touch for drawing; InteractiveViewer handles
                // two-finger pan/pinch-zoom automatically.
                interactionEndFrictionCoefficient: double.infinity,
                child: SizedBox(
                  width: _canvasSize,
                  height: _canvasSize,
                  child: CustomPaint(
                    painter: WhiteboardPainter(
                      strokes: _strokes,
                      activeStroke: _activeStroke,
                    ),
                    child: Container(color: Colors.white),
                  ),
                ),
              ),
            ),
            // Toolbar — floats at the top center
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 0,
              right: 0,
              child: Center(
                child: WhiteboardToolbar(
                  selectedTool: _tool,
                  selectedColor: _color,
                  strokeWidth: _strokeWidth,
                  onToolChanged: (t) => setState(() => _tool = t),
                  onColorChanged: (c) => setState(() {
                    _color = c;
                    _tool = DrawingTool.pen;
                  }),
                  onStrokeWidthChanged: (w) => setState(() => _strokeWidth = w),
                  onUndo: _undo,
                  onClear: _clear,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
