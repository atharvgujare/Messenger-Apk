using Messaging.Application.Common.Exceptions;
using Messaging.Application.Common.Interfaces;
using Messaging.Application.DTOs.Chats;
using Messaging.Application.Services;
using Messaging.Domain.Entities;
using Messaging.Domain.Enums;
using Moq;
using Xunit;

namespace Messaging.Tests;

public class Phase5RichMessageTests
{
    private readonly Mock<IConversationRepository> _mockConvRepo;
    private readonly Mock<IMessageRepository> _mockMsgRepo;
    private readonly Mock<IUserRepository> _mockUserRepo;
    private readonly ChatService _chatService;

    public Phase5RichMessageTests()
    {
        _mockConvRepo = new Mock<IConversationRepository>();
        _mockMsgRepo = new Mock<IMessageRepository>();
        _mockUserRepo = new Mock<IUserRepository>();

        _chatService = new ChatService(
            _mockConvRepo.Object,
            _mockMsgRepo.Object,
            _mockUserRepo.Object);
    }

    [Fact]
    public async Task EditMessageAsync_SenderCanEdit_UpdatesContentAndSetsIsEdited()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var messageId = Guid.NewGuid();
        var message = new Message
        {
            Id = messageId,
            SenderId = userId,
            ConversationId = Guid.NewGuid(),
            Content = "Original text",
            IsEdited = false,
            IsDeletedForEveryone = false
        };

        _mockMsgRepo.Setup(r => r.GetByIdAsync(messageId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(message);

        // Act
        var result = await _chatService.EditMessageAsync(messageId, userId, "Updated text");

        // Assert
        Assert.Equal("Updated text", result.Content);
        Assert.True(result.IsEdited);
        Assert.NotNull(result.UpdatedAtUtc);
        _mockMsgRepo.Verify(r => r.UpdateMessageAsync(It.Is<Message>(m => m.Content == "Updated text" && m.IsEdited), It.IsAny<CancellationToken>()), Times.Once);
        _mockMsgRepo.Verify(r => r.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task EditMessageAsync_NonSender_ThrowsUnauthorizedException()
    {
        // Arrange
        var senderId = Guid.NewGuid();
        var nonSenderId = Guid.NewGuid();
        var messageId = Guid.NewGuid();
        var message = new Message
        {
            Id = messageId,
            SenderId = senderId,
            Content = "Hello",
            IsDeletedForEveryone = false
        };

        _mockMsgRepo.Setup(r => r.GetByIdAsync(messageId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(message);

        // Act & Assert
        await Assert.ThrowsAsync<UnauthorizedException>(() =>
            _chatService.EditMessageAsync(messageId, nonSenderId, "Hacked text"));
    }

    [Fact]
    public async Task DeleteMessageAsync_ForEveryone_MarksDeletedAndObscuresContent()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var messageId = Guid.NewGuid();
        var convId = Guid.NewGuid();
        var message = new Message
        {
            Id = messageId,
            SenderId = userId,
            ConversationId = convId,
            Content = "Secret message",
            IsDeletedForEveryone = false
        };

        _mockMsgRepo.Setup(r => r.GetByIdAsync(messageId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(message);
        _mockConvRepo.Setup(r => r.IsMemberAsync(convId, userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        // Act
        var forEveryoneResult = await _chatService.DeleteMessageAsync(messageId, userId, forEveryone: true);

        // Assert
        Assert.True(forEveryoneResult);
        Assert.True(message.IsDeletedForEveryone);
        Assert.Equal("This message was deleted", message.Content);
        _mockMsgRepo.Verify(r => r.UpdateMessageAsync(message, It.IsAny<CancellationToken>()), Times.Once);
        _mockMsgRepo.Verify(r => r.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task DeleteMessageAsync_ForMe_AddsUserDeletion()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var messageId = Guid.NewGuid();
        var convId = Guid.NewGuid();
        var message = new Message
        {
            Id = messageId,
            SenderId = Guid.NewGuid(), // Sent by someone else
            ConversationId = convId,
            Content = "Some text"
        };

        _mockMsgRepo.Setup(r => r.GetByIdAsync(messageId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(message);
        _mockConvRepo.Setup(r => r.IsMemberAsync(convId, userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        _mockMsgRepo.Setup(r => r.IsDeletedForUserAsync(messageId, userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);

        // Act
        var forEveryoneResult = await _chatService.DeleteMessageAsync(messageId, userId, forEveryone: false);

        // Assert
        Assert.False(forEveryoneResult);
        _mockMsgRepo.Verify(r => r.AddUserDeletionAsync(It.Is<MessageUserDeletion>(d => d.MessageId == messageId && d.UserId == userId), It.IsAny<CancellationToken>()), Times.Once);
        _mockMsgRepo.Verify(r => r.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ToggleReactionAsync_NewEmoji_AddsReaction()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var messageId = Guid.NewGuid();
        var convId = Guid.NewGuid();
        var message = new Message
        {
            Id = messageId,
            ConversationId = convId,
            IsDeletedForEveryone = false
        };

        _mockMsgRepo.Setup(r => r.GetByIdAsync(messageId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(message);
        _mockConvRepo.Setup(r => r.IsMemberAsync(convId, userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        _mockMsgRepo.Setup(r => r.GetReactionAsync(messageId, userId, "❤️", It.IsAny<CancellationToken>()))
            .ReturnsAsync((MessageReaction?)null);

        var reactionsList = new List<MessageReaction>
        {
            new MessageReaction { MessageId = messageId, UserId = userId, Emoji = "❤️" }
        };
        _mockMsgRepo.Setup(r => r.GetReactionsForMessageAsync(messageId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(reactionsList);

        // Act
        var result = await _chatService.ToggleReactionAsync(messageId, userId, "❤️");

        // Assert
        Assert.Single(result);
        Assert.Equal("❤️", result[0].Emoji);
        Assert.Equal(1, result[0].Count);
        Assert.True(result[0].HasReacted);
        _mockMsgRepo.Verify(r => r.AddReactionAsync(It.IsAny<MessageReaction>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ToggleReactionAsync_ExistingEmoji_RemovesReaction()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var messageId = Guid.NewGuid();
        var convId = Guid.NewGuid();
        var message = new Message
        {
            Id = messageId,
            ConversationId = convId,
            IsDeletedForEveryone = false
        };

        var existingReaction = new MessageReaction { MessageId = messageId, UserId = userId, Emoji = "👍" };

        _mockMsgRepo.Setup(r => r.GetByIdAsync(messageId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(message);
        _mockConvRepo.Setup(r => r.IsMemberAsync(convId, userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        _mockMsgRepo.Setup(r => r.GetReactionAsync(messageId, userId, "👍", It.IsAny<CancellationToken>()))
            .ReturnsAsync(existingReaction);
        _mockMsgRepo.Setup(r => r.GetReactionsForMessageAsync(messageId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<MessageReaction>());

        // Act
        var result = await _chatService.ToggleReactionAsync(messageId, userId, "👍");

        // Assert
        Assert.Empty(result);
        _mockMsgRepo.Verify(r => r.RemoveReactionAsync(existingReaction, It.IsAny<CancellationToken>()), Times.Once);
    }
}
