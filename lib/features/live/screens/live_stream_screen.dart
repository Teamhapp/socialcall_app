import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/theme/app_colors.dart';

class LiveStreamScreen extends ConsumerStatefulWidget {
  const LiveStreamScreen({super.key});

  @override
  ConsumerState<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends ConsumerState<LiveStreamScreen> {
  Room? _room;
  LocalVideoTrack? _videoTrack;
  bool _isLive = false;
  bool _isLoading = false;
  bool _isCameraOn = true;
  bool _isMicOn = true;
  int _viewerCount = 0;
  int _giftCount = 0;
  String? _streamId;
  String _title = 'Live Stream';
  final _titleCtrl = TextEditingController();

  final List<_Comment> _comments = [];

  // Socket listener refs for cleanup
  MessageCallback? _commentCb;
  MessageCallback? _giftCb;
  MessageCallback? _viewerJoinedCb;
  MessageCallback? _viewerLeftCb;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _cleanupSocketListeners();
    if (_streamId != null) {
      SocketService.emit('leave_stream', {'streamId': _streamId!});
    }
    _endStreamSilent();
    super.dispose();
  }

  Future<void> _endStreamSilent() async {
    try {
      await _room?.disconnect();
      _videoTrack?.stop();
      if (_streamId != null) {
        await ApiClient.dio.delete(ApiEndpoints.streamEnd(_streamId!));
      }
    } catch (_) {}
  }

  void _setupSocketListeners() {
    SocketService.emit('join_stream', {'streamId': _streamId!});

    _commentCb = (data) {
      if (!mounted) return;
      final name = data['name'] as String? ?? 'Viewer';
      final text = data['text'] as String? ?? '';
      if (text.isEmpty) return;
      setState(() {
        _comments.add(_Comment(name: name, text: text));
        if (_comments.length > 50) _comments.removeAt(0);
      });
    };
    SocketService.on('stream_comment', _commentCb!);

    _giftCb = (data) {
      if (!mounted) return;
      final emoji  = (data['gift'] as Map?)?['emoji'] as String? ?? '🎁';
      final name   = (data['gift'] as Map?)?['name']  as String? ?? 'Gift';
      final sender = data['senderName'] as String? ?? 'Viewer';
      setState(() {
        _giftCount++;
        _comments.add(_Comment(name: sender, text: 'sent $emoji $name'));
        if (_comments.length > 50) _comments.removeAt(0);
      });
    };
    SocketService.on('stream_gift_received', _giftCb!);

    _viewerJoinedCb = (data) {
      final count = (data['viewerCount'] as num?)?.toInt();
      if (count != null && mounted) setState(() => _viewerCount = count);
    };
    SocketService.on('viewer_joined', _viewerJoinedCb!);

    _viewerLeftCb = (data) {
      if (mounted) setState(() => _viewerCount = (_viewerCount - 1).clamp(0, 999999));
    };
    SocketService.on('viewer_left', _viewerLeftCb!);
  }

  void _cleanupSocketListeners() {
    if (_commentCb      != null) { SocketService.off('stream_comment',       _commentCb);      _commentCb      = null; }
    if (_giftCb         != null) { SocketService.off('stream_gift_received', _giftCb);         _giftCb         = null; }
    if (_viewerJoinedCb != null) { SocketService.off('viewer_joined',        _viewerJoinedCb); _viewerJoinedCb = null; }
    if (_viewerLeftCb   != null) { SocketService.off('viewer_left',          _viewerLeftCb);   _viewerLeftCb   = null; }
  }

  Future<void> _goLive() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final res = await ApiClient.dio.post(ApiEndpoints.goLive, data: {
        'title': _titleCtrl.text.trim().isEmpty ? 'Live Stream' : _titleCtrl.text.trim(),
      });

      final data = res.data['data'];
      final token = data['token'] as String;
      final livekitUrl = data['livekitUrl'] as String;
      _streamId = data['stream']['id'].toString();

