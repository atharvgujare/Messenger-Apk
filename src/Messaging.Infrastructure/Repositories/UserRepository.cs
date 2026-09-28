using Messaging.Application.Common.Interfaces;
using Messaging.Domain.Entities;
using Messaging.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace Messaging.Infrastructure.Repositories;

public class UserRepository : IUserRepository
{
    private readonly AppDbContext _context;

    public UserRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<User?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        return await _context.Users
            .Include(u => u.Profile)
            .FirstOrDefaultAsync(u => u.Id == id, ct);
    }

    public async Task<User?> GetByUsernameAsync(string username, CancellationToken ct = default)
    {
        var normalized = username.Trim().ToLowerInvariant();
        return await _context.Users
            .Include(u => u.Profile)
            .FirstOrDefaultAsync(u => u.Username.ToLower() == normalized, ct);
    }

    public async Task<User?> GetByEmailAsync(string email, CancellationToken ct = default)
    {
        var normalized = email.Trim().ToLowerInvariant();
        return await _context.Users
            .Include(u => u.Profile)
            .FirstOrDefaultAsync(u => u.Email.ToLower() == normalized, ct);
    }

    public async Task<User?> GetByLoginIdentifierAsync(string identifier, CancellationToken ct = default)
    {
        var normalized = identifier.Trim().ToLowerInvariant();
        return await _context.Users
            .Include(u => u.Profile)
            .FirstOrDefaultAsync(u => u.Username.ToLower() == normalized || u.Email.ToLower() == normalized, ct);
    }

    public async Task<bool> IsUsernameTakenAsync(string username, CancellationToken ct = default)
    {
        var normalized = username.Trim().ToLowerInvariant();
        return await _context.Users.AnyAsync(u => u.Username.ToLower() == normalized, ct);
    }

    public async Task<bool> IsEmailTakenAsync(string email, CancellationToken ct = default)
    {
        var normalized = email.Trim().ToLowerInvariant();
        return await _context.Users.AnyAsync(u => u.Email.ToLower() == normalized, ct);
    }

    public async Task<IReadOnlyList<User>> SearchUsersAsync(string query, Guid currentUserId, int limit = 20, CancellationToken ct = default)
    {
        var normalized = query.Trim().ToLowerInvariant();
        return await _context.Users
            .Include(u => u.Profile)
            .Where(u => u.Id != currentUserId && u.IsActive && 
                   (u.Username.ToLower().Contains(normalized) || 
                   (u.Profile != null && u.Profile.DisplayName.ToLower().Contains(normalized))))
            .OrderBy(u => u.Username.ToLower().StartsWith(normalized) ? 0 : 1)
            .ThenBy(u => u.Username)
            .Take(limit)
            .ToListAsync(ct);
    }

    public async Task<UserSession?> GetSessionByRefreshTokenAsync(string refreshToken, CancellationToken ct = default)
    {
        return await _context.UserSessions
            .Include(s => s.User)
                .ThenInclude(u => u.Profile)
            .FirstOrDefaultAsync(s => s.RefreshToken == refreshToken, ct);
    }

    public async Task AddUserAsync(User user, CancellationToken ct = default)
    {
        await _context.Users.AddAsync(user, ct);
    }

    public async Task AddSessionAsync(UserSession session, CancellationToken ct = default)
    {
        await _context.UserSessions.AddAsync(session, ct);
    }

    public Task UpdateUserAsync(User user, CancellationToken ct = default)
    {
        _context.Users.Update(user);
        return Task.CompletedTask;
    }

    public Task UpdateSessionAsync(UserSession session, CancellationToken ct = default)
    {
        _context.UserSessions.Update(session);
        return Task.CompletedTask;
    }

    public async Task RevokeAllUserSessionsAsync(Guid userId, CancellationToken ct = default)
    {
        var activeSessions = await _context.UserSessions
            .Where(s => s.UserId == userId && s.RevokedAtUtc == null && s.ExpiresAtUtc > DateTime.UtcNow)
            .ToListAsync(ct);

        foreach (var session in activeSessions)
        {
            session.RevokedAtUtc = DateTime.UtcNow;
        }
    }

    public async Task SaveOtpAsync(EmailVerificationOtp otp, CancellationToken ct = default)
    {
        await _context.EmailVerificationOtps.AddAsync(otp, ct);
    }

    public async Task<EmailVerificationOtp?> GetValidOtpAsync(string email, string code, CancellationToken ct = default)
    {
        var sanitized = email.Trim().ToLowerInvariant();
        return await _context.EmailVerificationOtps
            .Where(o => o.Email == sanitized && o.OtpCode == code && !o.IsUsed && o.ExpiresAtUtc > DateTime.UtcNow)
            .OrderByDescending(o => o.CreatedAtUtc)
            .FirstOrDefaultAsync(ct);
    }

    public async Task InvalidateOtpsForEmailAsync(string email, CancellationToken ct = default)
    {
        var sanitized = email.Trim().ToLowerInvariant();
        var pending = await _context.EmailVerificationOtps
            .Where(o => o.Email == sanitized && !o.IsUsed)
            .ToListAsync(ct);

        foreach (var otp in pending)
        {
            otp.IsUsed = true;
        }
    }

    public async Task DeleteUserPermanentlyAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await _context.Users
            .Include(u => u.Profile)
            .FirstOrDefaultAsync(u => u.Id == userId, ct);

        if (user == null) return;

        // 1. Delete reactions by user
        var reactions = await _context.MessageReactions
            .Where(r => r.UserId == userId)
            .ToListAsync(ct);
        _context.MessageReactions.RemoveRange(reactions);

        // 2. Delete message user deletions
        var deletions = await _context.MessageUserDeletions
            .Where(d => d.UserId == userId)
            .ToListAsync(ct);
        _context.MessageUserDeletions.RemoveRange(deletions);

        // 3. Unlink conversations where LastMessage was sent by this user
        var convsWithLastMessage = await _context.Conversations
            .Where(c => c.LastMessage != null && c.LastMessage.SenderId == userId)
            .ToListAsync(ct);
        foreach (var conv in convsWithLastMessage)
        {
            conv.LastMessageId = null;
        }

        // 4. Unlink replies pointing to messages sent by this user
        var userMessageIds = await _context.Messages
            .Where(m => m.SenderId == userId)
            .Select(m => m.Id)
            .ToListAsync(ct);

        if (userMessageIds.Count > 0)
        {
            var repliesToUser = await _context.Messages
                .Where(m => m.ReplyToMessageId != null && userMessageIds.Contains(m.ReplyToMessageId.Value))
                .ToListAsync(ct);
            foreach (var reply in repliesToUser)
            {
                reply.ReplyToMessageId = null;
            }

            // 5. Delete all reactions on user's messages
            var reactionsOnUserMsgs = await _context.MessageReactions
                .Where(r => userMessageIds.Contains(r.MessageId))
                .ToListAsync(ct);
            _context.MessageReactions.RemoveRange(reactionsOnUserMsgs);

            // 6. Delete all message user deletions on user's messages
            var deletionsOnUserMsgs = await _context.MessageUserDeletions
                .Where(d => userMessageIds.Contains(d.MessageId))
                .ToListAsync(ct);
            _context.MessageUserDeletions.RemoveRange(deletionsOnUserMsgs);

            // 7. Delete messages sent by this user
            var userMessages = await _context.Messages
                .Where(m => m.SenderId == userId)
                .ToListAsync(ct);
            _context.Messages.RemoveRange(userMessages);
        }

        // 8. Delete conversation memberships
        var memberships = await _context.ConversationMembers
            .Where(m => m.UserId == userId)
            .ToListAsync(ct);
        _context.ConversationMembers.RemoveRange(memberships);

        // 9. Delete user sessions
        var sessions = await _context.UserSessions
            .Where(s => s.UserId == userId)
            .ToListAsync(ct);
        _context.UserSessions.RemoveRange(sessions);

        // 10. Delete pending OTPs
        if (!string.IsNullOrWhiteSpace(user.Email))
        {
            var normalizedEmail = user.Email.Trim().ToLowerInvariant();
            var otps = await _context.EmailVerificationOtps
                .Where(o => o.Email == normalizedEmail)
                .ToListAsync(ct);
            _context.EmailVerificationOtps.RemoveRange(otps);
        }

        // 11. Delete profile
        if (user.Profile != null)
        {
            _context.UserProfiles.Remove(user.Profile);
        }

        // 12. Delete user
        _context.Users.Remove(user);

        await _context.SaveChangesAsync(ct);
    }

    public async Task<bool> CanMessageUserAsync(Guid senderId, Guid recipientId, CancellationToken ct = default)
    {
        if (senderId == recipientId) return true;

        var recipient = await _context.Users
            .Include(u => u.Profile)
            .FirstOrDefaultAsync(u => u.Id == recipientId, ct);

        if (recipient == null) return false;

        // If recipient profile is public (not private), anyone can message
        if (recipient.Profile?.IsPrivate != true) return true;

        // If recipient profile is private, verify sender is an accepted follower
        return await _context.UserFollows.AnyAsync(f =>
            f.FollowerId == senderId &&
            f.FolloweeId == recipientId &&
            f.Status == FollowStatus.Accepted, ct);
    }

    public async Task<UserFollow?> GetFollowAsync(Guid followerId, Guid followeeId, CancellationToken ct = default)
    {
        return await _context.UserFollows
            .FirstOrDefaultAsync(f => f.FollowerId == followerId && f.FolloweeId == followeeId, ct);
    }

    public async Task<UserFollow?> GetFollowRequestByIdAsync(Guid requestId, CancellationToken ct = default)
    {
        return await _context.UserFollows
            .Include(f => f.Follower)
            .ThenInclude(u => u.Profile)
            .FirstOrDefaultAsync(f => f.Id == requestId, ct);
    }

    public async Task AddFollowAsync(UserFollow follow, CancellationToken ct = default)
    {
        await _context.UserFollows.AddAsync(follow, ct);
    }

    public Task UpdateFollowAsync(UserFollow follow, CancellationToken ct = default)
    {
        _context.UserFollows.Update(follow);
        return Task.CompletedTask;
    }

    public Task DeleteFollowAsync(UserFollow follow, CancellationToken ct = default)
    {
        _context.UserFollows.Remove(follow);
        return Task.CompletedTask;
    }

    public async Task<IReadOnlyList<UserFollow>> GetPendingFollowRequestsAsync(Guid userId, CancellationToken ct = default)
    {
        return await _context.UserFollows
            .Include(f => f.Follower)
            .ThenInclude(u => u.Profile)
            .Where(f => f.FolloweeId == userId && f.Status == FollowStatus.Pending)
            .OrderByDescending(f => f.CreatedAtUtc)
            .ToListAsync(ct);
    }

    public async Task<IReadOnlyList<UserFollow>> GetFollowersAsync(Guid userId, CancellationToken ct = default)
    {
        return await _context.UserFollows
            .Include(f => f.Follower)
            .ThenInclude(u => u.Profile)
            .Where(f => f.FolloweeId == userId && f.Status == FollowStatus.Accepted)
            .OrderByDescending(f => f.CreatedAtUtc)
            .ToListAsync(ct);
    }

    public async Task<IReadOnlyList<UserFollow>> GetFollowingAsync(Guid userId, CancellationToken ct = default)
    {
        return await _context.UserFollows
            .Include(f => f.Followee)
            .ThenInclude(u => u.Profile)
            .Where(f => f.FollowerId == userId && f.Status == FollowStatus.Accepted)
            .OrderByDescending(f => f.CreatedAtUtc)
            .ToListAsync(ct);
    }

    public async Task<int> GetFollowersCountAsync(Guid userId, CancellationToken ct = default)
    {
        return await _context.UserFollows
            .CountAsync(f => f.FolloweeId == userId && f.Status == FollowStatus.Accepted, ct);
    }

    public async Task<int> GetFollowingCountAsync(Guid userId, CancellationToken ct = default)
    {
        return await _context.UserFollows
            .CountAsync(f => f.FollowerId == userId && f.Status == FollowStatus.Accepted, ct);
    }

    public async Task AddSnapAsync(Snap snap, CancellationToken ct = default)
    {
        await _context.Snaps.AddAsync(snap, ct);
    }

    public async Task<Snap?> GetSnapByIdAsync(Guid snapId, CancellationToken ct = default)
    {
        return await _context.Snaps
            .Include(s => s.Sender)
            .ThenInclude(u => u.Profile)
            .FirstOrDefaultAsync(s => s.Id == snapId, ct);
    }

    public async Task<IReadOnlyList<Snap>> GetActiveSnapsAsync(Guid recipientId, CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        return await _context.Snaps
            .Include(s => s.Sender)
            .ThenInclude(u => u.Profile)
            .Where(s => s.RecipientId == recipientId && !s.IsOpened && s.ExpiresAtUtc > now)
            .OrderByDescending(s => s.CreatedAtUtc)
            .ToListAsync(ct);
    }

    public Task UpdateSnapAsync(Snap snap, CancellationToken ct = default)
    {
        _context.Snaps.Update(snap);
        return Task.CompletedTask;
    }

    public async Task<SnapStreak?> GetStreakAsync(Guid user1Id, Guid user2Id, CancellationToken ct = default)
    {
        var min = user1Id.CompareTo(user2Id) < 0 ? user1Id : user2Id;
        var max = user1Id.CompareTo(user2Id) < 0 ? user2Id : user1Id;
        return await _context.SnapStreaks
            .FirstOrDefaultAsync(s => s.User1Id == min && s.User2Id == max, ct);
    }

    public async Task AddOrUpdateStreakAsync(SnapStreak streak, CancellationToken ct = default)
    {
        var existing = await _context.SnapStreaks.FindAsync(new object[] { streak.Id }, ct);
        if (existing == null)
        {
            await _context.SnapStreaks.AddAsync(streak, ct);
        }
        else
        {
            _context.SnapStreaks.Update(streak);
        }
    }

    public async Task SaveChangesAsync(CancellationToken ct = default)
    {
        await _context.SaveChangesAsync(ct);
    }
}

