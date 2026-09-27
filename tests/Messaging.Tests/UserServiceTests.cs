using Messaging.Application.Common.Interfaces;
using Messaging.Application.DTOs.Users;
using Messaging.Application.Services;
using Messaging.Domain.Entities;
using Messaging.Domain.Enums;
using Moq;
using Xunit;

namespace Messaging.Tests;

public class UserServiceTests
{
    private readonly Mock<IUserRepository> _userRepoMock = new();
    private readonly UserService _userService;

    public UserServiceTests()
    {
        _userService = new UserService(_userRepoMock.Object);
    }

    [Fact]
    public async Task SearchUsersAsync_ShouldStripAtSymbol_AndReturnResults()
    {
        var currentUserId = Guid.NewGuid();
        var targetUser = new User
        {
            Id = Guid.NewGuid(),
            Username = "rahul",
            Profile = new UserProfile
            {
                DisplayName = "Rahul Sharma",
                IsOnline = true,
                LastSeenPrivacy = PrivacyLevel.Everyone
            }
        };

        _userRepoMock.Setup(r => r.SearchUsersAsync("rahul", currentUserId, 20, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<User> { targetUser });

        var results = await _userService.SearchUsersAsync("@rahul", currentUserId);

        Assert.Single(results);
        Assert.Equal("rahul", results[0].Username);
        Assert.Equal("Rahul Sharma", results[0].DisplayName);
        Assert.True(results[0].IsOnline);

        _userRepoMock.Verify(r => r.SearchUsersAsync("rahul", currentUserId, 20, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SearchUsersAsync_ShouldReturnEmpty_WhenQueryWhitespace()
    {
        var results = await _userService.SearchUsersAsync("   ", Guid.NewGuid());
        Assert.Empty(results);
        _userRepoMock.Verify(r => r.SearchUsersAsync(It.IsAny<string>(), It.IsAny<Guid>(), It.IsAny<int>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task SearchUsersAsync_ShouldMaskLastSeen_WhenPrivacyLevelIsNobody()
    {
        var currentUserId = Guid.NewGuid();
        var targetUser = new User
        {
            Id = Guid.NewGuid(),
            Username = "private_user",
            Profile = new UserProfile
            {
                DisplayName = "Secret Agent",
                IsOnline = true,
                LastSeenAtUtc = DateTime.UtcNow,
                LastSeenPrivacy = PrivacyLevel.Nobody
            }
        };

        _userRepoMock.Setup(r => r.SearchUsersAsync("private", currentUserId, 20, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<User> { targetUser });

        var results = await _userService.SearchUsersAsync("private", currentUserId);

        Assert.Single(results);
        Assert.False(results[0].IsOnline);
        Assert.Null(results[0].LastSeenAtUtc);
    }

    [Fact]
    public async Task GetProfileByIdAsync_ShouldHideEmail_ForOtherUsers()
    {
        var currentUserId = Guid.NewGuid();
        var targetUserId = Guid.NewGuid();
        var targetUser = new User
        {
            Id = targetUserId,
            Username = "rahul",
            Email = "rahul@secret.com",
            IsActive = true,
            Profile = new UserProfile
            {
                DisplayName = "Rahul Sharma",
                LastSeenPrivacy = PrivacyLevel.Everyone
            }
        };

        _userRepoMock.Setup(r => r.GetByIdAsync(targetUserId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(targetUser);

        var profile = await _userService.GetProfileByIdAsync(targetUserId, currentUserId);

        Assert.NotNull(profile);
        Assert.Equal("rahul", profile.Username);
        Assert.Null(profile.Email); // Email must be hidden from other users
    }

    [Fact]
    public async Task UpdateProfileAsync_ShouldUpdateProfileFieldsAndSave()
    {
        var userId = Guid.NewGuid();
        var user = new User
        {
            Id = userId,
            Username = "atharv",
            IsActive = true,
            Profile = new UserProfile
            {
                DisplayName = "Old Name",
                Bio = "Old Bio"
            }
        };

        _userRepoMock.Setup(r => r.GetByIdAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);

        var request = new UpdateProfileRequest
        {
            DisplayName = "Atharv Gujare",
            Bio = "New Engineering Bio",
            LastSeenPrivacy = PrivacyLevel.Contacts
        };

        var updated = await _userService.UpdateProfileAsync(userId, request);

        Assert.Equal("Atharv Gujare", updated.DisplayName);
        Assert.Equal("New Engineering Bio", updated.Bio);
        Assert.Equal(PrivacyLevel.Contacts, updated.LastSeenPrivacy);

        _userRepoMock.Verify(r => r.UpdateUserAsync(user, It.IsAny<CancellationToken>()), Times.Once);
        _userRepoMock.Verify(r => r.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }
}
