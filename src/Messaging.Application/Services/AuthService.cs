using System.Text.RegularExpressions;
using Messaging.Application.Common.Exceptions;
using Messaging.Application.Common.Interfaces;
using Messaging.Application.DTOs.Auth;
using Messaging.Domain.Entities;

namespace Messaging.Application.Services;

public class AuthService : IAuthService
{
    private readonly IUserRepository _userRepository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IJwtTokenService _jwtTokenService;

    private static readonly Regex UsernameRegex = new(@"^[a-zA-Z0-9_.]{3,30}$", RegexOptions.Compiled);

    public AuthService(
        IUserRepository userRepository,
        IPasswordHasher passwordHasher,
        IJwtTokenService jwtTokenService)
    {
        _userRepository = userRepository;
        _passwordHasher = passwordHasher;
        _jwtTokenService = jwtTokenService;
    }

    public async Task<AuthResponse> RegisterAsync(RegisterRequest request, string? ipAddress, CancellationToken ct = default)
    {
        var sanitizedUsername = request.Username.Trim().ToLowerInvariant();
        var sanitizedEmail = request.Email.Trim().ToLowerInvariant();

        if (!UsernameRegex.IsMatch(sanitizedUsername))
        {
            throw new ValidationException("Username", "Username must be 3-30 characters and contain only letters, numbers, underscores, and dots.");
        }

        if (sanitizedUsername.StartsWith('.') || sanitizedUsername.EndsWith('.'))
        {
            throw new ValidationException("Username", "Username cannot start or end with a dot.");
        }

        // Check reserved usernames
        var reserved = new[] { "admin", "administrator", "system", "moderator", "support", "help", "root", "api" };
        if (reserved.Contains(sanitizedUsername))
        {
            throw new ConflictException($"The username '{sanitizedUsername}' is reserved.");
        }

        if (await _userRepository.IsUsernameTakenAsync(sanitizedUsername, ct))
        {
            throw new ConflictException($"The username '{sanitizedUsername}' is already taken.");
        }

        if (await _userRepository.IsEmailTakenAsync(sanitizedEmail, ct))
        {
            throw new ConflictException("An account with this email address already exists.");
        }

        var passwordHash = _passwordHasher.HashPassword(request.Password);

        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = sanitizedUsername,
            Email = sanitizedEmail,
            PasswordHash = passwordHash,
            CreatedAtUtc = DateTime.UtcNow,
            IsActive = true
        };

        var profile = new UserProfile
        {
            UserId = user.Id,
            DisplayName = request.DisplayName.Trim(),
            IsOnline = true,
            LastSeenAtUtc = DateTime.UtcNow
        };
        user.Profile = profile;

        await _userRepository.AddUserAsync(user, ct);

        // Generate tokens
        var (accessToken, accessExpires) = _jwtTokenService.GenerateAccessToken(user);
        var refreshToken = _jwtTokenService.GenerateRefreshToken();

