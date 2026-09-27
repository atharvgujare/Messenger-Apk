namespace Messaging.Domain.Entities;

public class MessageUserDeletion
{
    public Guid MessageId { get; set; }
    public Guid UserId { get; set; }
    public DateTime DeletedAtUtc { get; set; } = DateTime.UtcNow;

    // Navigations
    public Message Message { get; set; } = null!;
    public User User { get; set; } = null!;
}
