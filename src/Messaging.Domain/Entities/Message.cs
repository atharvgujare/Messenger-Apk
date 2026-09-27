using Messaging.Domain.Enums;

namespace Messaging.Domain.Entities;

public class Message
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid ConversationId { get; set; }
    public Guid SenderId { get; set; }
    public MessageType Type { get; set; } = MessageType.Text;
    public string? Content { get; set; }
    public Guid? ReplyToMessageId { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAtUtc { get; set; }
    public bool IsEdited { get; set; } = false;
    public bool IsDeletedForEveryone { get; set; } = false;
    public MessageStatus Status { get; set; } = MessageStatus.Sent;

    // Navigations
    public Conversation Conversation { get; set; } = null!;
    public User Sender { get; set; } = null!;
    public Message? ReplyToMessage { get; set; }
}
