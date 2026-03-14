import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/host_model.dart';
import '../../../models/message_model.dart';
import '../../../shared/widgets/online_badge.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final HostModel host;
  const ChatScreen({super.key, required this.host});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isTyping = false;
  bool _isLoadingHistory = true;
  bool _isStartingCall = false;
  final List<MessageModel> _messages = [];

  MessageCallback? _newMessageCb;
  MessageCallback? _typingCb;
  MessageCallback? _readCb;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _myUserId = ref.read(authProvider).user?.id;
    _loadHistory();
    _listenSocket();
  }

  // ── Load chat history ────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    try {
      final resp = await ApiClient.dio.get(
        ApiEndpoints.messages(widget.host.id),
      );
      final raw = ApiClient.parseData(resp);
      final list = (raw as List<dynamic>)
          .map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(list);
          _isLoadingHistory = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  // ── Socket listeners ─────────────────────────────────────────────────────────

  void _listenSocket() {
    // New message from the other person
    _newMessageCb = (data) {
      if (!mounted) return;
      final senderId =
          data['sender_id'] as String? ?? data['senderId'] as String? ?? '';
      // Only add if it's from the host we're chatting with
      if (senderId != widget.host.id) return;

      final msg = MessageModel.fromJson(data);
      setState(() {
        _isTyping = false;
        _messages.add(msg);
      });
      _scrollToBottom();

      // Mark as read
      SocketService.emit('mark_read', {'senderId': widget.host.id});
    };
    SocketService.on('new_message', _newMessageCb!);

    // Typing indicator
    _typingCb = (data) {
      if (!mounted) return;
      final senderId = data['senderId'] as String? ?? '';
      if (senderId != widget.host.id) return;
      setState(() => _isTyping = data['isTyping'] as bool? ?? false);
    };
    SocketService.on('typing', _typingCb!);

    // Messages read acknowledgement
    _readCb = (data) {
      if (!mounted) return;
      // Could mark sent messages as read here
      setState(() {});
    };
    SocketService.on('messages_read', _readCb!);
  }

  // ── Send message ─────────────────────────────────────────────────────────────

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Optimistic UI — add immediately
    final optimistic = MessageModel(
      id: 'opt_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _myUserId ?? '',
      receiverId: widget.host.id,
      content: text,
      isRead: false,
      createdAt: DateTime.now(),
    );
    setState(() {
      _messages.add(optimistic);
      _messageController.clear();
    });
    _scrollToBottom();

    // Emit via Socket.IO (server saves to DB and delivers to host)
    SocketService.emit('send_message', {
      'receiverId': widget.host.id,
      'content': text,
      'messageType': 'text',
    });

    // Stop typing indicator
    SocketService.emit(
        'typing', {'receiverId': widget.host.id, 'isTyping': false});
  }

  void _onTextChanged(String value) {
    SocketService.emit('typing', {
      'receiverId': widget.host.id,
      'isTyping': value.isNotEmpty,
    });
  }

  // ── Start call (via API to get callId first) ─────────────────────────────────

  Future<void> _startCall(bool isVideo) async {
    if (_isStartingCall) return;
    setState(() => _isStartingCall = true);
    try {
      final resp = await ApiClient.dio.post(
        ApiEndpoints.callInitiate,
        data: {
          'hostId': widget.host.id,
          'callType': isVideo ? 'video' : 'audio',
        },
      );
      final data = ApiClient.parseData(resp) as Map<String, dynamic>?;
      final callId = data?['callId']?.toString() ?? '';
      if (callId.isEmpty) throw Exception('No callId returned');
      if (mounted) {
        context.push('/call', extra: {
          'host': widget.host,
          'isVideo': isVideo,
          'callId': callId,
          'isCaller': true,
        });
      }
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
      if (mounted) setState(() => _isStartingCall = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    SocketService.off('new_message', _newMessageCb);
    SocketService.off('typing', _typingCb);
    SocketService.off('messages_read', _readCb);
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: GestureDetector(
          onTap: () =>
              context.push('/host/${widget.host.id}', extra: widget.host),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: widget.host.avatar != null
                    ? NetworkImage(widget.host.avatar!)
                    : null,
                backgroundColor: AppColors.card,
                child: widget.host.avatar == null
                    ? const Icon(Icons.person_rounded,
                        size: 20, color: AppColors.textHint)
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.host.name, style: AppTextStyles.labelLarge),
                  OnlineBadge(
                      isOnline: widget.host.isOnline, showLabel: true),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // Audio call
          IconButton(
            icon: _isStartingCall
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.callGreen),
                  )
                : const Icon(Icons.call_rounded, color: AppColors.callGreen),
            onPressed: () => _startCall(false),
          ),
          // Video call
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: AppColors.primary),
            onPressed: () => _startCall(true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Loading state
          if (_isLoadingHistory)
            const LinearProgressIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
            ),

          // Messages list
          Expanded(
            child: _isLoadingHistory && _messages.isEmpty
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded,
                                size: 48, color: AppColors.textHint),
                            const SizedBox(height: 12),
                            Text('No messages yet',
                                style: AppTextStyles.bodyMedium),
                            const SizedBox(height: 4),
                            Text('Say hello! 👋',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        color: AppColors.primary,
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount:
                              _messages.length + (_isTyping ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (_isTyping && i == _messages.length) {
                              return _TypingIndicator(host: widget.host);
                            }
                            final msg = _messages[i];
                            final isMe = msg.senderId == _myUserId;
                            return _MessageBubble(message: msg, isMe: isMe);
                          },
                        ),
                      ),
          ),

          // Input bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16,
                MediaQuery.of(context).viewInsets.bottom + 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showGiftSheet,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.card_giftcard_rounded,
                        color: AppColors.accent, size: 22),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: _onTextChanged,
                    style: AppTextStyles.bodyLarge,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: AppColors.card,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Gift sheet ────────────────────────────────────────────────────────────────

  void _showGiftSheet() {
    final gifts = [
      ('🌹', 'Rose', 10),
      ('💎', 'Diamond', 500),
      ('🎂', 'Cake', 50),
      ('🏆', 'Trophy', 200),
      ('❤️', 'Heart', 20),
      ('🎵', 'Music', 30),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Send a Gift 🎁', style: AppTextStyles.headingMedium),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: gifts.length,
              itemBuilder: (_, i) {
                final gift = gifts[i];
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    SocketService.emit('send_message', {
                      'receiverId': widget.host.id,
                      'content': '${gift.$1} ${gift.$2}',
                      'messageType': 'gift',
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${gift.$1} ${gift.$2} sent! ₹${gift.$3} deducted'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(gift.$1,
                            style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(gift.$2, style: AppTextStyles.caption),
                        Text('₹${gift.$3}',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.gold)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe ? AppColors.primaryGradient : null,
                color: isMe ? null : AppColors.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Text(
                message.content,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isMe ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeago.format(message.createdAt),
                  style: AppTextStyles.caption,
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 12,
                    color: message.isRead
                        ? AppColors.primary
                        : AppColors.textHint,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  final HostModel host;
  const _TypingIndicator({required this.host});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage:
                host.avatar != null ? NetworkImage(host.avatar!) : null,
            backgroundColor: AppColors.card,
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.textHint,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
