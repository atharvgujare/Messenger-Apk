using System.ComponentModel.DataAnnotations;

namespace Messaging.Application.DTOs.Chats;

public class ToggleReactionRequest
{
    [Required(ErrorMessage = "Emoji is required.")]
    [StringLength(32, MinimumLength = 1, ErrorMessage = "Emoji must be 1 to 32 characters.")]
    public string Emoji { get; set; } = string.Empty;
}
