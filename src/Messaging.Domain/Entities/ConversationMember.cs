namespace Messaging.Domain.Entities;

public class ConversationMember
{
    public Guid ConversationId { get; set; }
    public Guid UserId { get; set; }
    public DateTime JoinedAtUtc { get; set; } = DateTime.UtcNow;
    public bool IsMuted { get; set; } = false;
    public bool IsPinned { get; set; } = false;
    public bool IsArchived { get; set; } = false;
    public Guid? LastReadMessageId { get; set; }
    public DateTime? LastReadAtUtc { get; set; }

    // Navigations
    public Conversation Conversation { get; set; } = null!;
    public User User { get; set; } = null!;
}
