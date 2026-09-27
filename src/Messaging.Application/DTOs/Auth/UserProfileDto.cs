using Messaging.Domain.Enums;

namespace Messaging.Application.DTOs.Auth;

public class UserProfileDto
{
    public Guid UserId { get; set; }
    public string Username { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string? Bio { get; set; }
    public string? AvatarUrl { get; set; }
    public bool IsOnline { get; set; }
    public DateTime? LastSeenAtUtc { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public PrivacyLevel LastSeenPrivacy { get; set; }
    public PrivacyLevel AvatarPrivacy { get; set; }
    public bool ReadReceiptsEnabled { get; set; }
    public bool TypingIndicatorEnabled { get; set; }
}
