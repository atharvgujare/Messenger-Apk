using Messaging.Application.Common.Exceptions;
using Messaging.Application.Common.Interfaces;
using Messaging.Application.DTOs.Auth;
using Messaging.Application.DTOs.Snaps;
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

        var followersCount = await _userRepository.GetFollowersCountAsync(targetUserId, ct);
        var followingCount = await _userRepository.GetFollowingCountAsync(targetUserId, ct);

        string? followStatus = null;
        if (!isSelf)
        {
            var follow = await _userRepository.GetFollowAsync(currentUserId, targetUserId, ct);
            if (follow != null)
            {
                followStatus = follow.Status.ToString().ToLowerInvariant();
            }
        }

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
            TypingIndicatorEnabled = profile.TypingIndicatorEnabled,
            IsPrivate = profile.IsPrivate,
            FollowersCount = followersCount,
            FollowingCount = followingCount,
            FollowStatus = followStatus
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

        if (!string.IsNullOrWhiteSpace(request.DisplayName)) profile.DisplayName = request.DisplayName.Trim();
        if (request.Bio != null) profile.Bio = request.Bio.Trim();
        if (request.AvatarUrl != null) profile.AvatarUrl = string.IsNullOrWhiteSpace(request.AvatarUrl) ? null : request.AvatarUrl.Trim();
        if (request.LastSeenPrivacy.HasValue) profile.LastSeenPrivacy = request.LastSeenPrivacy.Value;
        if (request.AvatarPrivacy.HasValue) profile.AvatarPrivacy = request.AvatarPrivacy.Value;
        if (request.ReadReceiptsEnabled.HasValue) profile.ReadReceiptsEnabled = request.ReadReceiptsEnabled.Value;
        if (request.TypingIndicatorEnabled.HasValue) profile.TypingIndicatorEnabled = request.TypingIndicatorEnabled.Value;
        if (request.IsPrivate.HasValue) profile.IsPrivate = request.IsPrivate.Value;

        user.UpdatedAtUtc = DateTime.UtcNow;

        await _userRepository.UpdateUserAsync(user, ct);
        await _userRepository.SaveChangesAsync(ct);

        var followersCount = await _userRepository.GetFollowersCountAsync(userId, ct);
        var followingCount = await _userRepository.GetFollowingCountAsync(userId, ct);

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
            TypingIndicatorEnabled = profile.TypingIndicatorEnabled,
            IsPrivate = profile.IsPrivate,
            FollowersCount = followersCount,
            FollowingCount = followingCount,
            FollowStatus = null
        };
    }

    public async Task DeleteAccountPermanentlyAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await _userRepository.GetByIdAsync(userId, ct);
        if (user == null)
        {
            throw new NotFoundException("User not found.");
        }

        await _userRepository.DeleteUserPermanentlyAsync(userId, ct);
    }

    public async Task<FollowResponseDto> FollowUserAsync(Guid followerId, Guid followeeId, CancellationToken ct = default)
    {
        if (followerId == followeeId)
        {
            throw new ValidationException("followerId", "You cannot follow yourself.");
        }

        var targetUser = await _userRepository.GetByIdAsync(followeeId, ct);
        if (targetUser == null || !targetUser.IsActive)
        {
            throw new NotFoundException("Target user not found.");
        }

        var existingFollow = await _userRepository.GetFollowAsync(followerId, followeeId, ct);
        if (existingFollow != null)
        {
            if (existingFollow.Status == FollowStatus.Accepted)
            {
                return new FollowResponseDto { Status = "accepted", Message = "You are already following this user." };
            }
            if (existingFollow.Status == FollowStatus.Pending)
            {
                return new FollowResponseDto { Status = "pending", Message = "Follow request already sent." };
            }
            // If rejected previously, reset to new request
            existingFollow.Status = targetUser.Profile?.IsPrivate == true ? FollowStatus.Pending : FollowStatus.Accepted;
            existingFollow.CreatedAtUtc = DateTime.UtcNow;
            await _userRepository.UpdateFollowAsync(existingFollow, ct);
            await _userRepository.SaveChangesAsync(ct);

            return new FollowResponseDto
            {
                Status = existingFollow.Status.ToString().ToLowerInvariant(),
                Message = existingFollow.Status == FollowStatus.Accepted ? "Now following user." : "Follow request sent."
            };
        }

        var isPrivate = targetUser.Profile?.IsPrivate == true;
        var newFollow = new UserFollow
        {
            Id = Guid.NewGuid(),
            FollowerId = followerId,
            FolloweeId = followeeId,
            Status = isPrivate ? FollowStatus.Pending : FollowStatus.Accepted,
            CreatedAtUtc = DateTime.UtcNow
        };

        await _userRepository.AddFollowAsync(newFollow, ct);
        await _userRepository.SaveChangesAsync(ct);

        return new FollowResponseDto
        {
            Status = newFollow.Status.ToString().ToLowerInvariant(),
            Message = isPrivate ? "Follow request sent to private account." : "Now following user."
        };
    }

    public async Task<bool> UnfollowUserAsync(Guid followerId, Guid followeeId, CancellationToken ct = default)
    {
        var existing = await _userRepository.GetFollowAsync(followerId, followeeId, ct);
        if (existing != null)
        {
            await _userRepository.DeleteFollowAsync(existing, ct);
            await _userRepository.SaveChangesAsync(ct);
            return true;
        }
        return false;
    }

    public async Task<bool> AcceptFollowRequestAsync(Guid currentUserId, Guid requestId, CancellationToken ct = default)
    {
        var req = await _userRepository.GetFollowRequestByIdAsync(requestId, ct);
        if (req == null || req.FolloweeId != currentUserId)
        {
            throw new NotFoundException("Follow request not found.");
        }

        req.Status = FollowStatus.Accepted;
        await _userRepository.UpdateFollowAsync(req, ct);
        await _userRepository.SaveChangesAsync(ct);
        return true;
    }

    public async Task<bool> RejectFollowRequestAsync(Guid currentUserId, Guid requestId, CancellationToken ct = default)
    {
        var req = await _userRepository.GetFollowRequestByIdAsync(requestId, ct);
        if (req == null || req.FolloweeId != currentUserId)
        {
            throw new NotFoundException("Follow request not found.");
        }

        await _userRepository.DeleteFollowAsync(req, ct);
        await _userRepository.SaveChangesAsync(ct);
        return true;
    }

    public async Task<IReadOnlyList<FollowRequestDto>> GetPendingFollowRequestsAsync(Guid currentUserId, CancellationToken ct = default)
    {
        var requests = await _userRepository.GetPendingFollowRequestsAsync(currentUserId, ct);
        return requests.Select(r => new FollowRequestDto
        {
            Id = r.Id,
            FollowerId = r.FollowerId,
            FollowerUsername = r.Follower.Username,
            FollowerDisplayName = r.Follower.Profile?.DisplayName ?? r.Follower.Username,
            FollowerAvatarUrl = r.Follower.Profile?.AvatarUrl,
            CreatedAtUtc = r.CreatedAtUtc
        }).ToList();
    }

    public async Task<IReadOnlyList<FollowUserDto>> GetFollowersAsync(Guid targetUserId, CancellationToken ct = default)
    {
        var followers = await _userRepository.GetFollowersAsync(targetUserId, ct);
        return followers.Select(f => new FollowUserDto
        {
            UserId = f.FollowerId,
            Username = f.Follower.Username,
            DisplayName = f.Follower.Profile?.DisplayName ?? f.Follower.Username,
            AvatarUrl = f.Follower.Profile?.AvatarUrl,
            IsOnline = f.Follower.Profile?.IsOnline ?? false
        }).ToList();
    }

    public async Task<IReadOnlyList<FollowUserDto>> GetFollowingAsync(Guid targetUserId, CancellationToken ct = default)
    {
        var following = await _userRepository.GetFollowingAsync(targetUserId, ct);
        return following.Select(f => new FollowUserDto
        {
            UserId = f.FolloweeId,
            Username = f.Followee.Username,
            DisplayName = f.Followee.Profile?.DisplayName ?? f.Followee.Username,
            AvatarUrl = f.Followee.Profile?.AvatarUrl,
            IsOnline = f.Followee.Profile?.IsOnline ?? false
        }).ToList();
    }

    public Task<bool> CanMessageUserAsync(Guid senderId, Guid recipientId, CancellationToken ct = default)
    {
        return _userRepository.CanMessageUserAsync(senderId, recipientId, ct);
    }

    public async Task<SnapDto> SendSnapAsync(Guid senderId, Messaging.Application.DTOs.Snaps.CreateSnapRequest request, CancellationToken ct = default)
    {
        var canMessage = await _userRepository.CanMessageUserAsync(senderId, request.RecipientId, ct);
        if (!canMessage)
        {
            throw new ForbiddenException("Cannot send snap: target account is private and you are not an accepted follower.");
        }

        var sender = await _userRepository.GetByIdAsync(senderId, ct);
        if (sender == null) throw new NotFoundException("Sender not found.");

        var snap = new Snap
        {
            Id = Guid.NewGuid(),
            SenderId = senderId,
            RecipientId = request.RecipientId,
            MediaUrl = request.MediaUrl,
            Caption = request.Caption,
            TimerSeconds = Math.Clamp(request.TimerSeconds, 1, 15),
            IsViewOnce = request.IsViewOnce,
            CreatedAtUtc = DateTime.UtcNow,
            ExpiresAtUtc = DateTime.UtcNow.AddHours(24),
            IsOpened = false
        };

        await _userRepository.AddSnapAsync(snap, ct);

        // Update streak
        var streak = await _userRepository.GetStreakAsync(senderId, request.RecipientId, ct);
        var now = DateTime.UtcNow;
        var u1 = senderId.CompareTo(request.RecipientId) < 0 ? senderId : request.RecipientId;
        var u2 = senderId.CompareTo(request.RecipientId) < 0 ? request.RecipientId : senderId;

        if (streak == null)
        {
            streak = new SnapStreak
            {
                Id = Guid.NewGuid(),
                User1Id = u1,
                User2Id = u2,
                StreakCount = 1,
                LastStreakIncrementUtc = now
            };
            if (senderId == u1) streak.LastSnapUser1Utc = now;
            else streak.LastSnapUser2Utc = now;

            await _userRepository.AddOrUpdateStreakAsync(streak, ct);
        }
        else
        {
            if (senderId == u1) streak.LastSnapUser1Utc = now;
            else streak.LastSnapUser2Utc = now;

            var lastInc = streak.LastStreakIncrementUtc ?? DateTime.MinValue;
            var hoursSinceInc = (now - lastInc).TotalHours;
            if (streak.LastSnapUser1Utc.HasValue && streak.LastSnapUser2Utc.HasValue)
            {
                var diff = Math.Abs((streak.LastSnapUser1Utc.Value - streak.LastSnapUser2Utc.Value).TotalHours);
                if (diff <= 24 && hoursSinceInc >= 20)
                {
                    streak.StreakCount++;
                    streak.LastStreakIncrementUtc = now;
                }
            }
            await _userRepository.AddOrUpdateStreakAsync(streak, ct);
        }


        await _userRepository.SaveChangesAsync(ct);

        return new SnapDto
        {
            Id = snap.Id,
            SenderId = sender.Id,
            SenderUsername = sender.Username,
            SenderDisplayName = sender.Profile?.DisplayName ?? sender.Username,
            SenderAvatarUrl = sender.Profile?.AvatarUrl,
            RecipientId = request.RecipientId,
            MediaUrl = snap.MediaUrl,
            Caption = snap.Caption,
            TimerSeconds = snap.TimerSeconds,
            IsViewOnce = snap.IsViewOnce,
            CreatedAtUtc = snap.CreatedAtUtc,
            IsOpened = snap.IsOpened,
            OpenedAtUtc = snap.OpenedAtUtc,
            StreakCount = streak.StreakCount
        };
    }

    public async Task<IReadOnlyList<SnapDto>> GetActiveSnapsAsync(Guid recipientId, CancellationToken ct = default)
    {
        var snaps = await _userRepository.GetActiveSnapsAsync(recipientId, ct);
        var result = new List<SnapDto>();

        foreach (var s in snaps)
        {
            var streak = await _userRepository.GetStreakAsync(s.SenderId, recipientId, ct);
            result.Add(new SnapDto
            {
                Id = s.Id,
                SenderId = s.SenderId,
                SenderUsername = s.Sender.Username,
                SenderDisplayName = s.Sender.Profile?.DisplayName ?? s.Sender.Username,
                SenderAvatarUrl = s.Sender.Profile?.AvatarUrl,
                RecipientId = s.RecipientId,
                MediaUrl = s.MediaUrl,
                Caption = s.Caption,
                TimerSeconds = s.TimerSeconds,
                IsViewOnce = s.IsViewOnce,
                CreatedAtUtc = s.CreatedAtUtc,
                IsOpened = s.IsOpened,
                OpenedAtUtc = s.OpenedAtUtc,
                StreakCount = streak?.StreakCount ?? 0
            });
        }

        return result;
    }

    public async Task<SnapDto?> OpenSnapAsync(Guid recipientId, Guid snapId, CancellationToken ct = default)
    {
        var snap = await _userRepository.GetSnapByIdAsync(snapId, ct);
        if (snap == null || snap.RecipientId != recipientId) return null;
        if (snap.IsOpened) return null; // Cannot reopen

        snap.IsOpened = true;
        snap.OpenedAtUtc = DateTime.UtcNow;
        await _userRepository.UpdateSnapAsync(snap, ct);
        await _userRepository.SaveChangesAsync(ct);

        var streak = await _userRepository.GetStreakAsync(snap.SenderId, recipientId, ct);

        return new SnapDto
        {
            Id = snap.Id,
            SenderId = snap.SenderId,
            SenderUsername = snap.Sender.Username,
            SenderDisplayName = snap.Sender.Profile?.DisplayName ?? snap.Sender.Username,
            SenderAvatarUrl = snap.Sender.Profile?.AvatarUrl,
            RecipientId = snap.RecipientId,
            MediaUrl = snap.MediaUrl,
            Caption = snap.Caption,
            TimerSeconds = snap.TimerSeconds,
            IsViewOnce = snap.IsViewOnce,
            CreatedAtUtc = snap.CreatedAtUtc,
            IsOpened = snap.IsOpened,
            OpenedAtUtc = snap.OpenedAtUtc,
            StreakCount = streak?.StreakCount ?? 0
        };
    }
}
