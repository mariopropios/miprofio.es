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
    required this.peerName,
    this.peerPhoto,
    this.lastMessage,
    this.lastMessageAt,
    required this.updatedAt,
    this.unreadCount = 0,
    this.viewingAsProfessional = false,
  });

  final String id;
  final String userId;
  final String professionalId;
  final String peerName;
  final String? peerPhoto;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime updatedAt;
  final int unreadCount;
  final bool viewingAsProfessional;

  bool get hasUnread => unreadCount > 0;

  /// Compatibilidad con pantallas que aún usan el nombre anterior.
  String get professionalName => peerName;
  String? get professionalPhoto => peerPhoto;

  factory Conversation.fromRow(
    Map<String, dynamic> json, {
    required String currentUserId,
    required Set<String> ownedProfessionalIds,
    int unreadCount = 0,
  }) {
    final prof = json['professionals'] as Map<String, dynamic>?;
    final client = json['client'] as Map<String, dynamic>?;
    final professionalId = json['professional_id'] as String;
    final viewingAsProfessional =
        ownedProfessionalIds.contains(professionalId);

    final peerName = viewingAsProfessional
        ? (client?['full_name'] as String? ?? 'Cliente')
        : (prof?['name'] as String? ?? 'Profesional');
    final peerPhoto = viewingAsProfessional
        ? (client?['avatar_url'] as String?)
        : (prof?['profile_photo'] as String?);

    return Conversation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      professionalId: professionalId,
      peerName: peerName,
      peerPhoto: peerPhoto,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      unreadCount: unreadCount,
      viewingAsProfessional: viewingAsProfessional,
    );
  }
}
