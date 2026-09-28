namespace Messaging.Application.DTOs.Snaps;

public class CreateSnapRequest
{
    public Guid RecipientId { get; set; }
    public string MediaUrl { get; set; } = string.Empty;
    public string? Caption { get; set; }
    public int TimerSeconds { get; set; } = 5;
    public bool IsViewOnce { get; set; } = false;
}

public class SnapDto
{
    public Guid Id { get; set; }
    public Guid SenderId { get; set; }
    public string SenderUsername { get; set; } = string.Empty;
    public string SenderDisplayName { get; set; } = string.Empty;
    public string? SenderAvatarUrl { get; set; }
    public Guid RecipientId { get; set; }
    public string MediaUrl { get; set; } = string.Empty;
    public string? Caption { get; set; }
    public int TimerSeconds { get; set; }
    public bool IsViewOnce { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public bool IsOpened { get; set; }
    public DateTime? OpenedAtUtc { get; set; }
    public int StreakCount { get; set; }
}
