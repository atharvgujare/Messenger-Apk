import 'message_model.dart';
import '../../users/models/user_search_model.dart';

enum ConversationType {
  direct,
  group,
  channel,
}

class ConversationModel {
  final String conversationId;
  final ConversationType type;
  final String title;
  final String? avatarUrl;
  final bool isPinned;
  final bool isMuted;
  final bool isArchived;
  final int unreadCount;
  final DateTime updatedAtUtc;
  final MessageModel? lastMessage;
  final UserSearchResultModel? otherParticipant;

  const ConversationModel({
    required this.conversationId,
    required this.type,
    required this.title,
    this.avatarUrl,
    this.isPinned = false,
    this.isMuted = false,
    this.isArchived = false,
    this.unreadCount = 0,
    required this.updatedAtUtc,
    this.lastMessage,
    this.otherParticipant,
  });

  String get initials {
    if (title.isEmpty) return '?';
    final parts = title.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return title[0].toUpperCase();
  }

  UserSearchResultModel? getOtherMember(String currentUserId) {
    return otherParticipant;
  }


  static ConversationType _parseType(dynamic value) {
    if (value is int) {
      switch (value) {
        case 1:
          return ConversationType.direct;
        case 2:
          return ConversationType.group;
        case 3:
          return ConversationType.channel;
        default:
          return ConversationType.direct;
      }
    }
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'group':
          return ConversationType.group;
        case 'channel':
        case 'savedmessages':
          return ConversationType.channel;
        default:
          return ConversationType.direct;
      }
    }
    return ConversationType.direct;
  }

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      conversationId: json['conversationId']?.toString() ?? '',
      type: _parseType(json['type']),
      title: json['title']?.toString() ?? 'Conversation',
      avatarUrl: json['avatarUrl']?.toString(),
      isPinned: json['isPinned'] == true,
      isMuted: json['isMuted'] == true,
      isArchived: json['isArchived'] == true,
      unreadCount: (json['unreadCount'] as int?) ?? 0,
      updatedAtUtc: DateTime.tryParse(json['updatedAtUtc']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      lastMessage: json['lastMessage'] != null
          ? MessageModel.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      otherParticipant: json['otherParticipant'] != null
          ? UserSearchResultModel.fromJson(json['otherParticipant'] as Map<String, dynamic>)
          : null,
    );
  }

  ConversationModel copyWith({
    String? conversationId,
    ConversationType? type,
    String? title,
    String? avatarUrl,
    bool? isPinned,
    bool? isMuted,
    bool? isArchived,
    int? unreadCount,
    DateTime? updatedAtUtc,
    MessageModel? lastMessage,
    UserSearchResultModel? otherParticipant,
  }) {
    return ConversationModel(
      conversationId: conversationId ?? this.conversationId,
      type: type ?? this.type,
      title: title ?? this.title,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isArchived: isArchived ?? this.isArchived,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      lastMessage: lastMessage ?? this.lastMessage,
      otherParticipant: otherParticipant ?? this.otherParticipant,
    );
  }
}
