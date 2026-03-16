import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class WatchStreamScreen extends ConsumerStatefulWidget {
  final String streamId;
  final String hostName;
  final String title;

  const WatchStreamScreen({
    super.key,
    required this.streamId,
    required this.hostName,
    required this.title,
  });

  @override
  ConsumerState<WatchStreamScreen> createState() => _WatchStreamScreenState();
}

class _WatchStreamScreenState extends ConsumerState<WatchStreamScreen> {
  Room? _room;
  VideoTrack? _hostVideoTrack;
  bool _isConnecting = true;
  String? _error;
  final List<_Comment> _comments = [];
  final _commentCtrl = TextEditingController();
  int _viewerCount = 0;

  // Socket listener refs for cleanup
  MessageCallback? _commentCb;
  MessageCallback? _giftCb;
  MessageCallback? _endedCb;
  MessageCallback? _viewerJoinedCb;

  @override
  void initState() {
    super.initState();
    _joinStream();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _cleanupSocketListeners();
    SocketService.emit('leave_stream', {'streamId': widget.streamId});
    _leaveStream();
    super.dispose();
  }

  Future<void> _leaveStream() async {
    try {
      await _room?.disconnect();
      await ApiClient.dio.post(ApiEndpoints.streamLeave(widget.streamId));
    } catch (_) {}
  }

  void _setupSocketListeners() {
    // Join the socket room so we receive real-time stream events
    SocketService.emit('join_stream', {'streamId': widget.streamId});

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

    _endedCb = (data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The stream has ended')),
      );
      Navigator.of(context).pop();
    };
    SocketService.on('stream_ended', _endedCb!);
  }

  void _cleanupSocketListeners() {
    if (_commentCb     != null) { SocketService.off('stream_comment',       _commentCb);     _commentCb     = null; }
    if (_giftCb        != null) { SocketService.off('stream_gift_received', _giftCb);        _giftCb        = null; }
    if (_viewerJoinedCb != null){ SocketService.off('viewer_joined',        _viewerJoinedCb);_viewerJoinedCb = null; }
    if (_endedCb       != null) { SocketService.off('stream_ended',         _endedCb);       _endedCb       = null; }
  }

  Future<void> _joinStream() async {
    try {
      final res = await ApiClient.dio.get(ApiEndpoints.streamToken(widget.streamId));
      final data = res.data['data'];
      final token = data['token'] as String;
      final livekitUrl = data['livekitUrl'] as String;
      final stream = data['stream'] as Map<String, dynamic>;

      final room = Room();

      // Listen for published tracks
      room.addListener(() {
        for (final participant in room.remoteParticipants.values) {
          for (final publication in participant.videoTrackPublications) {
            if (publication.track != null && publication.subscribed) {
              if (mounted) {
                setState(() => _hostVideoTrack = publication.track as VideoTrack?);
              }
            }
          }
        }
      });

      await room.connect(livekitUrl, token);

      // Join socket room for real-time comments, gifts, and stream-end events
      _setupSocketListeners();

      if (mounted) {
        setState(() {
          _room = room;
          _isConnecting = false;
          _viewerCount = (stream['viewer_count'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _error = 'Failed to join stream: $e';
        });
      }
    }
  }

  void _sendComment(String text) {
    if (text.trim().isEmpty) return;
    _commentCtrl.clear();
    // Emit to socket — server relays to all viewers and the host
    SocketService.emit('stream_comment', {
      'streamId': widget.streamId,
      'text': text.trim(),
    });
    // Show own comment immediately (don't wait for server echo)
    setState(() {
      _comments.add(_Comment(name: 'You', text: text.trim()));
      if (_comments.length > 50) _comments.removeAt(0);
    });
  }

  void _showGiftPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GiftPicker(
        streamId: widget.streamId,
        onGiftSent: (giftName) {
          if (mounted) {
            setState(() {
              _comments.add(_Comment(name: 'You', text: 'sent $giftName 🎁'));
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnecting) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Joining stream...', style: TextStyle(color: Colors.white70,
                  fontFamily: 'Poppins')),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Stream'), backgroundColor: AppColors.background),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.callRed, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video
          if (_hostVideoTrack != null)
            Positioned.fill(child: VideoTrackRenderer(_hostVideoTrack!))
          else
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text('Waiting for host video...',
                          style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                    ],
                  ),
                ),
              ),
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.hostName,
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w700, fontSize: 14,
                                fontFamily: 'Poppins')),
                        Text(widget.title,
                            style: const TextStyle(color: Colors.white70, fontSize: 12,
                                fontFamily: 'Poppins'),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.callRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('LIVE', style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 11, fontFamily: 'Poppins')),
                  ),
                  const SizedBox(width: 8),
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
                                fontSize: 12, fontFamily: 'Poppins')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Comments list
          Positioned(
            left: 0,
            right: 0,
            bottom: 90,
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                reverse: true,
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
                                style: const TextStyle(color: AppColors.primary,
                                    fontWeight: FontWeight.w700)),
                            TextSpan(text: c.text,
                                style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom input bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  12, 10, 12, MediaQuery.of(context).viewInsets.bottom + 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _commentCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14,
                            fontFamily: 'Poppins'),
                        decoration: const InputDecoration(
                          hintText: 'Say something...',
                          hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: _sendComment,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _sendComment(_commentCtrl.text),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showGiftPicker,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🎁',
                          style: TextStyle(fontSize: 20),
                          textAlign: TextAlign.center),
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

// ── Gift picker bottom sheet ──────────────────────────────────────────────────
class _GiftPicker extends StatefulWidget {
  final String streamId;
  final void Function(String giftName) onGiftSent;

  const _GiftPicker({required this.streamId, required this.onGiftSent});

  @override
  State<_GiftPicker> createState() => _GiftPickerState();
}

class _GiftPickerState extends State<_GiftPicker> {
  List<Map<String, dynamic>> _gifts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  Future<void> _loadGifts() async {
    try {
      final res = await ApiClient.dio.get(ApiEndpoints.gifts);
      setState(() {
        _gifts = List<Map<String, dynamic>>.from(res.data['data'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendGift(Map<String, dynamic> gift) async {
    Navigator.of(context).pop();
    // Emit stream_gift via socket — server deducts coins, credits host (65%),
    // increments gift_count, and broadcasts stream_gift_received to the room.
    SocketService.emit('stream_gift', {
      'streamId': widget.streamId,
      'giftId': gift['id'],
    });
    widget.onGiftSent(gift['name'] as String? ?? 'Gift');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text('Send a Gift', style: AppTextStyles.headingSmall),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const CircularProgressIndicator()
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _gifts.length,
              itemBuilder: (_, i) {
                final gift = _gifts[i];
                return GestureDetector(
                  onTap: () => _sendGift(gift),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(gift['emoji'] as String? ?? '🎁',
                            style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(gift['name'] as String? ?? '',
                            style: AppTextStyles.caption,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('💎 ${(gift['price'] as num?)?.toInt() ?? 0}',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
