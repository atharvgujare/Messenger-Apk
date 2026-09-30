class CallSessionModel {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final String receiverId;
  final String conversationId;
  final String callType; // 'voice' or 'video'
  final String channelName;
  final String agoraAppId;
  final String token;
  final DateTime createdAtUtc;

  CallSessionModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.receiverId,
    required this.conversationId,
    required this.callType,
    required this.channelName,
    required this.agoraAppId,
    required this.token,
    required this.createdAtUtc,
  });

  bool get isVideo => callType.toLowerCase() == 'video';

  factory CallSessionModel.fromJson(Map<String, dynamic> json) {
    return CallSessionModel(
      callId: json['callId']?.toString() ?? '',
      callerId: json['callerId']?.toString() ?? '',
      callerName: json['callerName']?.toString() ?? 'Unknown',
      callerAvatar: json['callerAvatar']?.toString(),
      receiverId: json['receiverId']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      callType: json['callType']?.toString() ?? 'voice',
      channelName: json['channelName']?.toString() ?? '',
      agoraAppId: json['agoraAppId']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      createdAtUtc: json['createdAtUtc'] != null
          ? DateTime.tryParse(json['createdAtUtc'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'receiverId': receiverId,
      'conversationId': conversationId,
      'callType': callType,
      'channelName': channelName,
      'agoraAppId': agoraAppId,
      'token': token,
      'createdAtUtc': createdAtUtc.toIso8601String(),
    };
  }
}
