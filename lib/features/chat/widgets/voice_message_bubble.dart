import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String voiceUrl;
  final int durationSeconds;
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    required this.voiceUrl,
    required this.durationSeconds,
    required this.isMe,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  double _progress = 0.0;
  int _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      final total = widget.durationSeconds > 0 ? widget.durationSeconds : 1;
      setState(() {
        _elapsed = pos.inSeconds;
        _progress = (_elapsed / total).clamp(0.0, 1.0);
      });
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _progress = 0;
        _elapsed = 0;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.voiceUrl));
    }
  }

  String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(1, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.durationSeconds > 0 ? widget.durationSeconds : 0;
    final displaySeconds = _isPlaying ? _elapsed : total;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: widget.isMe ? AppColors.primaryGradient : null,
        color: widget.isMe ? null : AppColors.card,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
          bottomRight: Radius.circular(widget.isMe ? 4 : 18),
        ),
      ),
      child: Row(
        children: [
          // Play/pause button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: widget.isMe ? Colors.white : AppColors.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Waveform + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: widget.isMe
                        ? Colors.white.withValues(alpha: 0.3)
                        : AppColors.border,
                    valueColor: AlwaysStoppedAnimation(
                      widget.isMe ? Colors.white : AppColors.primary,
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmt(displaySeconds),
                  style: AppTextStyles.caption.copyWith(
                    color: widget.isMe
                        ? Colors.white70
                        : AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.mic_rounded,
            size: 14,
            color: widget.isMe
                ? Colors.white60
                : AppColors.textHint,
          ),
        ],
      ),
    );
  }
}
