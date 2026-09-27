using Messaging.Domain.Entities;

namespace Messaging.Application.Common.Interfaces;

public interface IConversationRepository
{
    Task<Conversation?> GetDirectConversationAsync(Guid userA, Guid userB, CancellationToken ct = default);
    Task<Conversation?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<IReadOnlyList<Conversation>> GetUserConversationsAsync(Guid userId, CancellationToken ct = default);
    Task AddConversationAsync(Conversation conversation, CancellationToken ct = default);
    Task AddMemberAsync(ConversationMember member, CancellationToken ct = default);
    Task UpdateConversationAsync(Conversation conversation, CancellationToken ct = default);
    Task UpdateMemberAsync(ConversationMember member, CancellationToken ct = default);
    Task<bool> IsMemberAsync(Guid conversationId, Guid userId, CancellationToken ct = default);
    Task<IReadOnlyList<Guid>> GetMemberUserIdsAsync(Guid conversationId, CancellationToken ct = default);
    Task SaveChangesAsync(CancellationToken ct = default);
}
