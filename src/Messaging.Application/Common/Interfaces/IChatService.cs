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

    Task MarkMessageDeliveredAsync(
        Guid messageId, 
        Guid recipientUserId, 
        CancellationToken ct = default);

    Task<DateTime> MarkConversationReadAsync(
        Guid conversationId, 
        Guid readerUserId, 
        CancellationToken ct = default);

    Task<MessageDto> EditMessageAsync(
        Guid messageId, 
        Guid userId, 
        string newContent, 
        CancellationToken ct = default);

    Task<bool> DeleteMessageAsync(
        Guid messageId, 
        Guid userId, 
        bool forEveryone, 
        CancellationToken ct = default);

    Task<List<MessageReactionDto>> ToggleReactionAsync(
        Guid messageId, 
        Guid userId, 
        string emoji, 
        CancellationToken ct = default);

    Task<ConversationDto> CreateGroupConversationAsync(
        Guid creatorUserId, 
        CreateGroupRequest request, 
        CancellationToken ct = default);

    Task<bool> TogglePinConversationAsync(
        Guid conversationId, 
        Guid userId, 
        CancellationToken ct = default);
}

