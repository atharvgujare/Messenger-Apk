namespace Messaging.Application.DTOs.Chats;

public class MessageReactionDto
{
    public string Emoji { get; set; } = string.Empty;
    public int Count { get; set; }
    public List<Guid> UserIds { get; set; } = new();
    public bool HasReacted { get; set; }
}
