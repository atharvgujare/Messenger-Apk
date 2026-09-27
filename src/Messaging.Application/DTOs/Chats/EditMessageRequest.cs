using System.ComponentModel.DataAnnotations;

namespace Messaging.Application.DTOs.Chats;

public class EditMessageRequest
{
    [Required(ErrorMessage = "Message content is required.")]
    [StringLength(4000, MinimumLength = 1, ErrorMessage = "Content cannot be empty.")]
    public string Content { get; set; } = string.Empty;
}
