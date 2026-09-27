using System.Security.Claims;
using Messaging.Application.Common.Exceptions;
using Messaging.Application.Common.Interfaces;
using Messaging.Application.DTOs.Chats;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Messaging.Api.Hubs;

[Authorize]
public class ChatHub : Hub<IChatHubClient>
{
    private readonly IChatService _chatService;
    private readonly IPresenceTracker _presenceTracker;
    private readonly IUserRepository _userRepository;
    private readonly ILogger<ChatHub> _logger;

    public ChatHub(
        IChatService chatService, 
        IPresenceTracker presenceTracker,
        IUserRepository userRepository,
        ILogger<ChatHub> logger)
    {
        _chatService = chatService;
        _presenceTracker = presenceTracker;
        _userRepository = userRepository;
        _logger = logger;
    }

    public override async Task OnConnectedAsync()
    {
        var userId = GetUserId();
        if (userId.HasValue)
        {
            // 1. Add connection to user-specific group so we can send targeted updates to all user devices
            await Groups.AddToGroupAsync(Context.ConnectionId, GetUserGroup(userId.Value));
            _logger.LogInformation("User {UserId} connected to ChatHub on connection {ConnectionId}", userId, Context.ConnectionId);

            // 2. Track presence
            var isFirstConnection = await _presenceTracker.UserConnectedAsync(userId.Value, Context.ConnectionId);
            if (isFirstConnection)
            {
                var user = await _userRepository.GetByIdAsync(userId.Value);
                if (user?.Profile != null)
                {
                    user.Profile.IsOnline = true;
                    user.Profile.LastSeenAtUtc = DateTime.UtcNow;
                    await _userRepository.UpdateUserAsync(user);
                    await _userRepository.SaveChangesAsync();
                }

                // Broadcast presence to all other connected clients
                await Clients.Others.UserPresenceChanged(userId.Value, true, null);
                _logger.LogInformation("User {UserId} transitioned to ONLINE", userId);
            }
        }

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var userId = GetUserId();
        if (userId.HasValue)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, GetUserGroup(userId.Value));
            _logger.LogInformation("User {UserId} disconnected from ChatHub", userId);

