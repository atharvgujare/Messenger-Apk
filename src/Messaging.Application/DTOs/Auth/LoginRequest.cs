using System.ComponentModel.DataAnnotations;

namespace Messaging.Application.DTOs.Auth;

public class LoginRequest
{
    [Required(ErrorMessage = "Username or email is required.")]
    public string LoginIdentifier { get; set; } = string.Empty;

    [Required(ErrorMessage = "Password is required.")]
    public string Password { get; set; } = string.Empty;

    public string? DeviceInfo { get; set; }
}
