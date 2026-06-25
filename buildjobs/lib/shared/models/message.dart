class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String,
        senderId: json['sender_id'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        readAt: json['read_at'] != null
            ? DateTime.parse(json['read_at'] as String)
            : null,
      );
}

class Conversation {
  const Conversation({
    required this.id,
    required this.userId,
    required this.professionalId,
    required this.professionalName,
    this.professionalPhoto,
    this.lastMessage,
    this.lastMessageAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String professionalId;
  final String professionalName;
  final String? professionalPhoto;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime updatedAt;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final prof = json['professionals'] as Map<String, dynamic>?;
    return Conversation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      professionalId: json['professional_id'] as String,
      professionalName: prof?['name'] as String? ?? 'Profesional',
      professionalPhoto: prof?['profile_photo'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
