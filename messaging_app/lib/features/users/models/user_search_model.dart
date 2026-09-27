class UserSearchResultModel {
  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final bool isOnline;
  final DateTime? lastSeenAtUtc;

  UserSearchResultModel({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    required this.isOnline,
    this.lastSeenAtUtc,
  });

  factory UserSearchResultModel.fromJson(Map<String, dynamic> json) {
    return UserSearchResultModel(
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? '',
      avatarUrl: json['avatarUrl'],
      bio: json['bio'],
      isOnline: json['isOnline'] ?? false,
      lastSeenAtUtc: json['lastSeenAtUtc'] != null 
          ? DateTime.tryParse(json['lastSeenAtUtc']) 
          : null,
    );
  }

  String get initials {
    if (displayName.trim().isEmpty) return username.isNotEmpty ? username[0].toUpperCase() : 'U';
    final parts = displayName.trim().split(' ');
    if (parts.length > 1 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  UserSearchResultModel copyWith({
    String? userId,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    bool? isOnline,
    DateTime? lastSeenAtUtc,
  }) {
    return UserSearchResultModel(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      lastSeenAtUtc: lastSeenAtUtc ?? this.lastSeenAtUtc,
    );
  }
}
