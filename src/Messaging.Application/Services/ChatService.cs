using Messaging.Application.Common.Exceptions;
using Messaging.Application.Common.Interfaces;
using Messaging.Application.DTOs.Chats;
using Messaging.Application.DTOs.Users;
using Messaging.Domain.Entities;
using Messaging.Domain.Enums;

namespace Messaging.Application.Services;

public class ChatService : IChatService
{
    private readonly IConversationRepository _conversationRepository;
    private readonly IMessageRepository _messageRepository;
    private readonly IUserRepository _userRepository;

    public ChatService(
        IConversationRepository conversationRepository,
        IMessageRepository messageRepository,
        IUserRepository userRepository)
    {
        _conversationRepository = conversationRepository;
        _messageRepository = messageRepository;
        _userRepository = userRepository;
    }

    public async Task<ConversationDto> GetOrCreateDirectConversationAsync(
        Guid currentUserId, 
        Guid recipientUserId, 
        CancellationToken ct = default)
    {
        if (currentUserId == recipientUserId)
        {
            throw new ValidationException("RecipientUserId", "Cannot start a conversation with yourself.");
        }

        var recipient = await _userRepository.GetByIdAsync(recipientUserId, ct);
        if (recipient == null || !recipient.IsActive)
        {
            throw new NotFoundException("Recipient user not found.");
        }

        var existingConv = await _conversationRepository.GetDirectConversationAsync(currentUserId, recipientUserId, ct);
        if (existingConv != null)
        {
            return await MapToConversationDtoAsync(existingConv, currentUserId, ct);
        }

        var newConv = new Conversation
        {
            Id = Guid.NewGuid(),
            Type = ConversationType.Direct,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        };

        var memberA = new ConversationMember
        {
            ConversationId = newConv.Id,
            UserId = currentUserId,
            JoinedAtUtc = DateTime.UtcNow
        };

        var memberB = new ConversationMember
        {
            ConversationId = newConv.Id,
            UserId = recipientUserId,
            JoinedAtUtc = DateTime.UtcNow
        };

        newConv.Members.Add(memberA);
        newConv.Members.Add(memberB);

        await _conversationRepository.AddConversationAsync(newConv, ct);
        await _conversationRepository.SaveChangesAsync(ct);

        return await MapToConversationDtoAsync(newConv, currentUserId, ct);
    }

    public async Task<IReadOnlyList<ConversationDto>> GetUserConversationsAsync(
        Guid currentUserId, 
        CancellationToken ct = default)
    {
        var conversations = await _conversationRepository.GetUserConversationsAsync(currentUserId, ct);
        var dtos = new List<ConversationDto>();

        foreach (var conv in conversations)
        {
            dtos.Add(await MapToConversationDtoAsync(conv, currentUserId, ct));
        }

        return dtos.OrderByDescending(c => c.IsPinned).ThenByDescending(c => c.UpdatedAtUtc).ToList();
    }

    public async Task<IReadOnlyList<MessageDto>> GetConversationMessagesAsync(
        Guid conversationId, 
        Guid currentUserId, 
        DateTime? beforeTimestamp = null, 
        int limit = 50, 
        CancellationToken ct = default)
    {
        var isMember = await _conversationRepository.IsMemberAsync(conversationId, currentUserId, ct);
        if (!isMember)
        {
            throw new UnauthorizedException("You are not a member of this conversation.");
        }

        var messages = await _messageRepository.GetMessagesAsync(conversationId, currentUserId, beforeTimestamp, limit, ct);

        return messages.Select(m => MapToMessageDto(m, currentUserId)).ToList();
    }

