using System.ComponentModel.DataAnnotations;

namespace Messaging.Application.DTOs.Auth;

public class RefreshTokenRequest
{
    [Required(ErrorMessage = "Refresh token is required.")]
    public string RefreshToken { get; set; } = string.Empty;
}
