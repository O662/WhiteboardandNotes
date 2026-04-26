import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Drag payload when the user drags a finished panel recording onto the canvas.
class RecordingDragData {
  final String filePath;
  final int durationSeconds;
  const RecordingDragData(
      {required this.filePath, required this.durationSeconds});
}

class RecordingPanel extends StatefulWidget {
  /// Called when the user taps "Add widget" — places an empty recording widget
  /// on the canvas at the viewport centre.
  final VoidCallback onAddWidget;

  const RecordingPanel({super.key, required this.onAddWidget});

  @override
  State<RecordingPanel> createState() => _RecordingPanelState();
}

class _RecordingPanelState extends State<RecordingPanel>
    with SingleTickerProviderStateMixin {
  AudioRecorder? _recorder;
  bool _isRecording = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  late AnimationController _pulse;

  String? _savedPath;
  int _savedDuration = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _recorder?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isRecording) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    _recorder ??= AudioRecorder();
    final ok = await _recorder!.hasPermission();
    if (!ok || !mounted) return;

    final dir = await getApplicationDocumentsDirectory();
    final recDir = Directory('${dir.path}/recordings');
    if (!recDir.existsSync()) recDir.createSync(recursive: true);
    final path =
        '${recDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder!.start(
      const RecordConfig(encoder: AudioEncoder.wav),
      path: path,
    );
    setState(() {
      _isRecording = true;
      _elapsed = Duration.zero;
      _savedPath = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _recorder?.stop();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _savedPath = path;
      _savedDuration = _elapsed.inSeconds;
    });
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
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
          const Text('Recording',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          const SizedBox(height: 16),

          // ── Record / Stop button ──────────────────────────────────────────
          GestureDetector(
            onTap: _toggle,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) {
                final scale =
                    _isRecording ? 1.0 + _pulse.value * 0.1 : 1.0;
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _isRecording
                      ? const Color(0xFFE53935)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                  boxShadow: _isRecording
                      ? [
                          BoxShadow(
                            color: const Color(0xFFE53935).withAlpha(70),
                            blurRadius: 18,
                            spreadRadius: 4,
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 32,
                  color: _isRecording ? Colors.white : Colors.black54,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Status text
          Text(
            _isRecording
                ? _fmt(_elapsed.inSeconds)
                : _savedPath != null
                    ? 'Saved · ${_fmt(_savedDuration)}'
                    : 'Tap to record',
            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  (_isRecording || _savedPath != null) ? FontWeight.w700 : FontWeight.normal,
              color: _isRecording
                  ? const Color(0xFFE53935)
                  : _savedPath != null
                      ? const Color(0xFF43A047)
                      : Colors.black45,
            ),
          ),

          if (_isRecording) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: Color(0xFFE53935), shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                const Text('Recording',
                    style: TextStyle(fontSize: 11, color: Colors.black38)),
              ],
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Add to Board section ──────────────────────────────────────────
          const Text('Add to Board',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black45)),
          const SizedBox(height: 10),

          // "Add widget" button — places an empty recording widget
          _BoardBtn(
            icon: Icons.add_circle_outline_rounded,
            label: 'Add Recording Widget',
            color: const Color(0xFF1E88E5),
            onTap: widget.onAddWidget,
          ),
          const SizedBox(height: 8),

          // Draggable tile — only visible after a recording is saved
          if (_savedPath != null)
            Draggable<RecordingDragData>(
              data: RecordingDragData(
                  filePath: _savedPath!, durationSeconds: _savedDuration),
              feedback: Material(
                color: Colors.transparent,
                child: _DragTile(duration: _savedDuration),
              ),
              childWhenDragging: Opacity(
                opacity: 0.4,
                child: _DragTile(duration: _savedDuration),
              ),
              child: _DragTile(duration: _savedDuration),
            )
          else
            Opacity(
              opacity: 0.35,
              child: _DragTile(duration: 0, placeholder: true),
            ),
        ],
      ),
    );
  }
}

class _BoardBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BoardBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      );
}

class _DragTile extends StatelessWidget {
  final int duration;
  final bool placeholder;
  const _DragTile({required this.duration, this.placeholder = false});

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 178,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: placeholder ? Colors.grey.shade200 : const Color(0xFF43A047),
          width: 1.5,
        ),
        boxShadow: placeholder
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF43A047).withAlpha(30),
                  blurRadius: 6,
                )
              ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.audio_file_rounded,
            size: 20,
            color: placeholder ? Colors.black26 : const Color(0xFF43A047),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              placeholder ? 'Record first, then drag' : 'Recording · ${_fmt(duration)}',
              style: TextStyle(
                fontSize: 11,
                color: placeholder ? Colors.black38 : Colors.black87,
                fontWeight: placeholder ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ),
          if (!placeholder)
            const Icon(Icons.drag_indicator_rounded,
                size: 14, color: Colors.black26),
        ],
      ),
    );
  }
}