      final room = Room();
      await room.connect(livekitUrl, token);

      // Publish camera + mic
      _videoTrack = await LocalVideoTrack.createCameraTrack();
      await room.localParticipant?.publishVideoTrack(_videoTrack!);
      await room.localParticipant?.setMicrophoneEnabled(true);

      setState(() {
        _room = room;
        _isLive = true;
        _isLoading = false;
        _title = data['stream']['title'] as String? ?? 'Live Stream';
      });

      // Join socket room to receive viewer comments, gifts, and join/leave events
      _setupSocketListeners();

      // Keep screen on
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to go live: $e'), backgroundColor: AppColors.callRed),
        );
      }
    }
  }

  Future<void> _endStream() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('End Stream?'),
        content: const Text('This will disconnect all viewers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.callRed),
            child: const Text('End Stream', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    _cleanupSocketListeners();
    if (_streamId != null) SocketService.emit('leave_stream', {'streamId': _streamId!});
    try {
      await _room?.disconnect();
      _videoTrack?.stop();
      if (_streamId != null) {
        await ApiClient.dio.delete(ApiEndpoints.streamEnd(_streamId!));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _toggleCamera() async {
    await _room?.localParticipant?.setCameraEnabled(!_isCameraOn);
    setState(() => _isCameraOn = !_isCameraOn);
  }

  Future<void> _toggleMic() async {
    await _room?.localParticipant?.setMicrophoneEnabled(!_isMicOn);
    setState(() => _isMicOn = !_isMicOn);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLive) return _buildPreLiveScreen();
    return _buildLiveScreen();
  }

  Widget _buildPreLiveScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Go Live'),
        backgroundColor: AppColors.background,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_rounded, size: 48, color: AppColors.textHint),
                  SizedBox(height: 8),
                  Text('Camera preview will start after going live',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleCtrl,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Stream Title',
                hintText: 'e.g. Morning Chat, Q&A Session...',
                prefixIcon: Icon(Icons.edit_rounded),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _goLive,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.live_tv_rounded, color: Colors.white),
                label: Text(_isLoading ? 'Starting...' : 'Go Live Now',
                    style: const TextStyle(color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.callRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveScreen() {
    final track = _videoTrack;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video preview
          if (track != null && _isCameraOn)
            Positioned.fill(child: VideoTrackRenderer(track))
          else
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black87,
                child: Center(
                  child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 64),
                ),
              ),
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.callRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 8),
                        SizedBox(width: 4),
                        Text('LIVE', style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w800, fontSize: 12, fontFamily: 'Poppins')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_title,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.remove_red_eye_rounded,
                            color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text('$_viewerCount',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 13, fontFamily: 'Poppins')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Gift ticker
          if (_giftCount > 0)
            Positioned(
              top: 80,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text('$_giftCount', style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                  ],
                ),
              ),
            ),

          // Comments
          Positioned(
            left: 0,
            right: 80,
            bottom: 100,
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _comments.length,
                itemBuilder: (_, i) {
                  final c = _comments[_comments.length - 1 - i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
                          children: [
                            TextSpan(text: '${c.name}  ',
                                style: const TextStyle(
                                    color: AppColors.primary, fontWeight: FontWeight.w700)),
                            TextSpan(text: c.text, style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlBtn(
                    icon: _isCameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                    label: _isCameraOn ? 'Camera' : 'Off',
                    onTap: _toggleCamera,
                  ),
                  _ControlBtn(
                    icon: _isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                    label: _isMicOn ? 'Mic' : 'Muted',
                    onTap: _toggleMic,
                  ),
                  GestureDetector(
                    onTap: _isLoading ? null : _endStream,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.callRed,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text('End Stream',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Comment {
  final String name;
  final String text;
  _Comment({required this.name, required this.text});
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ControlBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Poppins')),
        ],
      ),
    );
  }
}
