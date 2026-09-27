using System.ComponentModel.DataAnnotations;
using Messaging.Domain.Enums;

namespace Messaging.Application.DTOs.Chats;

public class SendMessageRequest
{
    [Required(ErrorMessage = "Conversation ID is required.")]
    public Guid ConversationId { get; set; }

    [Required(ErrorMessage = "Message content is required.")]
    public string Content { get; set; } = string.Empty;

    public MessageType Type { get; set; } = MessageType.Text;

    public Guid? ReplyToMessageId { get; set; }

    public string? ClientGeneratedId { get; set; }
}
