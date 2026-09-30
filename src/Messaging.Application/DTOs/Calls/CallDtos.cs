namespace Messaging.Application.DTOs.Calls;

public record CallSessionDto(
    Guid CallId,
    Guid CallerId,
    string CallerName,
    string? CallerAvatar,
    Guid ReceiverId,
    Guid ConversationId,
    string CallType,
    string ChannelName,
    string AgoraAppId,
    string Token,
    DateTime CreatedAtUtc
);

public record CallAnswerDto(
    Guid CallId,
    string ChannelName,
    string AgoraAppId,
    string Token
);
