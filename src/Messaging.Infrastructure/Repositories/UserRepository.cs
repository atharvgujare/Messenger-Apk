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

    public async Task SaveChangesAsync(CancellationToken ct = default)
    {
        await _context.SaveChangesAsync(ct);
    }
}
