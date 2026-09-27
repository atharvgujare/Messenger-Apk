using Messaging.Infrastructure.Presence;
using Xunit;

namespace Messaging.Tests;

public class PresenceTrackerTests
{
    [Fact]
    public async Task UserConnectedAsync_ShouldReturnTrueOnFirstConnection_AndFalseOnSubsequent()
    {
        var tracker = new PresenceTracker();
        var userId = Guid.NewGuid();

        var first = await tracker.UserConnectedAsync(userId, "conn-1");
        var second = await tracker.UserConnectedAsync(userId, "conn-2");

        Assert.True(first);
        Assert.False(second);
        Assert.True(await tracker.IsUserOnlineAsync(userId));
    }

    [Fact]
    public async Task UserDisconnectedAsync_ShouldReturnTrueOnlyWhenLastConnectionCloses()
    {
        var tracker = new PresenceTracker();
        var userId = Guid.NewGuid();

        await tracker.UserConnectedAsync(userId, "conn-1");
        await tracker.UserConnectedAsync(userId, "conn-2");

        var firstDisconnect = await tracker.UserDisconnectedAsync(userId, "conn-1");
        Assert.False(firstDisconnect);
        Assert.True(await tracker.IsUserOnlineAsync(userId));

        var lastDisconnect = await tracker.UserDisconnectedAsync(userId, "conn-2");
        Assert.True(lastDisconnect);
        Assert.False(await tracker.IsUserOnlineAsync(userId));
    }

    [Fact]
    public async Task GetOnlineUsersAsync_ShouldIncludeOnlyActiveUsers()
    {
        var tracker = new PresenceTracker();
        var user1 = Guid.NewGuid();
        var user2 = Guid.NewGuid();

        await tracker.UserConnectedAsync(user1, "conn-1");
        await tracker.UserConnectedAsync(user2, "conn-2");
        await tracker.UserDisconnectedAsync(user1, "conn-1");

        var onlineUsers = await tracker.GetOnlineUsersAsync();
        Assert.Contains(user2, onlineUsers);
        Assert.DoesNotContain(user1, onlineUsers);
    }
}
