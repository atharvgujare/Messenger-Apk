using Messaging.Application.DTOs.Chats;

namespace Messaging.Application.Common.Interfaces;

public interface IChatHubClient
{
    Task MessageReceived(MessageDto message);
    Task MessageSent(MessageDto message);
    Task ConversationUpdated(ConversationDto conversation);
    Task MessageDelivered(Guid messageId, Guid conversationId);
    Task MessagesRead(Guid conversationId, Guid readByUserId, DateTime readAtUtc);
    Task UserPresenceChanged(Guid userId, bool isOnline, DateTime? lastSeenAtUtc);
    Task UserTyping(Guid conversationId, Guid userId, string username, bool isTyping);
    Task MessageEdited(Guid messageId, Guid conversationId, string newContent, DateTime editedAtUtc);
    Task MessageDeleted(Guid messageId, Guid conversationId, bool isDeletedForEveryone);
    Task MessageReactionUpdated(Guid messageId, Guid conversationId, List<MessageReactionDto> reactions);
}
