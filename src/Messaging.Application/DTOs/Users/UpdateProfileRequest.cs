using System.ComponentModel.DataAnnotations;
using Messaging.Domain.Enums;

namespace Messaging.Application.DTOs.Users;

public class UpdateProfileRequest
{
    [Required(ErrorMessage = "Display name is required.")]
    [StringLength(100, MinimumLength = 1)]
    public string DisplayName { get; set; } = string.Empty;

    [StringLength(500)]
    public string? Bio { get; set; }

    [StringLength(1024)]
    public string? AvatarUrl { get; set; }

    public PrivacyLevel? LastSeenPrivacy { get; set; }
    public PrivacyLevel? AvatarPrivacy { get; set; }
    public bool? ReadReceiptsEnabled { get; set; }
    public bool? TypingIndicatorEnabled { get; set; }
    public bool? IsPrivate { get; set; }
}
