using Messaging.Application.DTOs.Chats;

namespace Messaging.Application.Common.Interfaces;

public interface IChatService
{
    Task<ConversationDto> GetOrCreateDirectConversationAsync(
        Guid currentUserId, 
        Guid recipientUserId, 
        CancellationToken ct = default);

    Task<IReadOnlyList<ConversationDto>> GetUserConversationsAsync(
        Guid currentUserId, 
        CancellationToken ct = default);

    Task<IReadOnlyList<MessageDto>> GetConversationMessagesAsync(
        Guid conversationId, 
        Guid currentUserId, 
        DateTime? beforeTimestamp = null, 
        int limit = 50, 
        CancellationToken ct = default);

    Task<MessageDto> SendMessageAsync(
        Guid senderId, 
        SendMessageRequest request, 
        CancellationToken ct = default);

    Task<IReadOnlyList<Guid>> GetConversationParticipantUserIdsAsync(
        Guid conversationId, 
        CancellationToken ct = default);
}
