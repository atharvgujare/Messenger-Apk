using System.ComponentModel.DataAnnotations;

namespace Messaging.Application.DTOs.Chats;

public class CreateDirectConversationRequest
{
    [Required(ErrorMessage = "Recipient user ID is required.")]
    public Guid RecipientUserId { get; set; }
}
