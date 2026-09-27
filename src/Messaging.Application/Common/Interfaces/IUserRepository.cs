using Messaging.Domain.Entities;

namespace Messaging.Application.Common.Interfaces;

public interface IUserRepository
{
    Task<User?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<User?> GetByUsernameAsync(string username, CancellationToken ct = default);
    Task<User?> GetByEmailAsync(string email, CancellationToken ct = default);
    Task<User?> GetByLoginIdentifierAsync(string identifier, CancellationToken ct = default);
    Task<bool> IsUsernameTakenAsync(string username, CancellationToken ct = default);
    Task<bool> IsEmailTakenAsync(string email, CancellationToken ct = default);
    Task<UserSession?> GetSessionByRefreshTokenAsync(string refreshToken, CancellationToken ct = default);
    Task AddUserAsync(User user, CancellationToken ct = default);
    Task AddSessionAsync(UserSession session, CancellationToken ct = default);
    Task UpdateUserAsync(User user, CancellationToken ct = default);
    Task UpdateSessionAsync(UserSession session, CancellationToken ct = default);
    Task RevokeAllUserSessionsAsync(Guid userId, CancellationToken ct = default);
    Task SaveChangesAsync(CancellationToken ct = default);
}