    public async Task<MessageDto> SendMessageAsync(
        Guid senderId, 
        SendMessageRequest request, 
        CancellationToken ct = default)
    {
        var isMember = await _conversationRepository.IsMemberAsync(request.ConversationId, senderId, ct);
        if (!isMember)
        {
            throw new UnauthorizedException("You are not a member of this conversation.");
        }

        var sender = await _userRepository.GetByIdAsync(senderId, ct);
        if (sender == null || !sender.IsActive)
        {
            throw new UnauthorizedException("Sender account is inactive or not found.");
        }

        var conversation = await _conversationRepository.GetByIdAsync(request.ConversationId, ct);
        if (conversation == null)
        {
            throw new NotFoundException("Conversation not found.");
        }

        Message? replyToMsg = null;
        if (request.ReplyToMessageId.HasValue)
        {
            replyToMsg = await _messageRepository.GetByIdAsync(request.ReplyToMessageId.Value, ct);
        }

        var message = new Message
        {
            Id = Guid.NewGuid(),
            ConversationId = request.ConversationId,
            SenderId = senderId,
            Type = request.Type,
            Content = request.Content.Trim(),
            ReplyToMessageId = request.ReplyToMessageId,
            ReplyToMessage = replyToMsg,
            CreatedAtUtc = DateTime.UtcNow,
            Status = MessageStatus.Sent,
            Sender = sender,
            Conversation = conversation
        };

        await _messageRepository.AddMessageAsync(message, ct);

        conversation.LastMessageId = message.Id;
        conversation.UpdatedAtUtc = message.CreatedAtUtc;
        await _conversationRepository.UpdateConversationAsync(conversation, ct);

        await _messageRepository.SaveChangesAsync(ct);

        var dto = MapToMessageDto(message, senderId);
        dto.ClientGeneratedId = request.ClientGeneratedId;
        return dto;
    }

    public async Task<IReadOnlyList<Guid>> GetConversationParticipantUserIdsAsync(
        Guid conversationId, 
        CancellationToken ct = default)
    {
        return await _conversationRepository.GetMemberUserIdsAsync(conversationId, ct);
    }

    public async Task MarkMessageDeliveredAsync(
        Guid messageId, 
        Guid recipientUserId, 
        CancellationToken ct = default)
    {
        var message = await _messageRepository.GetByIdAsync(messageId, ct);
        if (message == null) return;

        var isMember = await _conversationRepository.IsMemberAsync(message.ConversationId, recipientUserId, ct);
        if (!isMember) return;

        // If the recipient is not the sender, mark as delivered
        if (message.SenderId != recipientUserId)
        {
            await _messageRepository.MarkMessageAsDeliveredAsync(messageId, ct);
        }
    }

    public async Task<DateTime> MarkConversationReadAsync(
        Guid conversationId, 
        Guid readerUserId, 
        CancellationToken ct = default)
    {
        var isMember = await _conversationRepository.IsMemberAsync(conversationId, readerUserId, ct);
        if (!isMember)
        {
            throw new UnauthorizedException("You are not a member of this conversation.");
        }

        var member = await _conversationRepository.GetMemberAsync(conversationId, readerUserId, ct);
        var conv = await _conversationRepository.GetByIdAsync(conversationId, ct);
        if (conv == null)
        {
            throw new NotFoundException("Conversation not found.");
        }

        var readAtUtc = DateTime.UtcNow;

        if (member != null)
        {
            member.LastReadMessageId = conv.LastMessageId;
            member.LastReadAtUtc = readAtUtc;
            await _conversationRepository.UpdateMemberAsync(member, ct);
            await _conversationRepository.SaveChangesAsync(ct);
        }

        await _messageRepository.MarkMessagesAsReadAsync(conversationId, readerUserId, readAtUtc, ct);

        return readAtUtc;
    }

    private async Task<ConversationDto> MapToConversationDtoAsync(
        Conversation conv, 
        Guid currentUserId, 
        CancellationToken ct)
    {
        var member = conv.Members.FirstOrDefault(m => m.UserId == currentUserId);
        var isPinned = member?.IsPinned ?? false;
        var isMuted = member?.IsMuted ?? false;
        var isArchived = member?.IsArchived ?? false;

        string title = conv.Title ?? "Direct Chat";
        string? avatarUrl = conv.AvatarUrl;
        UserSearchResultDto? otherParticipantDto = null;

        if (conv.Type == ConversationType.Direct)
        {
            var otherMember = conv.Members.FirstOrDefault(m => m.UserId != currentUserId);
            if (otherMember != null)
            {
                var otherUser = otherMember.User ?? await _userRepository.GetByIdAsync(otherMember.UserId, ct);
                if (otherUser != null)
                {
                    var profile = otherUser.Profile ?? new UserProfile { DisplayName = otherUser.Username };
                    title = profile.DisplayName;
                    avatarUrl = profile.AvatarUrl;

                    otherParticipantDto = new UserSearchResultDto
                    {
                        UserId = otherUser.Id,
                        Username = otherUser.Username,
                        DisplayName = profile.DisplayName,
                        AvatarUrl = profile.AvatarUrl,
                        Bio = profile.Bio,
                        IsOnline = profile.IsOnline,
                        LastSeenAtUtc = profile.LastSeenAtUtc
                    };
                }
            }
        }

        var lastMessageDto = conv.LastMessage != null ? MapToMessageDto(conv.LastMessage) : null;
        var unreadCount = await _messageRepository.GetUnreadCountAsync(conv.Id, currentUserId, member?.LastReadMessageId, ct);

        return new ConversationDto
        {
            ConversationId = conv.Id,
            Type = conv.Type,
            Title = title,
            AvatarUrl = avatarUrl,
            IsPinned = isPinned,
            IsMuted = isMuted,
            IsArchived = isArchived,
            UnreadCount = unreadCount,
            UpdatedAtUtc = conv.UpdatedAtUtc,
            LastMessage = lastMessageDto,
            OtherParticipant = otherParticipantDto
        };
    }