        var session = new UserSession
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            RefreshToken = refreshToken,
            DeviceInfo = "Initial Session",
            IpAddress = ipAddress,
            CreatedAtUtc = DateTime.UtcNow,
            ExpiresAtUtc = DateTime.UtcNow.AddDays(30)
        };

        await _userRepository.AddSessionAsync(session, ct);
        await _userRepository.SaveChangesAsync(ct);

        return BuildAuthResponse(user, profile, accessToken, accessExpires, refreshToken);
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request, string? ipAddress, CancellationToken ct = default)
    {
        var identifier = request.LoginIdentifier.Trim();
        var user = await _userRepository.GetByLoginIdentifierAsync(identifier, ct);

        if (user == null || !user.IsActive)
        {
            throw new UnauthorizedException("Invalid username/email or password.");
        }

        if (!_passwordHasher.VerifyPassword(request.Password, user.PasswordHash))
        {
            throw new UnauthorizedException("Invalid username/email or password.");
        }

        // Generate tokens
        var (accessToken, accessExpires) = _jwtTokenService.GenerateAccessToken(user);
        var refreshToken = _jwtTokenService.GenerateRefreshToken();

        var session = new UserSession
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            RefreshToken = refreshToken,
            DeviceInfo = request.DeviceInfo,
            IpAddress = ipAddress,
            CreatedAtUtc = DateTime.UtcNow,
            ExpiresAtUtc = DateTime.UtcNow.AddDays(30)
        };

        await _userRepository.AddSessionAsync(session, ct);

        if (user.Profile != null)
        {
            user.Profile.IsOnline = true;
            user.Profile.LastSeenAtUtc = DateTime.UtcNow;
            await _userRepository.UpdateUserAsync(user, ct);
        }

        await _userRepository.SaveChangesAsync(ct);

        return BuildAuthResponse(user, user.Profile ?? new UserProfile { UserId = user.Id, DisplayName = user.Username }, accessToken, accessExpires, refreshToken);
    }

    public async Task<AuthResponse> RefreshTokenAsync(RefreshTokenRequest request, string? ipAddress, CancellationToken ct = default)
    {
        var session = await _userRepository.GetSessionByRefreshTokenAsync(request.RefreshToken, ct);

        if (session == null || !session.IsActive)
        {
            throw new UnauthorizedException("Invalid, expired, or revoked refresh token.");
        }

        var user = await _userRepository.GetByIdAsync(session.UserId, ct);
        if (user == null || !user.IsActive)
        {
            throw new UnauthorizedException("User account is inactive or not found.");
        }

        // Rotate token
        var newRefreshToken = _jwtTokenService.GenerateRefreshToken();
        session.RevokedAtUtc = DateTime.UtcNow;
        session.ReplacedByToken = newRefreshToken;
        await _userRepository.UpdateSessionAsync(session, ct);

        var newSession = new UserSession
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            RefreshToken = newRefreshToken,
            DeviceInfo = session.DeviceInfo,
            IpAddress = ipAddress,
            CreatedAtUtc = DateTime.UtcNow,
            ExpiresAtUtc = DateTime.UtcNow.AddDays(30)
        };

        await _userRepository.AddSessionAsync(newSession, ct);

        var (accessToken, accessExpires) = _jwtTokenService.GenerateAccessToken(user);
        await _userRepository.SaveChangesAsync(ct);

        return BuildAuthResponse(user, user.Profile ?? new UserProfile { UserId = user.Id, DisplayName = user.Username }, accessToken, accessExpires, newRefreshToken);
    }

    public async Task LogoutAsync(string refreshToken, CancellationToken ct = default)
    {
        var session = await _userRepository.GetSessionByRefreshTokenAsync(refreshToken, ct);
        if (session != null && session.IsActive)
        {
            session.RevokedAtUtc = DateTime.UtcNow;
            await _userRepository.UpdateSessionAsync(session, ct);
            await _userRepository.SaveChangesAsync(ct);
        }
    }

    public async Task LogoutAllAsync(Guid userId, CancellationToken ct = default)
    {
        await _userRepository.RevokeAllUserSessionsAsync(userId, ct);
        await _userRepository.SaveChangesAsync(ct);
    }

    public async Task<UserProfileDto> GetCurrentUserProfileAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await _userRepository.GetByIdAsync(userId, ct);
        if (user == null)
        {
            throw new NotFoundException("User not found.");
        }

        var profile = user.Profile ?? new UserProfile { UserId = user.Id, DisplayName = user.Username };
        return MapToProfileDto(user, profile);
    }

    private static AuthResponse BuildAuthResponse(
        User user,
        UserProfile profile,
        string accessToken,
        DateTime accessExpires,
        string refreshToken)
    {
        return new AuthResponse
        {
            UserId = user.Id,
            Username = user.Username,
            DisplayName = profile.DisplayName,
            Email = user.Email,
            AccessToken = accessToken,
            RefreshToken = refreshToken,
            ExpiresAtUtc = accessExpires,
            Profile = MapToProfileDto(user, profile)
        };
    }

    private static UserProfileDto MapToProfileDto(User user, UserProfile profile)
    {
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
