using System.Security.Claims;
using Messaging.Api.Hubs;
using Messaging.Application.Common.Interfaces;
using Messaging.Application.DTOs.Chats;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;

namespace Messaging.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ConversationsController : ControllerBase
{
    private readonly IChatService _chatService;
    private readonly IHubContext<ChatHub, IChatHubClient> _hubContext;

    public ConversationsController(
        IChatService chatService, 
        IHubContext<ChatHub, IChatHubClient> hubContext)
    {
        _chatService = chatService;
        _hubContext = hubContext;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<ConversationDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetConversations(CancellationToken ct)
    {
        var currentUserId = GetCurrentUserId();
        var conversations = await _chatService.GetUserConversationsAsync(currentUserId, ct);
        return Ok(conversations);
    }

    [HttpPost("direct")]
    [ProducesResponseType(typeof(ConversationDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetOrCreateDirectConversation(
        [FromBody] CreateDirectConversationRequest request, 
        CancellationToken ct)
    {
        var currentUserId = GetCurrentUserId();
        var conversation = await _chatService.GetOrCreateDirectConversationAsync(
            currentUserId, 
            request.RecipientUserId, 
            ct);
            
        return Ok(conversation);
    }

    [HttpGet("{id:guid}/messages")]
    [ProducesResponseType(typeof(IReadOnlyList<MessageDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetMessages(
        [FromRoute] Guid id,
        [FromQuery] DateTime? before = null,
        [FromQuery] int limit = 50,
        CancellationToken ct = default)
    {
        var currentUserId = GetCurrentUserId();
        var messages = await _chatService.GetConversationMessagesAsync(
            id, 
            currentUserId, 
            before, 
            limit, 
            ct);

        return Ok(messages);
    }

    [HttpPost("{id:guid}/messages")]
    [ProducesResponseType(typeof(MessageDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> SendMessage(
        [FromRoute] Guid id,
        [FromBody] SendMessageRequest request,
        CancellationToken ct)
    {
        var currentUserId = GetCurrentUserId();
        request.ConversationId = id;

        var message = await _chatService.SendMessageAsync(currentUserId, request, ct);

        // Notify real-time participants via SignalR
        var participantIds = await _chatService.GetConversationParticipantUserIdsAsync(id, ct);
        foreach (var participantId in participantIds)
        {
            if (participantId == currentUserId)
            {
                await _hubContext.Clients.Group($"user_{participantId}").MessageSent(message);
            }
            else
            {
                await _hubContext.Clients.Group($"user_{participantId}").MessageReceived(message);
            }
        }

        return CreatedAtAction(nameof(GetMessages), new { id }, message);
    }

    private Guid GetCurrentUserId()
    {
        var idClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!Guid.TryParse(idClaim, out var id))
        {
            throw new UnauthorizedAccessException("Invalid or missing user ID in token.");
        }
        return id;
    }
}
