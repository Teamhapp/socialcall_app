class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json['id'],
        senderId: json['sender_id'],
        receiverId: json['receiver_id'],
        content: json['content'],
        isRead: json['is_read'] ?? false,
        createdAt: DateTime.parse(json['created_at']),
      );

  bool isSentBy(String userId) => senderId == userId;
}
