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
    private readonly IEmailService _emailService;

    private static readonly Regex UsernameRegex = new(@"^[a-zA-Z0-9_.]{3,30}$", RegexOptions.Compiled);

    public AuthService(
        IUserRepository userRepository,
        IPasswordHasher passwordHasher,
        IJwtTokenService jwtTokenService,
        IEmailService emailService)
    {
        _userRepository = userRepository;
        _passwordHasher = passwordHasher;
        _jwtTokenService = jwtTokenService;
        _emailService = emailService;
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

    public async Task<string> SendOtpAsync(string email, CancellationToken ct = default)
    {
        var sanitizedEmail = email.Trim().ToLowerInvariant();

        if (await _userRepository.IsEmailTakenAsync(sanitizedEmail, ct))
        {
            throw new ConflictException("An account with this email address already exists. Only one account can be created using one email.");
        }

        // Invalidate old OTPs
        await _userRepository.InvalidateOtpsForEmailAsync(sanitizedEmail, ct);

        // Generate 6-digit OTP
        var otpCode = Random.Shared.Next(100000, 999999).ToString();
        var otp = new EmailVerificationOtp
        {
            Id = Guid.NewGuid(),
            Email = sanitizedEmail,
            OtpCode = otpCode,
            CreatedAtUtc = DateTime.UtcNow,
            ExpiresAtUtc = DateTime.UtcNow.AddMinutes(10),
            IsUsed = false
        };

        await _userRepository.SaveOtpAsync(otp, ct);
        await _userRepository.SaveChangesAsync(ct);

        // Attempt sending email via Brevo/Resend HTTPS API or SMTP without blocking
        try
        {
            using var timeoutCts = new CancellationTokenSource(TimeSpan.FromSeconds(15));
            using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(ct, timeoutCts.Token);
            await _emailService.SendOtpEmailAsync(sanitizedEmail, otpCode, linkedCts.Token);
        }
        catch (Exception ex)
        {
            System.Console.WriteLine($"[EMAIL NOTICE] Outbound email attempt notice: {ex.Message}");
        }

        return otpCode;
    }

    public async Task<string> ForgotPasswordAsync(string email, CancellationToken ct = default)
    {
        var sanitizedEmail = email.Trim().ToLowerInvariant();

        var user = await _userRepository.GetByEmailAsync(sanitizedEmail, ct);
        if (user == null || !user.IsActive)
        {
            throw new NotFoundException("No account found registered with this email address.");
        }

        // Invalidate old OTPs
        await _userRepository.InvalidateOtpsForEmailAsync(sanitizedEmail, ct);

        // Generate 6-digit OTP
        var otpCode = Random.Shared.Next(100000, 999999).ToString();
        var otp = new EmailVerificationOtp
        {
            Id = Guid.NewGuid(),
            Email = sanitizedEmail,
            OtpCode = otpCode,
            CreatedAtUtc = DateTime.UtcNow,
            ExpiresAtUtc = DateTime.UtcNow.AddMinutes(10),
            IsUsed = false
        };

        await _userRepository.SaveOtpAsync(otp, ct);
        await _userRepository.SaveChangesAsync(ct);

        try
        {
            using var timeoutCts = new CancellationTokenSource(TimeSpan.FromSeconds(15));
            using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(ct, timeoutCts.Token);
            await _emailService.SendPasswordResetEmailAsync(sanitizedEmail, otpCode, linkedCts.Token);
        }
        catch (Exception ex)
        {
            System.Console.WriteLine($"[PASSWORD RESET NOTICE] Outbound email notice: {ex.Message}");
        }

        return otpCode;
    }

    public async Task ResetPasswordAsync(ResetPasswordRequest request, CancellationToken ct = default)
    {
        var sanitizedEmail = request.Email.Trim().ToLowerInvariant();

        var otp = await _userRepository.GetValidOtpAsync(sanitizedEmail, request.OtpCode.Trim(), ct);
        if (otp == null)
        {
            throw new ValidationException("OtpCode", "Invalid or expired password reset verification code.");
        }

        var user = await _userRepository.GetByEmailAsync(sanitizedEmail, ct);
        if (user == null || !user.IsActive)
        {
            throw new NotFoundException("No user found with this email address.");
        }

        otp.IsUsed = true;
        otp.UsedAtUtc = DateTime.UtcNow;

        user.PasswordHash = _passwordHasher.HashPassword(request.NewPassword);
        user.UpdatedAtUtc = DateTime.UtcNow;

        await _userRepository.UpdateUserAsync(user, ct);
        await _userRepository.RevokeAllUserSessionsAsync(user.Id, ct);
        await _userRepository.SaveChangesAsync(ct);
    }

    public async Task<bool> VerifyOtpAsync(string email, string otpCode, CancellationToken ct = default)
    {
        var sanitizedEmail = email.Trim().ToLowerInvariant();
        var otp = await _userRepository.GetValidOtpAsync(sanitizedEmail, otpCode.Trim(), ct);
        return otp != null;
    }

    public async Task<AuthResponse> RegisterWithOtpAsync(RegisterWithOtpRequest request, string? ipAddress, CancellationToken ct = default)
    {
        var sanitizedEmail = request.Email.Trim().ToLowerInvariant();
        var sanitizedUsername = request.Username.Trim().ToLowerInvariant();

        var otp = await _userRepository.GetValidOtpAsync(sanitizedEmail, request.OtpCode.Trim(), ct);
        if (otp == null)
        {
            throw new ValidationException("OtpCode", "Invalid or expired verification code. Please request a new code.");
        }

        if (await _userRepository.IsEmailTakenAsync(sanitizedEmail, ct))
        {
            throw new ConflictException("An account with this email address already exists.");
        }

        if (!UsernameRegex.IsMatch(sanitizedUsername))
        {
            throw new ValidationException("Username", "Username must be 3-30 characters and contain only letters, numbers, underscores, and dots.");
        }

        if (sanitizedUsername.StartsWith('.') || sanitizedUsername.EndsWith('.'))
        {
            throw new ValidationException("Username", "Username cannot start or end with a dot.");
        }

        var reserved = new[] { "admin", "administrator", "system", "moderator", "support", "help", "root", "api" };
        if (reserved.Contains(sanitizedUsername))
        {
            throw new ConflictException($"The username '{sanitizedUsername}' is reserved.");
        }

        if (await _userRepository.IsUsernameTakenAsync(sanitizedUsername, ct))
        {
            throw new ConflictException($"The username '{sanitizedUsername}' is already taken.");
        }

        // Mark OTP as used
        otp.IsUsed = true;
        otp.UsedAtUtc = DateTime.UtcNow;

        var passwordHash = _passwordHasher.HashPassword(request.Password);
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = sanitizedUsername,
            Email = sanitizedEmail,
            PasswordHash = passwordHash,
            CreatedAtUtc = DateTime.UtcNow,
            IsActive = true,
            IsEmailVerified = true
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

        var (accessToken, accessExpires) = _jwtTokenService.GenerateAccessToken(user);
        var refreshToken = _jwtTokenService.GenerateRefreshToken();

        var session = new UserSession
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            RefreshToken = refreshToken,
            DeviceInfo = "Initial Verified Session",
            IpAddress = ipAddress,
            CreatedAtUtc = DateTime.UtcNow,
            ExpiresAtUtc = DateTime.UtcNow.AddDays(30)
        };

        await _userRepository.AddSessionAsync(session, ct);
        await _userRepository.SaveChangesAsync(ct);

        return BuildAuthResponse(user, profile, accessToken, accessExpires, refreshToken);
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

    public async Task<AuthResponse> PhoneLoginOrRegisterAsync(PhoneAuthRequest request, string? ipAddress, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(request.PhoneNumber))
        {
            throw new ValidationException("PhoneNumber", "Phone number is required.");
        }

        var cleanPhone = request.PhoneNumber.Trim().Replace(" ", "").Replace("-", "");

        // Find existing user by phone
        var existingUser = await _userRepository.GetByPhoneNumberAsync(cleanPhone, ct);
        if (existingUser != null)
        {
            // Login existing user
            var existingProfile = existingUser.Profile ?? new UserProfile { UserId = existingUser.Id, DisplayName = existingUser.Username };
            
            var (accessToken, accessExpires) = _jwtTokenService.GenerateAccessToken(existingUser);
            var refreshToken = _jwtTokenService.GenerateRefreshToken();

            var session = new UserSession
            {
                Id = Guid.NewGuid(),
                UserId = existingUser.Id,
                RefreshToken = refreshToken,
                DeviceInfo = "Phone Session",
                IpAddress = ipAddress,
                CreatedAtUtc = DateTime.UtcNow,
                ExpiresAtUtc = DateTime.UtcNow.AddDays(30)
            };

            await _userRepository.AddSessionAsync(session, ct);
            await _userRepository.SaveChangesAsync(ct);

            return BuildAuthResponse(existingUser, existingProfile, accessToken, accessExpires, refreshToken);
        }

        // New user registration via phone
        var baseUsername = !string.IsNullOrWhiteSpace(request.Username)
            ? request.Username.Trim().ToLowerInvariant()
            : "user_" + cleanPhone.Substring(Math.Max(0, cleanPhone.Length - 4)) + "_" + Random.Shared.Next(100, 999);

        var finalUsername = baseUsername;
        var counter = 1;
        while (await _userRepository.IsUsernameTakenAsync(finalUsername, ct))
        {
            finalUsername = $"{baseUsername}_{counter++}";
        }

        var syntheticEmail = $"{cleanPhone.Replace("+", "")}@phone.messenger.com";
        var newUser = new User
        {
            Id = Guid.NewGuid(),
            Username = finalUsername,
            Email = syntheticEmail,
            PhoneNumber = cleanPhone,
            IsPhoneVerified = true,
            IsEmailVerified = false,
            PasswordHash = _passwordHasher.HashPassword(Guid.NewGuid().ToString("N")),
            IsActive = true,
            CreatedAtUtc = DateTime.UtcNow
        };

        var newProfile = new UserProfile
        {
            UserId = newUser.Id,
            DisplayName = !string.IsNullOrWhiteSpace(request.DisplayName) ? request.DisplayName.Trim() : finalUsername,
            IsOnline = true,
            LastSeenAtUtc = DateTime.UtcNow
        };

        newUser.Profile = newProfile;

        await _userRepository.AddUserAsync(newUser, ct);

        var (newAccessToken, newAccessExpires) = _jwtTokenService.GenerateAccessToken(newUser);
        var newRefreshToken = _jwtTokenService.GenerateRefreshToken();

        var newSession = new UserSession
        {
            Id = Guid.NewGuid(),
            UserId = newUser.Id,
            RefreshToken = newRefreshToken,
            DeviceInfo = "Phone Session",
            IpAddress = ipAddress,
            CreatedAtUtc = DateTime.UtcNow,
            ExpiresAtUtc = DateTime.UtcNow.AddDays(30)
        };

        await _userRepository.AddSessionAsync(newSession, ct);
        await _userRepository.SaveChangesAsync(ct);

        return BuildAuthResponse(newUser, newProfile, newAccessToken, newAccessExpires, newRefreshToken);
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
