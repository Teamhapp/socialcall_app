class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final bool isRead;
  final DateTime createdAt;
  final String? messageType;   // 'text' | 'gift' | 'voice' | 'image'
  final String? voiceUrl;
  final int? voiceDurationSeconds;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.isRead,
    required this.createdAt,
    this.messageType,
    this.voiceUrl,
    this.voiceDurationSeconds,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json['id']?.toString() ?? '',
        senderId: json['sender_id']?.toString() ?? '',
        receiverId: json['receiver_id']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        isRead: json['is_read'] as bool? ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'].toString())
            : DateTime.now(),
        messageType: json['message_type']?.toString(),
        voiceUrl: json['voice_url']?.toString(),
        voiceDurationSeconds: json['voice_duration_seconds'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content': content,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
        if (messageType != null) 'message_type': messageType,
        if (voiceUrl != null) 'voice_url': voiceUrl,
        if (voiceDurationSeconds != null)
          'voice_duration_seconds': voiceDurationSeconds,
      };

  bool isSentBy(String userId) => senderId == userId;
}