    public async Task<MessageDto> EditMessageAsync(
        Guid messageId, 
        Guid userId, 
        string newContent, 
        CancellationToken ct = default)
    {
        var message = await _messageRepository.GetByIdAsync(messageId, ct);
        if (message == null)
        {
            throw new NotFoundException("Message not found.");
        }

        if (message.SenderId != userId)
        {
            throw new UnauthorizedException("You can only edit your own messages.");
        }

        if (message.IsDeletedForEveryone)
        {
            throw new ValidationException("Message", "Cannot edit a deleted message.");
        }

        message.Content = newContent.Trim();
        message.IsEdited = true;
        message.UpdatedAtUtc = DateTime.UtcNow;

        await _messageRepository.UpdateMessageAsync(message, ct);
        await _messageRepository.SaveChangesAsync(ct);

        return MapToMessageDto(message, userId);
    }

    public async Task<bool> DeleteMessageAsync(
        Guid messageId, 
        Guid userId, 
        bool forEveryone, 
        CancellationToken ct = default)
    {
        var message = await _messageRepository.GetByIdAsync(messageId, ct);
        if (message == null)
        {
            throw new NotFoundException("Message not found.");
        }

        var isMember = await _conversationRepository.IsMemberAsync(message.ConversationId, userId, ct);
        if (!isMember)
        {
            throw new UnauthorizedException("You are not a member of this conversation.");
        }

        if (forEveryone)
        {
            if (message.SenderId != userId)
            {
                throw new UnauthorizedException("You can only delete your own messages for everyone.");
            }

            message.IsDeletedForEveryone = true;
            message.Content = "This message was deleted";
            message.UpdatedAtUtc = DateTime.UtcNow;

            await _messageRepository.UpdateMessageAsync(message, ct);
            await _messageRepository.SaveChangesAsync(ct);
            return true;
        }
        else
        {
            var alreadyDeleted = await _messageRepository.IsDeletedForUserAsync(messageId, userId, ct);
            if (!alreadyDeleted)
            {
                var deletion = new MessageUserDeletion
                {
                    MessageId = messageId,
                    UserId = userId,
                    DeletedAtUtc = DateTime.UtcNow
                };
                await _messageRepository.AddUserDeletionAsync(deletion, ct);
                await _messageRepository.SaveChangesAsync(ct);
            }
            return false;
        }
    }

    public async Task<List<MessageReactionDto>> ToggleReactionAsync(
        Guid messageId, 
        Guid userId, 
        string emoji, 
        CancellationToken ct = default)
    {
        var message = await _messageRepository.GetByIdAsync(messageId, ct);
        if (message == null)
        {
            throw new NotFoundException("Message not found.");
        }

        var isMember = await _conversationRepository.IsMemberAsync(message.ConversationId, userId, ct);
        if (!isMember)
        {
            throw new UnauthorizedException("You are not a member of this conversation.");
        }

        if (message.IsDeletedForEveryone)
        {
            throw new ValidationException("Message", "Cannot react to a deleted message.");
        }

        var existingReaction = await _messageRepository.GetReactionAsync(messageId, userId, emoji, ct);
        if (existingReaction != null)
        {
            await _messageRepository.RemoveReactionAsync(existingReaction, ct);
        }
        else
        {
            var newReaction = new MessageReaction
            {
                Id = Guid.NewGuid(),
                MessageId = messageId,
                UserId = userId,
                Emoji = emoji.Trim(),
                CreatedAtUtc = DateTime.UtcNow
            };
            await _messageRepository.AddReactionAsync(newReaction, ct);
        }

        await _messageRepository.SaveChangesAsync(ct);

        var allReactions = await _messageRepository.GetReactionsForMessageAsync(messageId, ct);
        return allReactions
            .GroupBy(r => r.Emoji)
            .Select(g => new MessageReactionDto
            {
                Emoji = g.Key,
                Count = g.Count(),
                UserIds = g.Select(r => r.UserId).ToList(),
                HasReacted = g.Any(r => r.UserId == userId)
            })
            .ToList();
    }

