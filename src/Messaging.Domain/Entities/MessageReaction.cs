namespace Messaging.Domain.Entities;

public class MessageReaction
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid MessageId { get; set; }
    public Guid UserId { get; set; }
    public string Emoji { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

    // Navigations
    public Message Message { get; set; } = null!;
    public User User { get; set; } = null!;
}
