using Messaging.Domain.Entities;

namespace Messaging.Application.Common.Interfaces;

public interface IUserRepository
{
    Task<User?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<User?> GetByUsernameAsync(string username, CancellationToken ct = default);
    Task<User?> GetByEmailAsync(string email, CancellationToken ct = default);
    Task<User?> GetByPhoneNumberAsync(string phoneNumber, CancellationToken ct = default);
    Task<User?> GetByLoginIdentifierAsync(string identifier, CancellationToken ct = default);
    Task<bool> IsUsernameTakenAsync(string username, CancellationToken ct = default);
    Task<bool> IsEmailTakenAsync(string email, CancellationToken ct = default);
    Task<UserSession?> GetSessionByRefreshTokenAsync(string refreshToken, CancellationToken ct = default);
    Task<IReadOnlyList<User>> SearchUsersAsync(string query, Guid currentUserId, int limit = 20, CancellationToken ct = default);
    Task AddUserAsync(User user, CancellationToken ct = default);
    Task AddSessionAsync(UserSession session, CancellationToken ct = default);
    Task UpdateUserAsync(User user, CancellationToken ct = default);
    Task UpdateSessionAsync(UserSession session, CancellationToken ct = default);
    Task RevokeAllUserSessionsAsync(Guid userId, CancellationToken ct = default);
    Task SaveOtpAsync(EmailVerificationOtp otp, CancellationToken ct = default);
    Task<EmailVerificationOtp?> GetValidOtpAsync(string email, string code, CancellationToken ct = default);
    Task InvalidateOtpsForEmailAsync(string email, CancellationToken ct = default);
    Task DeleteUserPermanentlyAsync(Guid userId, CancellationToken ct = default);
    Task<bool> CanMessageUserAsync(Guid senderId, Guid recipientId, CancellationToken ct = default);
    Task<UserFollow?> GetFollowAsync(Guid followerId, Guid followeeId, CancellationToken ct = default);
    Task<UserFollow?> GetFollowRequestByIdAsync(Guid requestId, CancellationToken ct = default);
    Task AddFollowAsync(UserFollow follow, CancellationToken ct = default);
    Task UpdateFollowAsync(UserFollow follow, CancellationToken ct = default);
    Task DeleteFollowAsync(UserFollow follow, CancellationToken ct = default);
    Task<IReadOnlyList<UserFollow>> GetPendingFollowRequestsAsync(Guid userId, CancellationToken ct = default);
    Task<IReadOnlyList<UserFollow>> GetFollowersAsync(Guid userId, CancellationToken ct = default);
    Task<IReadOnlyList<UserFollow>> GetFollowingAsync(Guid userId, CancellationToken ct = default);
    Task<int> GetFollowersCountAsync(Guid userId, CancellationToken ct = default);
    Task<int> GetFollowingCountAsync(Guid userId, CancellationToken ct = default);

    Task SaveChangesAsync(CancellationToken ct = default);
}

