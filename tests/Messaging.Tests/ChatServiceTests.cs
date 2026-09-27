using Messaging.Application.Common.Exceptions;
using Messaging.Application.Common.Interfaces;
using Messaging.Application.DTOs.Chats;
using Messaging.Application.Services;
using Messaging.Domain.Entities;
using Messaging.Domain.Enums;
using Moq;
using Xunit;

namespace Messaging.Tests;

public class ChatServiceTests
{
    private readonly Mock<IConversationRepository> _convRepoMock = new();
    private readonly Mock<IMessageRepository> _msgRepoMock = new();
    private readonly Mock<IUserRepository> _userRepoMock = new();
    private readonly ChatService _chatService;

    public ChatServiceTests()
    {
        _chatService = new ChatService(
            _convRepoMock.Object,
            _msgRepoMock.Object,
            _userRepoMock.Object);
    }

    [Fact]
    public async Task GetOrCreateDirectConversationAsync_ShouldThrowValidation_WhenTalkingToSelf()
    {
        var userId = Guid.NewGuid();
        await Assert.ThrowsAsync<ValidationException>(() =>
            _chatService.GetOrCreateDirectConversationAsync(userId, userId));
    }

    [Fact]
    public async Task GetOrCreateDirectConversationAsync_ShouldThrowNotFound_WhenRecipientDoesNotExist()
    {
        var currentUserId = Guid.NewGuid();
        var recipientId = Guid.NewGuid();

        _userRepoMock.Setup(u => u.GetByIdAsync(recipientId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((User?)null);

        await Assert.ThrowsAsync<NotFoundException>(() =>
            _chatService.GetOrCreateDirectConversationAsync(currentUserId, recipientId));
    }

    [Fact]
    public async Task GetOrCreateDirectConversationAsync_ShouldReturnExisting_WhenAlreadyExists()
    {
        var currentUserId = Guid.NewGuid();
        var recipientId = Guid.NewGuid();

        var recipient = new User
        {
            Id = recipientId,
            Username = "rahul",
            IsActive = true,
            Profile = new UserProfile { DisplayName = "Rahul" }
        };

        var existingConv = new Conversation
        {
            Id = Guid.NewGuid(),
            Type = ConversationType.Direct,
            Members = new List<ConversationMember>
            {
                new() { UserId = currentUserId, ConversationId = Guid.NewGuid() },
                new() { UserId = recipientId, ConversationId = Guid.NewGuid(), User = recipient }
            }
        };

        _userRepoMock.Setup(u => u.GetByIdAsync(recipientId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(recipient);

        _convRepoMock.Setup(c => c.GetDirectConversationAsync(currentUserId, recipientId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(existingConv);

        var result = await _chatService.GetOrCreateDirectConversationAsync(currentUserId, recipientId);

        Assert.NotNull(result);
        Assert.Equal(existingConv.Id, result.ConversationId);
        _convRepoMock.Verify(c => c.AddConversationAsync(It.IsAny<Conversation>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task GetOrCreateDirectConversationAsync_ShouldCreateNew_WhenNoneExists()
    {
        var currentUserId = Guid.NewGuid();
        var recipientId = Guid.NewGuid();

        var recipient = new User
        {
            Id = recipientId,
            Username = "rahul",
            IsActive = true,
            Profile = new UserProfile { DisplayName = "Rahul" }
        };

        _userRepoMock.Setup(u => u.GetByIdAsync(recipientId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(recipient);

        _convRepoMock.Setup(c => c.GetDirectConversationAsync(currentUserId, recipientId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Conversation?)null);

        var result = await _chatService.GetOrCreateDirectConversationAsync(currentUserId, recipientId);

        Assert.NotNull(result);
        _convRepoMock.Verify(c => c.AddConversationAsync(It.Is<Conversation>(conv =>
            conv.Type == ConversationType.Direct &&
            conv.Members.Count == 2), It.IsAny<CancellationToken>()), Times.Once);
        _convRepoMock.Verify(c => c.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task SendMessageAsync_ShouldThrowUnauthorized_WhenUserNotMember()
    {
        var senderId = Guid.NewGuid();
        var convId = Guid.NewGuid();

        _convRepoMock.Setup(c => c.IsMemberAsync(convId, senderId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);

        var request = new SendMessageRequest
        {
            ConversationId = convId,
            Content = "Hello!"
        };

        await Assert.ThrowsAsync<UnauthorizedException>(() =>
            _chatService.SendMessageAsync(senderId, request));
    }

    [Fact]
    public async Task SendMessageAsync_ShouldPersistMessageAndReturnDto_WhenValid()
    {
        var senderId = Guid.NewGuid();
        var convId = Guid.NewGuid();
        var sender = new User
        {
            Id = senderId,
            Username = "atharv",
            IsActive = true,
            Profile = new UserProfile { DisplayName = "Atharv Gujare" }
        };

        var conv = new Conversation
        {
            Id = convId,
            Type = ConversationType.Direct,
            Members = new List<ConversationMember>()
        };

        _convRepoMock.Setup(c => c.IsMemberAsync(convId, senderId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        _userRepoMock.Setup(u => u.GetByIdAsync(senderId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(sender);
        _convRepoMock.Setup(c => c.GetByIdAsync(convId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(conv);

        var request = new SendMessageRequest
        {
            ConversationId = convId,
            Content = "Hey there, ready to test SignalR?",
            Type = MessageType.Text,
            ClientGeneratedId = "cli-123"
        };

        var result = await _chatService.SendMessageAsync(senderId, request);

        Assert.NotNull(result);
        Assert.Equal("Hey there, ready to test SignalR?", result.Content);
        Assert.Equal("cli-123", result.ClientGeneratedId);
        Assert.Equal(senderId, result.SenderId);
        Assert.Equal(MessageStatus.Sent, result.Status);

        _msgRepoMock.Verify(m => m.AddMessageAsync(It.IsAny<Message>(), It.IsAny<CancellationToken>()), Times.Once);
        _convRepoMock.Verify(c => c.UpdateConversationAsync(conv, It.IsAny<CancellationToken>()), Times.Once);
        _msgRepoMock.Verify(m => m.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task MarkMessageDeliveredAsync_ShouldCallRepo_WhenRecipientIsMemberAndNotSender()
    {
        var messageId = Guid.NewGuid();
        var convId = Guid.NewGuid();
        var senderId = Guid.NewGuid();
        var recipientId = Guid.NewGuid();

        var message = new Message
        {
            Id = messageId,
            ConversationId = convId,
            SenderId = senderId,
            Status = MessageStatus.Sent
        };

        _msgRepoMock.Setup(m => m.GetByIdAsync(messageId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(message);
        _convRepoMock.Setup(c => c.IsMemberAsync(convId, recipientId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        await _chatService.MarkMessageDeliveredAsync(messageId, recipientId);

        _msgRepoMock.Verify(m => m.MarkMessageAsDeliveredAsync(messageId, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task MarkMessageDeliveredAsync_ShouldNotUpdate_WhenSenderTriesToDeliverOwnMessage()
    {
        var messageId = Guid.NewGuid();
        var convId = Guid.NewGuid();
        var senderId = Guid.NewGuid();

        var message = new Message
        {
            Id = messageId,
            ConversationId = convId,
            SenderId = senderId,
            Status = MessageStatus.Sent
        };

        _msgRepoMock.Setup(m => m.GetByIdAsync(messageId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(message);
        _convRepoMock.Setup(c => c.IsMemberAsync(convId, senderId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        await _chatService.MarkMessageDeliveredAsync(messageId, senderId);

        _msgRepoMock.Verify(m => m.MarkMessageAsDeliveredAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task MarkConversationReadAsync_ShouldUpdateMemberAndMarkMessages_WhenAuthorized()
    {
        var convId = Guid.NewGuid();
        var readerId = Guid.NewGuid();
        var lastMsgId = Guid.NewGuid();

        var conv = new Conversation
        {
            Id = convId,
            LastMessageId = lastMsgId
        };
        var member = new ConversationMember
        {
            ConversationId = convId,
            UserId = readerId
        };

        _convRepoMock.Setup(c => c.IsMemberAsync(convId, readerId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        _convRepoMock.Setup(c => c.GetMemberAsync(convId, readerId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(member);
        _convRepoMock.Setup(c => c.GetByIdAsync(convId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(conv);

        var readAt = await _chatService.MarkConversationReadAsync(convId, readerId);

        Assert.Equal(lastMsgId, member.LastReadMessageId);
        Assert.NotNull(member.LastReadAtUtc);
        _convRepoMock.Verify(c => c.UpdateMemberAsync(member, It.IsAny<CancellationToken>()), Times.Once);
        _msgRepoMock.Verify(m => m.MarkMessagesAsReadAsync(convId, readerId, It.IsAny<DateTime>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task GetConversationMessagesAsync_ShouldThrowUnauthorized_WhenNotMember()
    {
        var userId = Guid.NewGuid();
        var convId = Guid.NewGuid();

        _convRepoMock.Setup(c => c.IsMemberAsync(convId, userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);

        await Assert.ThrowsAsync<UnauthorizedException>(() =>
            _chatService.GetConversationMessagesAsync(convId, userId));
    }
}
