namespace Messaging.Application.Common.Interfaces;

public interface IPresenceTracker
{
    Task<bool> UserConnectedAsync(Guid userId, string connectionId);
    Task<bool> UserDisconnectedAsync(Guid userId, string connectionId);
    Task<bool> IsUserOnlineAsync(Guid userId);
    Task<IReadOnlyList<Guid>> GetOnlineUsersAsync();
}
