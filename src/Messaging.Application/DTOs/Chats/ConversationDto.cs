using Messaging.Application.DTOs.Users;
using Messaging.Domain.Enums;

namespace Messaging.Application.DTOs.Chats;

public class ConversationDto
{
    public Guid ConversationId { get; set; }
    public ConversationType Type { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? AvatarUrl { get; set; }
    public bool IsPinned { get; set; }
    public bool IsMuted { get; set; }
    public bool IsArchived { get; set; }
    public int UnreadCount { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
    public MessageDto? LastMessage { get; set; }
    public UserSearchResultDto? OtherParticipant { get; set; }
}
