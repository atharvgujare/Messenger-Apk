namespace Messaging.Domain.Entities;

public class Snap
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid SenderId { get; set; }
    public Guid RecipientId { get; set; }
    public string MediaUrl { get; set; } = string.Empty;
    public string? Caption { get; set; }
    public int TimerSeconds { get; set; } = 5;
    public bool IsViewOnce { get; set; } = false;
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime ExpiresAtUtc { get; set; } = DateTime.UtcNow.AddHours(24);
    public DateTime? OpenedAtUtc { get; set; }
    public bool IsOpened { get; set; } = false;

    public User Sender { get; set; } = null!;
    public User Recipient { get; set; } = null!;
}

public class SnapStreak
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid User1Id { get; set; }
    public Guid User2Id { get; set; }
    public int StreakCount { get; set; } = 0;
    public DateTime? LastSnapUser1Utc { get; set; }
    public DateTime? LastSnapUser2Utc { get; set; }
    public DateTime? LastStreakIncrementUtc { get; set; }
}
