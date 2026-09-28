class UserProfileModel {
  final String userId;
  final String username;
  final String displayName;
  final String? email;
  final String? bio;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeenAtUtc;
  final bool isPrivate;
  final int followersCount;
  final int followingCount;
  final String? followStatus;

  UserProfileModel({
    required this.userId,
    required this.username,
    required this.displayName,
    this.email,
    this.bio,
    this.avatarUrl,
    required this.isOnline,
    this.lastSeenAtUtc,
    this.isPrivate = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.followStatus,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? '',
      email: json['email'],
      bio: json['bio'],
      avatarUrl: json['avatarUrl'],
      isOnline: json['isOnline'] ?? false,
      lastSeenAtUtc: json['lastSeenAtUtc'] != null 
          ? DateTime.tryParse(json['lastSeenAtUtc']) 
          : null,
      isPrivate: json['isPrivate'] ?? false,
      followersCount: json['followersCount'] ?? 0,
      followingCount: json['followingCount'] ?? 0,
      followStatus: json['followStatus'],
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'username': username,
    'displayName': displayName,
    'email': email,
    'bio': bio,
    'avatarUrl': avatarUrl,
    'isOnline': isOnline,
    'lastSeenAtUtc': lastSeenAtUtc?.toIso8601String(),
    'isPrivate': isPrivate,
    'followersCount': followersCount,
    'followingCount': followingCount,
    'followStatus': followStatus,
  };
}

class AuthResponseModel {
  final String userId;
  final String username;
  final String displayName;
  final String email;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAtUtc;
  final UserProfileModel profile;

  AuthResponseModel({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAtUtc,
    required this.profile,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? '',
      email: json['email'] ?? '',
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      expiresAtUtc: json['expiresAtUtc'] != null 
          ? DateTime.parse(json['expiresAtUtc']) 
          : DateTime.now().add(const Duration(hours: 1)),
      profile: UserProfileModel.fromJson(json['profile'] ?? {}),
    );
  }
}
