using System.ComponentModel.DataAnnotations;

namespace Messaging.Application.DTOs.Chats;

public class CreateGroupRequest
{
    [Required]
    [StringLength(100, MinimumLength = 1)]
    public string Title { get; set; } = string.Empty;

    public string? AvatarUrl { get; set; }

    [Required]
    [MinLength(1, ErrorMessage = "A group must have at least one participant besides the creator.")]
    public List<Guid> MemberUserIds { get; set; } = new();
}

public class TogglePinConversationResponse
{
    public Guid ConversationId { get; set; }
    public bool IsPinned { get; set; }
}
