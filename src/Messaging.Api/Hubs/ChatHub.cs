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
    private readonly ILogger<ChatHub> _logger;

    public ChatHub(IChatService chatService, ILogger<ChatHub> logger)
    {
        _chatService = chatService;
        _logger = logger;
    }

    public override async Task OnConnectedAsync()
    {
        var userId = GetUserId();
        if (userId.HasValue)
        {
            // Add connection to user-specific group so we can send targeted updates to all user devices
            await Groups.AddToGroupAsync(Context.ConnectionId, GetUserGroup(userId.Value));
            _logger.LogInformation("User {UserId} connected to ChatHub on connection {ConnectionId}", userId, Context.ConnectionId);
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

    private Guid? GetUserId()
    {
        var idClaim = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(idClaim, out var id) ? id : null;
    }

    private static string GetUserGroup(Guid userId) => $"user_{userId}";
    private static string GetConversationGroup(Guid convId) => $"conv_{convId}";
}
