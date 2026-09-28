using Messaging.Application.DTOs.Auth;

namespace Messaging.Application.Common.Interfaces;

public interface IAuthService
{
    Task<AuthResponse> RegisterAsync(RegisterRequest request, string? ipAddress, CancellationToken ct = default);
    Task<AuthResponse> LoginAsync(LoginRequest request, string? ipAddress, CancellationToken ct = default);
    Task<AuthResponse> RefreshTokenAsync(RefreshTokenRequest request, string? ipAddress, CancellationToken ct = default);
    Task LogoutAsync(string refreshToken, CancellationToken ct = default);
    Task LogoutAllAsync(Guid userId, CancellationToken ct = default);
    Task<UserProfileDto> GetCurrentUserProfileAsync(Guid userId, CancellationToken ct = default);
    Task<string> SendOtpAsync(string email, CancellationToken ct = default);
    Task<bool> VerifyOtpAsync(string email, string otpCode, CancellationToken ct = default);
    Task<AuthResponse> RegisterWithOtpAsync(RegisterWithOtpRequest request, string? ipAddress, CancellationToken ct = default);
    Task<string> ForgotPasswordAsync(string email, CancellationToken ct = default);
    Task ResetPasswordAsync(ResetPasswordRequest request, CancellationToken ct = default);
}


