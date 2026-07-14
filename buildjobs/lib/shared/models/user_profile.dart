class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.role = 'client',
    this.city,
    this.reviewCount = 0,
    this.messageEmailNotifications = true,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final String role;
  final String? city;
  final int reviewCount;
  final bool messageEmailNotifications;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'client',
      city: json['city'] as String?,
      reviewCount: json['review_count'] as int? ?? 0,
      messageEmailNotifications:
          json['message_email_notifications'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'review_count': reviewCount,
      };
}
