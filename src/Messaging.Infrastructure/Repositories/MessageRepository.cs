using Messaging.Application.Common.Interfaces;
using Messaging.Domain.Entities;
using Messaging.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Messaging.Infrastructure.Repositories;

public class MessageRepository : IMessageRepository
{
    private readonly AppDbContext _context;

    public MessageRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<Message>> GetMessagesAsync(
        Guid conversationId, 
        Guid currentUserId,
        DateTime? beforeTimestamp, 
        int limit = 50, 
        CancellationToken ct = default)
    {
        var query = _context.Messages
            .Include(m => m.Sender)
                .ThenInclude(s => s.Profile)
            .Include(m => m.ReplyToMessage)
                .ThenInclude(r => r!.Sender)
                    .ThenInclude(s => s.Profile)
            .Include(m => m.Reactions)
            .Where(m => m.ConversationId == conversationId && 
                        !m.UserDeletions.Any(d => d.UserId == currentUserId));

        if (beforeTimestamp.HasValue)
        {
            query = query.Where(m => m.CreatedAtUtc < beforeTimestamp.Value);
        }

        return await query
            .OrderByDescending(m => m.CreatedAtUtc)
            .Take(limit)
            .ToListAsync(ct);
    }

    public async Task<Message?> GetByIdAsync(Guid messageId, CancellationToken ct = default)
    {
        return await _context.Messages
            .Include(m => m.Sender)
                .ThenInclude(s => s.Profile)
            .Include(m => m.ReplyToMessage)
                .ThenInclude(r => r!.Sender)
                    .ThenInclude(s => s.Profile)
            .Include(m => m.Reactions)
            .FirstOrDefaultAsync(m => m.Id == messageId, ct);
    }

    public async Task AddMessageAsync(Message message, CancellationToken ct = default)
    {
        await _context.Messages.AddAsync(message, ct);
    }

    public Task UpdateMessageAsync(Message message, CancellationToken ct = default)
    {
        _context.Messages.Update(message);
        return Task.CompletedTask;
    }

    public async Task<MessageReaction?> GetReactionAsync(Guid messageId, Guid userId, string emoji, CancellationToken ct = default)
    {
        return await _context.MessageReactions
            .FirstOrDefaultAsync(r => r.MessageId == messageId && r.UserId == userId && r.Emoji == emoji, ct);
    }

    public async Task AddReactionAsync(MessageReaction reaction, CancellationToken ct = default)
    {
        await _context.MessageReactions.AddAsync(reaction, ct);
    }

    public Task RemoveReactionAsync(MessageReaction reaction, CancellationToken ct = default)
    {
        _context.MessageReactions.Remove(reaction);
        return Task.CompletedTask;
    }

    public async Task<List<MessageReaction>> GetReactionsForMessageAsync(Guid messageId, CancellationToken ct = default)
    {
        return await _context.MessageReactions
            .Where(r => r.MessageId == messageId)
            .ToListAsync(ct);
    }

    public async Task AddUserDeletionAsync(MessageUserDeletion deletion, CancellationToken ct = default)
    {
        await _context.MessageUserDeletions.AddAsync(deletion, ct);
    }

    public async Task<bool> IsDeletedForUserAsync(Guid messageId, Guid userId, CancellationToken ct = default)
    {
        return await _context.MessageUserDeletions
            .AnyAsync(d => d.MessageId == messageId && d.UserId == userId, ct);
    }

    public async Task MarkMessageAsDeliveredAsync(Guid messageId, CancellationToken ct = default)
    {
        var message = await _context.Messages.FirstOrDefaultAsync(m => m.Id == messageId, ct);
        if (message != null && message.Status == Domain.Enums.MessageStatus.Sent)
        {
            message.Status = Domain.Enums.MessageStatus.Delivered;
            await _context.SaveChangesAsync(ct);
        }
    }

    public async Task MarkMessagesAsReadAsync(Guid conversationId, Guid readerUserId, DateTime readAtUtc, CancellationToken ct = default)
    {
        var messages = await _context.Messages
            .Where(m => m.ConversationId == conversationId && 
                        m.SenderId != readerUserId && 
                        m.Status < Domain.Enums.MessageStatus.Read &&
                        m.CreatedAtUtc <= readAtUtc)
            .ToListAsync(ct);

        if (messages.Count > 0)
        {
            foreach (var m in messages)
            {
                m.Status = Domain.Enums.MessageStatus.Read;
            }
            await _context.SaveChangesAsync(ct);
        }
    }

    public async Task<int> GetUnreadCountAsync(
        Guid conversationId, 
        Guid userId, 
        Guid? lastReadMessageId, 
        CancellationToken ct = default)
    {
        if (lastReadMessageId == null)
        {
            return await _context.Messages
                .CountAsync(m => m.ConversationId == conversationId && m.SenderId != userId && !m.IsDeletedForEveryone, ct);
        }

        var lastReadMsg = await _context.Messages
            .FirstOrDefaultAsync(m => m.Id == lastReadMessageId.Value, ct);

        if (lastReadMsg == null)
        {
            return 0;
        }

        return await _context.Messages
            .CountAsync(m => m.ConversationId == conversationId && 
                             m.SenderId != userId && 
                             m.CreatedAtUtc > lastReadMsg.CreatedAtUtc && 
                             !m.IsDeletedForEveryone, ct);
    }

    public async Task SaveChangesAsync(CancellationToken ct = default)
    {
        await _context.SaveChangesAsync(ct);
    }
}
