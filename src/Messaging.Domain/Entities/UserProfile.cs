using Messaging.Domain.Enums;

namespace Messaging.Domain.Entities;

public class UserProfile
{
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public string? Bio { get; set; }
    public string? AvatarUrl { get; set; }
    public DateTime? LastSeenAtUtc { get; set; }
    public bool IsOnline { get; set; }
    public PrivacyLevel LastSeenPrivacy { get; set; } = PrivacyLevel.Everyone;
    public PrivacyLevel AvatarPrivacy { get; set; } = PrivacyLevel.Everyone;
    public bool ReadReceiptsEnabled { get; set; } = true;
    public bool TypingIndicatorEnabled { get; set; } = true;
    public bool IsPrivate { get; set; } = false;

    // Navigation
    public User User { get; set; } = null!;
}
