using Messaging.Domain.Entities;

namespace Messaging.Application.Common.Interfaces;

public interface IMessageRepository
{
    Task<IReadOnlyList<Message>> GetMessagesAsync(
        Guid conversationId, 
        Guid currentUserId,
        DateTime? beforeTimestamp, 
        int limit = 50, 
        CancellationToken ct = default);

    Task<Message?> GetByIdAsync(Guid messageId, CancellationToken ct = default);
    Task AddMessageAsync(Message message, CancellationToken ct = default);
    Task UpdateMessageAsync(Message message, CancellationToken ct = default);
    Task MarkMessageAsDeliveredAsync(Guid messageId, CancellationToken ct = default);
    Task MarkMessagesAsReadAsync(Guid conversationId, Guid readerUserId, DateTime readAtUtc, CancellationToken ct = default);
    Task<int> GetUnreadCountAsync(Guid conversationId, Guid userId, Guid? lastReadMessageId, CancellationToken ct = default);
    Task<MessageReaction?> GetReactionAsync(Guid messageId, Guid userId, string emoji, CancellationToken ct = default);
    Task AddReactionAsync(MessageReaction reaction, CancellationToken ct = default);
    Task RemoveReactionAsync(MessageReaction reaction, CancellationToken ct = default);
    Task<List<MessageReaction>> GetReactionsForMessageAsync(Guid messageId, CancellationToken ct = default);
    Task AddUserDeletionAsync(MessageUserDeletion deletion, CancellationToken ct = default);
    Task<bool> IsDeletedForUserAsync(Guid messageId, Guid userId, CancellationToken ct = default);
    Task SaveChangesAsync(CancellationToken ct = default);
}
