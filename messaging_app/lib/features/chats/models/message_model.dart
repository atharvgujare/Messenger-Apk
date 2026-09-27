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

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderUsername;
  final String senderDisplayName;
  final MessageType type;
  final String content;
  final DateTime createdAtUtc;
  final bool isEdited;
  final MessageStatus status;
  final String? replyToMessageId;
  final String? clientGeneratedId;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderUsername,
    required this.senderDisplayName,
    required this.type,
    required this.content,
    required this.createdAtUtc,
    this.isEdited = false,
    this.status = MessageStatus.sent,
    this.replyToMessageId,
    this.clientGeneratedId,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderUsername: json['senderUsername']?.toString() ?? '',
      senderDisplayName: json['senderDisplayName']?.toString() ?? '',
      type: MessageType.values[(json['type'] as int?) ?? 0],
      content: json['content']?.toString() ?? '',
      createdAtUtc: DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      isEdited: json['isEdited'] == true,
      status: MessageStatus.values[(json['status'] as int?) ?? 1],
      replyToMessageId: json['replyToMessageId']?.toString(),
      clientGeneratedId: json['clientGeneratedId']?.toString(),
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
      'isEdited': isEdited,
      'status': status.index,
      'replyToMessageId': replyToMessageId,
      'clientGeneratedId': clientGeneratedId,
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
    bool? isEdited,
    MessageStatus? status,
    String? replyToMessageId,
    String? clientGeneratedId,
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
      isEdited: isEdited ?? this.isEdited,
      status: status ?? this.status,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      clientGeneratedId: clientGeneratedId ?? this.clientGeneratedId,
    );
  }
}
