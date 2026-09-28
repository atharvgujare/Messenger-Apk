using Messaging.Application.DTOs.Auth;
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
}
