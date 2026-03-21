import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/message_model.dart';

class VoiceRecorderButton extends StatefulWidget {
  final String receiverUserId;
  final void Function(MessageModel message) onMessageSent;

  const VoiceRecorderButton({
    super.key,
    required this.receiverUserId,
    required this.onMessageSent,
  });

  @override
  State<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends State<VoiceRecorderButton>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isCancelled = false;
  bool _isUploading = false;
  int _seconds = 0;
  Timer? _timer;
  String? _filePath;
  double _dragOffset = 0;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }

    HapticFeedback.mediumImpact();
    final dir = await getTemporaryDirectory();
    _filePath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path: _filePath!,
    );

    setState(() {
      _isRecording = true;
      _isCancelled = false;
      _seconds = 0;
      _dragOffset = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
      // Max 2 min
      if (_seconds >= 120) _stopAndSend();
    });
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    if (!_isRecording) return;

    final path = await _recorder.stop();
    setState(() => _isRecording = false);

    if (_isCancelled || path == null) {
      // Delete file if exists
      if (path != null) {
        try { File(path).deleteSync(); } catch (_) {}
      }
      HapticFeedback.lightImpact();
      return;
    }

    if (_seconds < 1) return; // Too short

    setState(() => _isUploading = true);
    HapticFeedback.lightImpact();

    try {
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(path, filename: 'voice.m4a'),
        'duration': _seconds.toString(),
      });

      final resp = await ApiClient.dio.post(
        ApiEndpoints.chatVoice(widget.receiverUserId),
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      final data = ApiClient.parseData(resp) as Map<String, dynamic>;
      final msg = MessageModel.fromJson(data);
      widget.onMessageSent(msg);

      // Cleanup
      try { File(path).deleteSync(); } catch (_) {}
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiClient.errorMessage(e)),
            backgroundColor: AppColors.callRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _onLongPressStart(LongPressStartDetails _) => _startRecording();

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    final offset = details.offsetFromOrigin.dx;
    setState(() => _dragOffset = offset);
    if (offset < -80) {
      // Slide to cancel threshold
      setState(() => _isCancelled = true);
    } else {
      setState(() => _isCancelled = false);
    }
  }

  void _onLongPressEnd(LongPressEndDetails _) => _stopAndSend();

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(1, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    if (_isUploading) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      );
    }

    if (_isRecording) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cancel hint
          AnimatedOpacity(
            opacity: _isCancelled ? 1 : 0.5,
            duration: const Duration(milliseconds: 150),
            child: Row(
              children: [
                Icon(Icons.arrow_back_ios_rounded,
                    size: 12,
                    color: _isCancelled ? AppColors.callRed : AppColors.textHint),
                Text(
                  _isCancelled ? 'Release to cancel' : '← Slide to cancel',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isCancelled ? AppColors.callRed : AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Timer
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Text(
              '🔴 ${_fmt(_seconds)}',
              style: TextStyle(
                fontSize: 12,
                color: Color.lerp(AppColors.callRed, Colors.orange,
                    _pulseCtrl.value),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Mic button (still held)
          GestureDetector(
            onLongPressMoveUpdate: _onLongPressMoveUpdate,
            onLongPressEnd: _onLongPressEnd,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.callRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      );
    }

    // Idle mic button
    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _onLongPressMoveUpdate,
      onLongPressEnd: _onLongPressEnd,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.mic_none_rounded,
            color: AppColors.textSecondary, size: 22),
      ),
    );
  }
}
