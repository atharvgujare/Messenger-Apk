using Messaging.Application.Common.Interfaces;
using Messaging.Domain.Entities;
using Messaging.Domain.Enums;
using Messaging.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Messaging.Infrastructure.Repositories;

public class ConversationRepository : IConversationRepository
{
    private readonly AppDbContext _context;

    public ConversationRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<Conversation?> GetDirectConversationAsync(Guid userA, Guid userB, CancellationToken ct = default)
    {
        return await _context.Conversations
            .Include(c => c.Members)
                .ThenInclude(m => m.User)
                    .ThenInclude(u => u.Profile)
            .Include(c => c.LastMessage)
                .ThenInclude(m => m!.Sender)
                    .ThenInclude(s => s.Profile)
            .Where(c => c.Type == ConversationType.Direct &&
                        c.Members.Any(m => m.UserId == userA) &&
                        c.Members.Any(m => m.UserId == userB))
            .FirstOrDefaultAsync(ct);
    }

    public async Task<Conversation?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        return await _context.Conversations
            .Include(c => c.Members)
                .ThenInclude(m => m.User)
                    .ThenInclude(u => u.Profile)
            .Include(c => c.LastMessage)
                .ThenInclude(m => m!.Sender)
                    .ThenInclude(s => s.Profile)
            .FirstOrDefaultAsync(c => c.Id == id, ct);
    }

    public async Task<IReadOnlyList<Conversation>> GetUserConversationsAsync(Guid userId, CancellationToken ct = default)
    {
        return await _context.Conversations
            .Include(c => c.Members)
                .ThenInclude(m => m.User)
                    .ThenInclude(u => u.Profile)
            .Include(c => c.LastMessage)
                .ThenInclude(m => m!.Sender)
                    .ThenInclude(s => s.Profile)
            .Where(c => c.Members.Any(m => m.UserId == userId))
            .OrderByDescending(c => c.UpdatedAtUtc)
            .ToListAsync(ct);
    }

    public async Task AddConversationAsync(Conversation conversation, CancellationToken ct = default)
    {
        await _context.Conversations.AddAsync(conversation, ct);
    }

    public async Task AddMemberAsync(ConversationMember member, CancellationToken ct = default)
    {
        await _context.ConversationMembers.AddAsync(member, ct);
    }

    public Task UpdateConversationAsync(Conversation conversation, CancellationToken ct = default)
    {
        _context.Conversations.Update(conversation);
        return Task.CompletedTask;
    }

    public Task UpdateMemberAsync(ConversationMember member, CancellationToken ct = default)
    {
        _context.ConversationMembers.Update(member);
        return Task.CompletedTask;
    }

    public async Task<bool> IsMemberAsync(Guid conversationId, Guid userId, CancellationToken ct = default)
    {
        return await _context.ConversationMembers
            .AnyAsync(m => m.ConversationId == conversationId && m.UserId == userId, ct);
    }

    public async Task<IReadOnlyList<Guid>> GetMemberUserIdsAsync(Guid conversationId, CancellationToken ct = default)
    {
        return await _context.ConversationMembers
            .Where(m => m.ConversationId == conversationId)
            .Select(m => m.UserId)
            .ToListAsync(ct);
    }

    public async Task SaveChangesAsync(CancellationToken ct = default)
    {
        await _context.SaveChangesAsync(ct);
    }
}
