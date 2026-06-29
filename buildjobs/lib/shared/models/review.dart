class Review {
  const Review({
    required this.id,
    required this.companyId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    this.reviewerProfessionalId,
    required this.rating,
    required this.title,
    required this.body,
    required this.createdAt,
    this.photoUrls = const [],
    this.ownerReply,
    this.ownerReplyAt,
  });

  final String id;
  final String companyId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  /// ID del perfil profesional del reviewer, si es un profesional.
  /// Null si es un cliente normal.
  final String? reviewerProfessionalId;
  final int rating;
  final String title;
  final String body;
  final DateTime createdAt;
  final List<String> photoUrls;
  final String? ownerReply;
  final DateTime? ownerReplyAt;

  /// Verdadero si quien dejó la reseña tiene un perfil profesional propio.
  bool get reviewerIsProfessional => reviewerProfessionalId != null;

  factory Review.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photo_urls'];
    final photos = rawPhotos is List
        ? rawPhotos.map((e) => e.toString()).toList()
        : <String>[];

    return Review(
      id: json['id'] as String,
      companyId: (json['professional_id'] ?? json['company_id']) as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? 'Usuario',
      userAvatarUrl: json['user_avatar_url'] as String?,
      reviewerProfessionalId:
          json['reviewer_professional_id'] as String?,
      rating: json['rating'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      photoUrls: photos,
      ownerReply: json['owner_reply'] as String?,
      ownerReplyAt: json['owner_reply_at'] != null
          ? DateTime.parse(json['owner_reply_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'professional_id': companyId,
        'user_id': userId,
        'user_name': userName,
        'rating': rating,
        'title': title,
        'body': body,
        'created_at': createdAt.toIso8601String(),
        'photo_urls': photoUrls,
        if (ownerReply != null) 'owner_reply': ownerReply,
        if (ownerReplyAt != null)
          'owner_reply_at': ownerReplyAt!.toIso8601String(),
      };
}
