using Messaging.Application.DTOs.Chats;

namespace Messaging.Application.Common.Interfaces;

public interface IChatHubClient
{
    Task MessageReceived(MessageDto message);
    Task MessageSent(MessageDto message);
    Task ConversationUpdated(ConversationDto conversation);
}
