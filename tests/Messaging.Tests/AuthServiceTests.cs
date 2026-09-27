using Messaging.Application.Common.Exceptions;
using Messaging.Application.Common.Interfaces;
using Messaging.Application.DTOs.Auth;
using Messaging.Application.Services;
using Messaging.Domain.Entities;
using Moq;
using Xunit;

namespace Messaging.Tests;

public class AuthServiceTests
{
    private readonly Mock<IUserRepository> _userRepoMock = new();
    private readonly Mock<IPasswordHasher> _hasherMock = new();
    private readonly Mock<IJwtTokenService> _tokenServiceMock = new();
    private readonly Mock<IEmailService> _emailServiceMock = new();
    private readonly AuthService _authService;

    public AuthServiceTests()
    {
        _authService = new AuthService(
            _userRepoMock.Object,
            _hasherMock.Object,
            _tokenServiceMock.Object,
            _emailServiceMock.Object);
    }


    [Fact]
    public async Task RegisterAsync_ShouldCreateUserAndReturnTokens_WhenValidRequest()
    {
        var request = new RegisterRequest
        {
            Username = "atharv",
            Email = "atharv@example.com",
            Password = "Password123!",
            DisplayName = "Atharv Gujare"
        };

        _userRepoMock.Setup(r => r.IsUsernameTakenAsync("atharv", It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);
        _userRepoMock.Setup(r => r.IsEmailTakenAsync("atharv@example.com", It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);
        _hasherMock.Setup(h => h.HashPassword("Password123!"))
            .Returns("hashed_password_123");
        _tokenServiceMock.Setup(t => t.GenerateAccessToken(It.IsAny<User>()))
            .Returns(("test_access_token", DateTime.UtcNow.AddMinutes(60)));
        _tokenServiceMock.Setup(t => t.GenerateRefreshToken())
            .Returns("test_refresh_token");

        var response = await _authService.RegisterAsync(request, "127.0.0.1");

        Assert.NotNull(response);
        Assert.Equal("atharv", response.Username);
        Assert.Equal("Atharv Gujare", response.DisplayName);
        Assert.Equal("test_access_token", response.AccessToken);
        Assert.Equal("test_refresh_token", response.RefreshToken);

        _userRepoMock.Verify(r => r.AddUserAsync(It.IsAny<User>(), It.IsAny<CancellationToken>()), Times.Once);
        _userRepoMock.Verify(r => r.AddSessionAsync(It.IsAny<UserSession>(), It.IsAny<CancellationToken>()), Times.Once);
        _userRepoMock.Verify(r => r.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task RegisterAsync_ShouldThrowConflictException_WhenUsernameTaken()
    {
        var request = new RegisterRequest
        {
            Username = "atharv",
            Email = "atharv@example.com",
            Password = "Password123!",
            DisplayName = "Atharv Gujare"
        };

        _userRepoMock.Setup(r => r.IsUsernameTakenAsync("atharv", It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        await Assert.ThrowsAsync<ConflictException>(() => _authService.RegisterAsync(request, null));
    }

    [Fact]
    public async Task RegisterAsync_ShouldThrowConflictException_WhenEmailTaken()
    {
        var request = new RegisterRequest
        {
            Username = "atharv",
            Email = "atharv@example.com",
            Password = "Password123!",
            DisplayName = "Atharv Gujare"
        };

        _userRepoMock.Setup(r => r.IsUsernameTakenAsync("atharv", It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);
        _userRepoMock.Setup(r => r.IsEmailTakenAsync("atharv@example.com", It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        await Assert.ThrowsAsync<ConflictException>(() => _authService.RegisterAsync(request, null));
    }

    [Fact]
    public async Task LoginAsync_ShouldSucceed_WithValidCredentials()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "atharv",
            Email = "atharv@example.com",
            PasswordHash = "hashed_pw",
            IsActive = true,
            Profile = new UserProfile { DisplayName = "Atharv Gujare" }
        };

        _userRepoMock.Setup(r => r.GetByLoginIdentifierAsync("atharv", It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);
        _hasherMock.Setup(h => h.VerifyPassword("Password123!", "hashed_pw"))
            .Returns(true);
        _tokenServiceMock.Setup(t => t.GenerateAccessToken(user))
            .Returns(("access_token_abc", DateTime.UtcNow.AddMinutes(60)));
        _tokenServiceMock.Setup(t => t.GenerateRefreshToken())
            .Returns("refresh_token_xyz");

        var request = new LoginRequest { LoginIdentifier = "atharv", Password = "Password123!" };
        var response = await _authService.LoginAsync(request, "127.0.0.1");

        Assert.NotNull(response);
        Assert.Equal("atharv", response.Username);
        Assert.Equal("access_token_abc", response.AccessToken);
    }

    [Fact]
    public async Task LoginAsync_ShouldThrowUnauthorizedException_WithInvalidPassword()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "atharv",
            PasswordHash = "hashed_pw",
            IsActive = true
        };

        _userRepoMock.Setup(r => r.GetByLoginIdentifierAsync("atharv", It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);
        _hasherMock.Setup(h => h.VerifyPassword("WrongPassword", "hashed_pw"))
            .Returns(false);

        var request = new LoginRequest { LoginIdentifier = "atharv", Password = "WrongPassword" };
        await Assert.ThrowsAsync<UnauthorizedException>(() => _authService.LoginAsync(request, null));
    }

    [Fact]
    public async Task RefreshTokenAsync_ShouldRotateRefreshToken()
    {
        var userId = Guid.NewGuid();
        var session = new UserSession
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            RefreshToken = "old_refresh_token",
            ExpiresAtUtc = DateTime.UtcNow.AddDays(10),
            CreatedAtUtc = DateTime.UtcNow.AddDays(-1)
        };
        var user = new User
        {
            Id = userId,
            Username = "atharv",
            Email = "atharv@example.com",
            IsActive = true,
            Profile = new UserProfile { DisplayName = "Atharv" }
        };

        _userRepoMock.Setup(r => r.GetSessionByRefreshTokenAsync("old_refresh_token", It.IsAny<CancellationToken>()))
            .ReturnsAsync(session);
        _userRepoMock.Setup(r => r.GetByIdAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);
        _tokenServiceMock.Setup(t => t.GenerateRefreshToken())
            .Returns("new_rotated_refresh_token");
        _tokenServiceMock.Setup(t => t.GenerateAccessToken(user))
            .Returns(("new_access_token", DateTime.UtcNow.AddMinutes(60)));

        var request = new RefreshTokenRequest { RefreshToken = "old_refresh_token" };
        var response = await _authService.RefreshTokenAsync(request, "127.0.0.1");

        Assert.NotNull(response);
        Assert.Equal("new_rotated_refresh_token", response.RefreshToken);
        Assert.Equal("new_access_token", response.AccessToken);
        Assert.True(session.IsRevoked);
        Assert.Equal("new_rotated_refresh_token", session.ReplacedByToken);
    }
}
