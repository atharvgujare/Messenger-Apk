using Messaging.Application.Common.Exceptions;
using Messaging.Application.Common.Interfaces;
using Messaging.Application.DTOs.Auth;
using Messaging.Application.DTOs.Users;
using Messaging.Domain.Entities;
using Messaging.Domain.Enums;

namespace Messaging.Application.Services;

public class UserService : IUserService
{
    private readonly IUserRepository _userRepository;

    public UserService(IUserRepository userRepository)
    {
        _userRepository = userRepository;
    }

    public async Task<IReadOnlyList<UserSearchResultDto>> SearchUsersAsync(
        string query, 
        Guid currentUserId, 
        int limit = 20, 
        CancellationToken ct = default)
    {
        var cleanQuery = query.Trim().TrimStart('@').ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(cleanQuery))
        {
            return Array.Empty<UserSearchResultDto>();
        }

        var users = await _userRepository.SearchUsersAsync(cleanQuery, currentUserId, limit, ct);

        return users.Select(u =>
        {
            var profile = u.Profile ?? new UserProfile { UserId = u.Id, DisplayName = u.Username };
            var hideLastSeen = profile.LastSeenPrivacy == PrivacyLevel.Nobody;
            var hideAvatar = profile.AvatarPrivacy == PrivacyLevel.Nobody;

            return new UserSearchResultDto
            {
                UserId = u.Id,
                Username = u.Username,
                DisplayName = profile.DisplayName,
                AvatarUrl = hideAvatar ? null : profile.AvatarUrl,
                Bio = profile.Bio,
                IsOnline = hideLastSeen ? false : profile.IsOnline,
                LastSeenAtUtc = hideLastSeen ? null : profile.LastSeenAtUtc
            };
        }).ToList();
    }

    public async Task<UserProfileDto> GetProfileByIdAsync(
        Guid targetUserId, 
        Guid currentUserId, 
        CancellationToken ct = default)
    {
        var user = await _userRepository.GetByIdAsync(targetUserId, ct);
        if (user == null || !user.IsActive)
        {
            throw new NotFoundException("User not found.");
        }

        var profile = user.Profile ?? new UserProfile { UserId = user.Id, DisplayName = user.Username };
        var isSelf = targetUserId == currentUserId;
        var hideLastSeen = !isSelf && profile.LastSeenPrivacy == PrivacyLevel.Nobody;
        var hideAvatar = !isSelf && profile.AvatarPrivacy == PrivacyLevel.Nobody;

        return new UserProfileDto
        {
            UserId = user.Id,
            Username = user.Username,
            DisplayName = profile.DisplayName,
            Email = isSelf ? user.Email : null, // Hide email from other users
            Bio = profile.Bio,
            AvatarUrl = hideAvatar ? null : profile.AvatarUrl,
            IsOnline = hideLastSeen ? false : profile.IsOnline,
            LastSeenAtUtc = hideLastSeen ? null : profile.LastSeenAtUtc,
            CreatedAtUtc = user.CreatedAtUtc,
            LastSeenPrivacy = profile.LastSeenPrivacy,
            AvatarPrivacy = profile.AvatarPrivacy,
            ReadReceiptsEnabled = profile.ReadReceiptsEnabled,
            TypingIndicatorEnabled = profile.TypingIndicatorEnabled
        };
    }

    public async Task<UserProfileDto> UpdateProfileAsync(
        Guid userId, 
        UpdateProfileRequest request, 
        CancellationToken ct = default)
    {
        var user = await _userRepository.GetByIdAsync(userId, ct);
        if (user == null || !user.IsActive)
        {
            throw new NotFoundException("User not found.");
        }

        var profile = user.Profile;
        if (profile == null)
        {
            profile = new UserProfile { UserId = user.Id };
            user.Profile = profile;
        }

        profile.DisplayName = request.DisplayName.Trim();
        if (request.Bio != null) profile.Bio = request.Bio.Trim();
        if (request.AvatarUrl != null) profile.AvatarUrl = request.AvatarUrl.Trim();
        if (request.LastSeenPrivacy.HasValue) profile.LastSeenPrivacy = request.LastSeenPrivacy.Value;
        if (request.AvatarPrivacy.HasValue) profile.AvatarPrivacy = request.AvatarPrivacy.Value;
        if (request.ReadReceiptsEnabled.HasValue) profile.ReadReceiptsEnabled = request.ReadReceiptsEnabled.Value;
        if (request.TypingIndicatorEnabled.HasValue) profile.TypingIndicatorEnabled = request.TypingIndicatorEnabled.Value;

        user.UpdatedAtUtc = DateTime.UtcNow;

        await _userRepository.UpdateUserAsync(user, ct);
        await _userRepository.SaveChangesAsync(ct);

        return new UserProfileDto
        {
            UserId = user.Id,
            Username = user.Username,
            DisplayName = profile.DisplayName,
            Email = user.Email,
            Bio = profile.Bio,
            AvatarUrl = profile.AvatarUrl,
            IsOnline = profile.IsOnline,
            LastSeenAtUtc = profile.LastSeenAtUtc,
            CreatedAtUtc = user.CreatedAtUtc,
            LastSeenPrivacy = profile.LastSeenPrivacy,
            AvatarPrivacy = profile.AvatarPrivacy,
            ReadReceiptsEnabled = profile.ReadReceiptsEnabled,
            TypingIndicatorEnabled = profile.TypingIndicatorEnabled
        };
    }
}
