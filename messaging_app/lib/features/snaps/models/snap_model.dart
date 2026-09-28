class SnapModel {
  final String id;
  final String senderId;
  final String senderUsername;
  final String senderDisplayName;
  final String? senderAvatarUrl;
  final String recipientId;
  final String mediaUrl;
  final String? caption;
  final int timerSeconds;
  final bool isViewOnce;
  final DateTime createdAtUtc;
  final bool isOpened;
  final DateTime? openedAtUtc;
  final int streakCount;

  SnapModel({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    required this.senderDisplayName,
    this.senderAvatarUrl,
    required this.recipientId,
    required this.mediaUrl,
    this.caption,
    required this.timerSeconds,
    required this.isViewOnce,
    required this.createdAtUtc,
    required this.isOpened,
    this.openedAtUtc,
    required this.streakCount,
  });

  factory SnapModel.fromJson(Map<String, dynamic> json) {
    return SnapModel(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderUsername: json['senderUsername']?.toString() ?? '',
      senderDisplayName: json['senderDisplayName']?.toString() ?? '',
      senderAvatarUrl: json['senderAvatarUrl']?.toString(),
      recipientId: json['recipientId']?.toString() ?? '',
      mediaUrl: json['mediaUrl']?.toString() ?? '',
      caption: json['caption']?.toString(),
      timerSeconds: json['timerSeconds'] is int ? json['timerSeconds'] : int.tryParse(json['timerSeconds'].toString()) ?? 5,
      isViewOnce: json['isViewOnce'] == true,
      createdAtUtc: json['createdAtUtc'] != null
          ? DateTime.tryParse(json['createdAtUtc'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isOpened: json['isOpened'] == true,
      openedAtUtc: json['openedAtUtc'] != null
          ? DateTime.tryParse(json['openedAtUtc'].toString())
          : null,
      streakCount: json['streakCount'] is int ? json['streakCount'] : int.tryParse(json['streakCount'].toString()) ?? 0,
    );
  }
}
