enum MessageType {
  text,
  image,
  video,
  audio,
  document,
  system,
}

enum MessageStatus {
  pending,
  sent,
  delivered,
  read,
  failed,
}

class MessageReactionModel {
  final String emoji;
  final int count;
  final List<String> userIds;
  final bool hasReacted;

  const MessageReactionModel({
    required this.emoji,
    required this.count,
    required this.userIds,
    required this.hasReacted,
  });

  factory MessageReactionModel.fromJson(Map<String, dynamic> json) {
    return MessageReactionModel(
      emoji: json['emoji']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      userIds: (json['userIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      hasReacted: json['hasReacted'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'emoji': emoji,
    'count': count,
    'userIds': userIds,
    'hasReacted': hasReacted,
  };
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderUsername;
  final String senderDisplayName;
  final MessageType type;
  final String content;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;
  final bool isEdited;
  final bool isDeletedForEveryone;
  final MessageStatus status;
  final String? replyToMessageId;
  final String? replyToSenderUsername;
  final String? replyToSenderDisplayName;
  final String? replyToContent;
  final String? clientGeneratedId;
  final List<MessageReactionModel> reactions;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderUsername,
    required this.senderDisplayName,
    required this.type,
    required this.content,
    required this.createdAtUtc,
    this.updatedAtUtc,
    this.isEdited = false,
    this.isDeletedForEveryone = false,
    this.status = MessageStatus.sent,
    this.replyToMessageId,
    this.replyToSenderUsername,
    this.replyToSenderDisplayName,
    this.replyToContent,
    this.clientGeneratedId,
    this.reactions = const [],
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactions'] as List<dynamic>?;
    final parsedReactions = rawReactions != null
        ? rawReactions.map((r) => MessageReactionModel.fromJson(Map<String, dynamic>.from(r as Map))).toList()
        : <MessageReactionModel>[];

    return MessageModel(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderUsername: json['senderUsername']?.toString() ?? '',
      senderDisplayName: json['senderDisplayName']?.toString() ?? '',
      type: MessageType.values[(json['type'] as int?) ?? 0],
      content: json['content']?.toString() ?? '',
      createdAtUtc: DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      updatedAtUtc: json['updatedAtUtc'] != null ? DateTime.tryParse(json['updatedAtUtc'].toString())?.toLocal() : null,
      isEdited: json['isEdited'] == true,
      isDeletedForEveryone: json['isDeletedForEveryone'] == true,
      status: MessageStatus.values[(json['status'] as int?) ?? 1],
      replyToMessageId: json['replyToMessageId']?.toString(),
      replyToSenderUsername: json['replyToSenderUsername']?.toString(),
      replyToSenderDisplayName: json['replyToSenderDisplayName']?.toString(),
      replyToContent: json['replyToContent']?.toString(),
      clientGeneratedId: json['clientGeneratedId']?.toString(),
      reactions: parsedReactions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderUsername': senderUsername,
      'senderDisplayName': senderDisplayName,
      'type': type.index,
      'content': content,
      'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
      'updatedAtUtc': updatedAtUtc?.toUtc().toIso8601String(),
      'isEdited': isEdited,
      'isDeletedForEveryone': isDeletedForEveryone,
      'status': status.index,
      'replyToMessageId': replyToMessageId,
      'replyToSenderUsername': replyToSenderUsername,
      'replyToSenderDisplayName': replyToSenderDisplayName,
      'replyToContent': replyToContent,
      'clientGeneratedId': clientGeneratedId,
      'reactions': reactions.map((r) => r.toJson()).toList(),
    };
  }

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderUsername,
    String? senderDisplayName,
    MessageType? type,
    String? content,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    bool? isEdited,
    bool? isDeletedForEveryone,
    MessageStatus? status,
    String? replyToMessageId,
    String? replyToSenderUsername,
    String? replyToSenderDisplayName,
    String? replyToContent,
    String? clientGeneratedId,
    List<MessageReactionModel>? reactions,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      type: type ?? this.type,
      content: content ?? this.content,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      isEdited: isEdited ?? this.isEdited,
      isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
      status: status ?? this.status,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToSenderUsername: replyToSenderUsername ?? this.replyToSenderUsername,
      replyToSenderDisplayName: replyToSenderDisplayName ?? this.replyToSenderDisplayName,
      replyToContent: replyToContent ?? this.replyToContent,
      clientGeneratedId: clientGeneratedId ?? this.clientGeneratedId,
      reactions: reactions ?? this.reactions,
    );
  }
}