            // Track presence
            var isLastConnection = await _presenceTracker.UserDisconnectedAsync(userId.Value, Context.ConnectionId);
            if (isLastConnection)
            {
                var lastSeen = DateTime.UtcNow;
                var user = await _userRepository.GetByIdAsync(userId.Value);
                if (user?.Profile != null)
                {
                    user.Profile.IsOnline = false;
                    user.Profile.LastSeenAtUtc = lastSeen;
                    await _userRepository.UpdateUserAsync(user);
                    await _userRepository.SaveChangesAsync();
                }

                // Broadcast presence to all other connected clients
                await Clients.Others.UserPresenceChanged(userId.Value, false, lastSeen);
                _logger.LogInformation("User {UserId} transitioned to OFFLINE at {LastSeen}", userId, lastSeen);
            }
        }

        await base.OnDisconnectedAsync(exception);
    }

    public async Task JoinConversation(Guid conversationId)
    {
        var userId = GetUserId();
        if (!userId.HasValue) return;

        var participants = await _chatService.GetConversationParticipantUserIdsAsync(conversationId);
        if (participants.Contains(userId.Value))
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, GetConversationGroup(conversationId));
            _logger.LogDebug("User {UserId} joined conversation group {ConversationId}", userId, conversationId);
        }
    }

    public async Task LeaveConversation(Guid conversationId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, GetConversationGroup(conversationId));
    }

    public async Task<MessageDto> SendMessage(SendMessageRequest request)
    {
        var userId = GetUserId();
        if (!userId.HasValue)
        {
            throw new HubException("Unauthorized: Invalid user identity.");
        }

        try
        {
            var message = await _chatService.SendMessageAsync(userId.Value, request);

            // Get all participants of this conversation
            var participantIds = await _chatService.GetConversationParticipantUserIdsAsync(request.ConversationId);

            // Deliver message to each participant's user-group
            foreach (var participantId in participantIds)
            {
                if (participantId == userId.Value)
                {
                    // Confirm back to sender
                    await Clients.Group(GetUserGroup(participantId)).MessageSent(message);
                }
                else
                {
                    // Deliver to recipient
                    await Clients.Group(GetUserGroup(participantId)).MessageReceived(message);
                }
            }

            return message;
        }
        catch (AppException ex)
        {
            throw new HubException(ex.Message);
        }
    }

    public async Task MarkMessageDelivered(Guid messageId, Guid conversationId)
    {
        var userId = GetUserId();
        if (!userId.HasValue) return;

        try
        {
            await _chatService.MarkMessageDeliveredAsync(messageId, userId.Value);
            var participants = await _chatService.GetConversationParticipantUserIdsAsync(conversationId);
            foreach (var participantId in participants)
            {
                await Clients.Group(GetUserGroup(participantId)).MessageDelivered(messageId, conversationId);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to mark message {MessageId} as delivered", messageId);
        }
    }

    public async Task MarkConversationAsRead(Guid conversationId)
    {
        var userId = GetUserId();
        if (!userId.HasValue) return;

        try
        {
            var readAt = await _chatService.MarkConversationReadAsync(conversationId, userId.Value);
            var participants = await _chatService.GetConversationParticipantUserIdsAsync(conversationId);
            foreach (var participantId in participants)
            {
                await Clients.Group(GetUserGroup(participantId)).MessagesRead(conversationId, userId.Value, readAt);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to mark conversation {ConversationId} as read", conversationId);
        }
    }

    public async Task SendTypingIndicator(Guid conversationId, bool isTyping)
    {
        var userId = GetUserId();
        if (!userId.HasValue) return;

        var username = Context.User?.Identity?.Name ?? "User";
        var participants = await _chatService.GetConversationParticipantUserIdsAsync(conversationId);
        foreach (var participantId in participants)
        {
            if (participantId != userId.Value)
            {
                await Clients.Group(GetUserGroup(participantId)).UserTyping(conversationId, userId.Value, username, isTyping);
            }
        }
    }

    public async Task<MessageDto> EditMessage(Guid messageId, string newContent)
    {
        var userId = GetUserId();
        if (!userId.HasValue)
        {
            throw new HubException("Unauthorized: Invalid user identity.");
        }

        try
        {
            var edited = await _chatService.EditMessageAsync(messageId, userId.Value, newContent);
            var participants = await _chatService.GetConversationParticipantUserIdsAsync(edited.ConversationId);
            foreach (var participantId in participants)
            {
                await Clients.Group(GetUserGroup(participantId)).MessageEdited(
                    edited.Id, 
                    edited.ConversationId, 
                    edited.Content ?? string.Empty, 
                    edited.UpdatedAtUtc ?? DateTime.UtcNow);
            }
            return edited;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to edit message {MessageId}", messageId);
            throw new HubException(ex.Message);
        }
    }

    public async Task DeleteMessage(Guid messageId, Guid conversationId, bool forEveryone)
    {
        var userId = GetUserId();
        if (!userId.HasValue)
        {
            throw new HubException("Unauthorized: Invalid user identity.");
        }

        try
        {
            var isForEveryone = await _chatService.DeleteMessageAsync(messageId, userId.Value, forEveryone);
            if (isForEveryone)
            {
                var participants = await _chatService.GetConversationParticipantUserIdsAsync(conversationId);
                foreach (var participantId in participants)
                {
                    await Clients.Group(GetUserGroup(participantId)).MessageDeleted(messageId, conversationId, true);
                }
            }
            else
            {
                await Clients.Group(GetUserGroup(userId.Value)).MessageDeleted(messageId, conversationId, false);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to delete message {MessageId}", messageId);
            throw new HubException(ex.Message);
        }
    }

    public async Task<List<MessageReactionDto>> ToggleReaction(Guid messageId, Guid conversationId, string emoji)
    {
        var userId = GetUserId();
        if (!userId.HasValue)
        {
            throw new HubException("Unauthorized: Invalid user identity.");
        }

        try
        {
            var reactions = await _chatService.ToggleReactionAsync(messageId, userId.Value, emoji);
            var participants = await _chatService.GetConversationParticipantUserIdsAsync(conversationId);
            foreach (var participantId in participants)
            {
                await Clients.Group(GetUserGroup(participantId)).MessageReactionUpdated(messageId, conversationId, reactions);
            }
            return reactions;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to toggle reaction on message {MessageId}", messageId);
            throw new HubException(ex.Message);
        }
    }

    private Guid? GetUserId()
    {
        var idClaim = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(idClaim, out var id) ? id : null;
    }

    private static string GetUserGroup(Guid userId) => $"user_{userId}";
    private static string GetConversationGroup(Guid convId) => $"conv_{convId}";
}
