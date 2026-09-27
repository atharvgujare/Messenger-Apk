using Messaging.Domain.Entities;

namespace Messaging.Application.Common.Interfaces;

public interface IMessageRepository
{
    Task<IReadOnlyList<Message>> GetMessagesAsync(
        Guid conversationId, 
        DateTime? beforeTimestamp, 
        int limit = 50, 
        CancellationToken ct = default);

    Task<Message?> GetByIdAsync(Guid messageId, CancellationToken ct = default);
    Task AddMessageAsync(Message message, CancellationToken ct = default);
    Task UpdateMessageAsync(Message message, CancellationToken ct = default);
    Task<int> GetUnreadCountAsync(Guid conversationId, Guid userId, Guid? lastReadMessageId, CancellationToken ct = default);
    Task SaveChangesAsync(CancellationToken ct = default);
}
