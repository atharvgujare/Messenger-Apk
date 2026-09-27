using System.Collections.Concurrent;
using Messaging.Application.Common.Interfaces;

namespace Messaging.Infrastructure.Presence;

public class PresenceTracker : IPresenceTracker
{
    private static readonly ConcurrentDictionary<Guid, HashSet<string>> OnlineUsers = new();

    public Task<bool> UserConnectedAsync(Guid userId, string connectionId)
    {
        var isFirstConnection = false;

        OnlineUsers.AddOrUpdate(
            userId,
            _ =>
            {
                isFirstConnection = true;
                return new HashSet<string> { connectionId };
            },
            (_, connections) =>
            {
                lock (connections)
                {
                    if (connections.Count == 0)
                    {
                        isFirstConnection = true;
                    }
                    connections.Add(connectionId);
                }
                return connections;
            });

        return Task.FromResult(isFirstConnection);
    }

    public Task<bool> UserDisconnectedAsync(Guid userId, string connectionId)
    {
        var isLastConnection = false;

        if (OnlineUsers.TryGetValue(userId, out var connections))
        {
            lock (connections)
            {
                connections.Remove(connectionId);
                if (connections.Count == 0)
                {
                    isLastConnection = true;
                    OnlineUsers.TryRemove(userId, out _);
                }
            }
        }

        return Task.FromResult(isLastConnection);
    }

    public Task<bool> IsUserOnlineAsync(Guid userId)
    {
        var isOnline = OnlineUsers.ContainsKey(userId);
        return Task.FromResult(isOnline);
    }

    public Task<IReadOnlyList<Guid>> GetOnlineUsersAsync()
    {
        IReadOnlyList<Guid> users = OnlineUsers.Keys.ToList();
        return Task.FromResult(users);
    }
}
