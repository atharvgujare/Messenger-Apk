using Messaging.Application.DTOs.Auth;
using Messaging.Application.DTOs.Snaps;
using Messaging.Application.DTOs.Users;

namespace Messaging.Application.Common.Interfaces;

public interface IUserService
{
    Task<IReadOnlyList<UserSearchResultDto>> SearchUsersAsync(
        string query, 
        Guid currentUserId, 
        int limit = 20, 
        CancellationToken ct = default);

    Task<UserProfileDto> GetProfileByIdAsync(
        Guid targetUserId, 
        Guid currentUserId, 
        CancellationToken ct = default);

    Task<UserProfileDto> UpdateProfileAsync(
        Guid userId, 
        UpdateProfileRequest request, 
        CancellationToken ct = default);

    Task DeleteAccountPermanentlyAsync(
        Guid userId, 
        CancellationToken ct = default);

    Task<FollowResponseDto> FollowUserAsync(Guid followerId, Guid followeeId, CancellationToken ct = default);
    Task<bool> UnfollowUserAsync(Guid followerId, Guid followeeId, CancellationToken ct = default);
    Task<bool> AcceptFollowRequestAsync(Guid currentUserId, Guid requestId, CancellationToken ct = default);
    Task<bool> RejectFollowRequestAsync(Guid currentUserId, Guid requestId, CancellationToken ct = default);
    Task<IReadOnlyList<FollowRequestDto>> GetPendingFollowRequestsAsync(Guid currentUserId, CancellationToken ct = default);
    Task<IReadOnlyList<FollowUserDto>> GetFollowersAsync(Guid targetUserId, CancellationToken ct = default);
    Task<IReadOnlyList<FollowUserDto>> GetFollowingAsync(Guid targetUserId, CancellationToken ct = default);
    Task<bool> CanMessageUserAsync(Guid senderId, Guid recipientId, CancellationToken ct = default);

    Task<SnapDto> SendSnapAsync(Guid senderId, Messaging.Application.DTOs.Snaps.CreateSnapRequest request, CancellationToken ct = default);
    Task<IReadOnlyList<SnapDto>> GetActiveSnapsAsync(Guid recipientId, CancellationToken ct = default);
    Task<SnapDto?> OpenSnapAsync(Guid recipientId, Guid snapId, CancellationToken ct = default);
}
