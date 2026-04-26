import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/whiteboard_item.dart';

class RecordingCard extends StatefulWidget {
  final RecordingItem item;
  final ValueChanged<RecordingItem> onUpdate;

  const RecordingCard({super.key, required this.item, required this.onUpdate});

  @override
  State<RecordingCard> createState() => _RecordingCardState();
}

class _RecordingCardState extends State<RecordingCard>
    with SingleTickerProviderStateMixin {
  AudioRecorder? _recorder;
  bool _isRecording = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  late AnimationController _pulse;

  String? get _filePath => widget.item.filePath;
  bool get _hasRecording => _filePath != null && File(_filePath!).existsSync();

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _recorder?.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    _recorder ??= AudioRecorder();
    final hasPermission = await _recorder!.hasPermission();
    if (!hasPermission || !mounted) return;

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
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder?.stop();
    if (!mounted) return;
    setState(() => _isRecording = false);
    if (path != null) {
      widget.onUpdate(RecordingItem(
        position: widget.item.position,
        filePath: path,
        durationSeconds: _elapsed.inSeconds,
        label: widget.item.label,
      ));
    }
  }

  Future<void> _playRecording() async {
    if (_filePath == null) return;
    final uri = Uri.file(_filePath!);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isRecording
              ? const Color(0xFFE53935)
              : Colors.grey.shade200,
          width: _isRecording ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Mic / status icon
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) {
                return Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? Color.lerp(
                            const Color(0xFFE53935),
                            const Color(0xFFEF9A9A),
                            _pulse.value,
                          )
                        : _hasRecording
                            ? const Color(0xFF1E88E5).withAlpha(20)
                            : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _isRecording
                        ? Icons.stop_rounded
                        : _hasRecording
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                    size: 20,
                    color: _isRecording
                        ? Colors.white
                        : _hasRecording
                            ? const Color(0xFF1E88E5)
                            : Colors.black45,
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            // Label + duration / status
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isRecording
                        ? _fmt(_elapsed.inSeconds)
                        : _hasRecording
                            ? _fmt(widget.item.durationSeconds)
                            : 'Tap mic to record',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isRecording
                          ? const Color(0xFFE53935)
                          : Colors.black45,
                      fontWeight: _isRecording
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            // Action buttons
            if (_hasRecording && !_isRecording) ...[
              _CardBtn(
                icon: Icons.play_arrow_rounded,
                color: const Color(0xFF1E88E5),
                onTap: _playRecording,
              ),
              const SizedBox(width: 4),
            ],
            _CardBtn(
              icon: _isRecording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded,
              color: _isRecording ? const Color(0xFFE53935) : Colors.black38,
              onTap: _isRecording ? _stopRecording : _startRecording,
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CardBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: color),
        ),
      );
}