    public async Task<ConversationDto> CreateGroupConversationAsync(
        Guid creatorUserId, 
        CreateGroupRequest request, 
        CancellationToken ct = default)
    {
        var title = request.Title?.Trim();
        if (string.IsNullOrWhiteSpace(title))
        {
            throw new ValidationException("Title", "Group name/subject cannot be empty.");
        }

        var newConv = new Conversation
        {
            Id = Guid.NewGuid(),
            Type = ConversationType.Group,
            Title = title,
            AvatarUrl = request.AvatarUrl,
            CreatedByUserId = creatorUserId,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        };

        // Add creator
        newConv.Members.Add(new ConversationMember
        {
            ConversationId = newConv.Id,
            UserId = creatorUserId,
            JoinedAtUtc = DateTime.UtcNow,
            IsAdmin = true
        });

        // Add member users
        var validUserIds = request.MemberUserIds
            .Where(id => id != creatorUserId)
            .Distinct();

        foreach (var memberId in validUserIds)
        {
            var user = await _userRepository.GetByIdAsync(memberId, ct);
            if (user != null && user.IsActive)
            {
                newConv.Members.Add(new ConversationMember
                {
                    ConversationId = newConv.Id,
                    UserId = memberId,
                    JoinedAtUtc = DateTime.UtcNow,
                    IsAdmin = false
                });
            }
        }

        await _conversationRepository.AddConversationAsync(newConv, ct);
        await _conversationRepository.SaveChangesAsync(ct);

        return await MapToConversationDtoAsync(newConv, creatorUserId, ct);
    }

    public async Task<bool> TogglePinConversationAsync(
        Guid conversationId, 
        Guid userId, 
        CancellationToken ct = default)
    {
        var member = await _conversationRepository.GetMemberAsync(conversationId, userId, ct);
        if (member == null)
        {
            throw new UnauthorizedException("You are not a member of this conversation.");
        }

        member.IsPinned = !member.IsPinned;
        await _conversationRepository.UpdateMemberAsync(member, ct);
        await _conversationRepository.SaveChangesAsync(ct);

        return member.IsPinned;
    }

    private static MessageDto MapToMessageDto(Message m, Guid? currentUserId = null)
    {
        string? replyToSenderUsername = null;
        string? replyToSenderDisplayName = null;
        string? replyToContent = null;

        if (m.ReplyToMessage != null)
        {
            replyToSenderUsername = m.ReplyToMessage.Sender?.Username;
            replyToSenderDisplayName = m.ReplyToMessage.Sender?.Profile?.DisplayName ?? m.ReplyToMessage.Sender?.Username;
            replyToContent = m.ReplyToMessage.IsDeletedForEveryone ? "This message was deleted" : m.ReplyToMessage.Content;
        }

        var reactions = m.Reactions?
            .GroupBy(r => r.Emoji)
            .Select(g => new MessageReactionDto
            {
                Emoji = g.Key,
                Count = g.Count(),
                UserIds = g.Select(r => r.UserId).ToList(),
                HasReacted = currentUserId.HasValue && g.Any(r => r.UserId == currentUserId.Value)
            })
            .ToList() ?? new List<MessageReactionDto>();

        return new MessageDto
        {
            Id = m.Id,
            ConversationId = m.ConversationId,
            SenderId = m.SenderId,
            SenderUsername = m.Sender?.Username ?? string.Empty,
            SenderDisplayName = m.Sender?.Profile?.DisplayName ?? m.Sender?.Username ?? string.Empty,
            Type = m.Type,
            Content = m.IsDeletedForEveryone ? "This message was deleted" : m.Content,
            CreatedAtUtc = m.CreatedAtUtc,
            UpdatedAtUtc = m.UpdatedAtUtc,
            IsEdited = m.IsEdited,
            IsDeletedForEveryone = m.IsDeletedForEveryone,
            Status = m.Status,
            ReplyToMessageId = m.ReplyToMessageId,
            ReplyToSenderUsername = replyToSenderUsername,
            ReplyToSenderDisplayName = replyToSenderDisplayName,
            ReplyToContent = replyToContent,
            Reactions = reactions
        };
    }
}
