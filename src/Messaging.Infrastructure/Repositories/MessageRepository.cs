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
        DateTime? beforeTimestamp, 
        int limit = 50, 
        CancellationToken ct = default)
    {
        var query = _context.Messages
            .Include(m => m.Sender)
                .ThenInclude(s => s.Profile)
            .Include(m => m.ReplyToMessage)
            .Where(m => m.ConversationId == conversationId && !m.IsDeletedForEveryone);

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
