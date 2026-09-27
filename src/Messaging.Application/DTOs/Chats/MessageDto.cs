using Messaging.Domain.Enums;

namespace Messaging.Application.DTOs.Chats;

public class MessageDto
{
    public Guid Id { get; set; }
    public Guid ConversationId { get; set; }
    public Guid SenderId { get; set; }
    public string SenderUsername { get; set; } = string.Empty;
    public string SenderDisplayName { get; set; } = string.Empty;
    public MessageType Type { get; set; }
    public string? Content { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public bool IsEdited { get; set; }
    public MessageStatus Status { get; set; }
    public Guid? ReplyToMessageId { get; set; }
    public string? ClientGeneratedId { get; set; }
}
