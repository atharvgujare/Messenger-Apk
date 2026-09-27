import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _canSend = false;
  bool _isTyping = false;
  Timer? _typingThrottleTimer;
  String? _lastObservedEditingId;

  static const List<String> _quickEmojis = ['❤️', '👍', '😂', '😮', '😢', '🙏', '🔥'];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().enterConversation(widget.conversation.conversationId).then((_) {
        _scrollToBottom();
      });
    });
  }

  void _onTextChanged() {
    final text = _textController.text.trim();
    final hasText = text.isNotEmpty;

    if (hasText != _canSend) {
      setState(() {
        _canSend = hasText;
      });
    }

    final chatProvider = context.read<ChatProvider>();
    if (hasText) {
      if (!_isTyping) {
        _isTyping = true;
        chatProvider.sendTyping(widget.conversation.conversationId, true);
      }
      _typingThrottleTimer?.cancel();
      _typingThrottleTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          _isTyping = false;
          chatProvider.sendTyping(widget.conversation.conversationId, false);
        }
      });
    } else if (_isTyping) {
      _isTyping = false;
      _typingThrottleTimer?.cancel();
      chatProvider.sendTyping(widget.conversation.conversationId, false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final provider = context.read<ChatProvider>();

    // Message editing mode
    if (provider.editingMessage != null) {
      final msgId = provider.editingMessage!.id;
      _textController.clear();
      setState(() => _canSend = false);
      await provider.editMessage(msgId, text);
      return;
    }

    if (_isTyping) {
      _isTyping = false;
      _typingThrottleTimer?.cancel();
      provider.sendTyping(widget.conversation.conversationId, false);
    }

    final replyId = provider.replyingToMessage?.id;
    _textController.clear();
    setState(() => _canSend = false);

    await provider.sendMessage(
      conversationId: widget.conversation.conversationId,
      content: text,
      replyToMessageId: replyId,
    );

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _startEditing(MessageModel message) {
    context.read<ChatProvider>().setEditing(message);
    _textController.text = message.content;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
    _focusNode.requestFocus();
  }

  void _startReplying(MessageModel message) {
    context.read<ChatProvider>().setReplyingTo(message);
    _focusNode.requestFocus();
  }

  void _showMessageActionMenu(MessageModel message, bool isMe) {
    if (message.isDeletedForEveryone) return;

    final theme = Theme.of(context);
    final provider = context.read<ChatProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardTheme.color ?? theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Emoji Reaction Quick Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _quickEmojis.map((emoji) {
                      final hasReacted = message.reactions.any((r) => r.emoji == emoji && r.hasReacted);
                      return InkWell(
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          provider.toggleReaction(message.id, emoji);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: hasReacted
                              ? BoxDecoration(
                                  color: theme.colorScheme.primary.withAlpha(50),
                                  shape: BoxShape.circle,
                                )
                              : null,
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),

                // 2. Reply Option
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _startReplying(message);
                  },
                ),

                // 3. Edit Option (Sender only, non-deleted)
                if (isMe)
                  ListTile(
                    leading: const Icon(Icons.edit_rounded),
                    title: const Text('Edit'),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _startEditing(message);
                    },
                  ),

                // 4. Copy Text
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy text'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    Navigator.pop(bottomSheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),

                // 5. Delete Options
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text('Delete for me', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    provider.deleteMessage(message.id, forEveryone: false);
                  },
                ),

                if (isMe)
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                    title: const Text('Delete for everyone', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      provider.deleteMessage(message.id, forEveryone: true);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _typingThrottleTimer?.cancel();
    if (_isTyping && mounted) {
      context.read<ChatProvider>().sendTyping(widget.conversation.conversationId, false);
    }
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.currentUserId.trim().toLowerCase();
    final currentUsername = auth.currentUsername.trim().toLowerCase();
    final chatProvider = context.watch<ChatProvider>();

    // Live update of conversation state & presence
    final liveConv = chatProvider.conversations.firstWhere(
      (c) => c.conversationId == widget.conversation.conversationId,
      orElse: () => widget.conversation,
    );
    final other = liveConv.otherParticipant;
    final title = liveConv.title;
    final initials = liveConv.initials;
    final isOnline = other?.isOnline ?? false;
    final typingUser = chatProvider.getTypingUser(widget.conversation.conversationId);

    // Keep editing message input in sync if changed from provider
    if (chatProvider.editingMessage != null && chatProvider.editingMessage!.id != _lastObservedEditingId) {
      _lastObservedEditingId = chatProvider.editingMessage!.id;
      _textController.text = chatProvider.editingMessage!.content;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    } else if (chatProvider.editingMessage == null && _lastObservedEditingId != null) {
      _lastObservedEditingId = null;
      _textController.clear();
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          context.read<ChatProvider>().leaveConversation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    _buildSubtitle(typingUser, isOnline, other?.username),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Consumer<ChatProvider>(
                  builder: (context, provider, _) {
                    final messages = provider.getMessagesFor(widget.conversation.conversationId);

                    if (provider.isLoadingMessages && messages.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 64,
                              color: theme.colorScheme.primary.withAlpha(80),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Send a message to start the conversation!',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = (currentUserId.isNotEmpty && msg.senderId.trim().toLowerCase() == currentUserId) ||
                                     (currentUsername.isNotEmpty && msg.senderUsername.trim().toLowerCase() == currentUsername);
                        return _buildMessageBubble(context, theme, msg, isMe, provider);
                      },
                    );
                  },
                ),
              ),
              _buildReplyOrEditBanner(theme, chatProvider),
              _buildMessageComposer(theme, chatProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(String? typingUser, bool isOnline, String? username) {
    if (typingUser != null) {
      return const Row(
        children: [
          Text(
            'typing...',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppTheme.accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    if (isOnline) {
      return const Text(
        'online',
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.accentColor,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Text(
      username != null ? '@$username' : 'offline',
      style: const TextStyle(fontSize: 12, color: Colors.grey),
    );
  }

  Widget _buildReplyOrEditBanner(ThemeData theme, ChatProvider provider) {
    if (provider.replyingToMessage != null) {
      final replyMsg = provider.replyingToMessage!;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        child: Row(
          children: [
            Container(
              width: 4,
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Replying to ${replyMsg.senderDisplayName}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    replyMsg.content,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => provider.cancelReply(),
            ),
          ],
        ),
      );
    }

    if (provider.editingMessage != null) {
      final editMsg = provider.editingMessage!;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        child: Row(
          children: [
            const Icon(Icons.edit_rounded, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Edit Message',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    editMsg.content,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () {
                provider.cancelEdit();
                _textController.clear();
              },
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMessageBubble(
    BuildContext context,
    ThemeData theme,
    MessageModel message,
    bool isMe,
    ChatProvider provider,
  ) {
    final timeStr = DateFormat('h:mm a').format(message.createdAtUtc);
    final isDeleted = message.isDeletedForEveryone;

    final isDark = theme.brightness == Brightness.dark;
    final isGroup = widget.conversation.type == ConversationType.group;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onLongPress: () => _showMessageActionMenu(message, isMe),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDeleted
                        ? (isMe
                            ? (isDark ? AppTheme.darkBubbleMine.withAlpha(150) : AppTheme.lightBubbleMine.withAlpha(150))
                            : (isDark ? AppTheme.darkBubbleOther.withAlpha(150) : Colors.grey.withAlpha(50)))
                        : (isMe
                            ? (isDark ? AppTheme.darkBubbleMine : AppTheme.lightBubbleMine)
                            : (isDark ? AppTheme.darkBubbleOther : AppTheme.lightBubbleOther)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(12),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // Sender name for group chats
                      if (isGroup && !isMe && !isDeleted)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            message.senderDisplayName.isNotEmpty ? message.senderDisplayName : message.senderUsername,
                            style: TextStyle(
                              color: _getSenderColor(message.senderId),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      // Quoted Reply Preview
                      if (message.replyToMessageId != null && !isDeleted)
                        _buildQuotedReplyPreview(theme, message, isMe),


                      // Message Content
                      if (isDeleted)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.block_rounded,
                              size: 14,
                              color: isMe ? Colors.white70 : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'This message was deleted',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: isMe ? Colors.white70 : Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          message.content,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF111B21),
                            fontSize: 15,
                          ),
                        ),
                      const SizedBox(height: 4),


                      // Timestamp, Edited Tag & Status Icon
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.isEdited && !isDeleted) ...[
                            Text(
                              '(edited) ',
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: isMe ? Colors.white60 : Colors.grey,
                              ),
                            ),
                          ],
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: isMe ? Colors.white70 : Colors.grey,
                            ),
                          ),
                          if (isMe && !isDeleted) ...[
                            const SizedBox(width: 4),
                            _buildStatusIcon(message.status),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Emoji Reactions Pill Bar
          if (message.reactions.isNotEmpty && !isDeleted)
            Padding(
              padding: const EdgeInsets.only(top: 3.0),
              child: _buildReactionChips(theme, message, provider),
            ),
        ],
      ),
    );
  }

  Widget _buildQuotedReplyPreview(ThemeData theme, MessageModel message, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? Colors.black.withAlpha(35) : Colors.black.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : theme.colorScheme.primary,
            width: 3.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.replyToSenderDisplayName ?? message.replyToSenderUsername ?? 'Original Message',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message.replyToContent ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMe ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionChips(ThemeData theme, MessageModel message, ChatProvider provider) {
    return Wrap(
      spacing: 4,
      children: message.reactions.map((r) {
        return GestureDetector(
          onTap: () => provider.toggleReaction(message.id, r.emoji),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: r.hasReacted
                  ? theme.colorScheme.primary.withAlpha(50)
                  : (theme.cardTheme.color ?? theme.colorScheme.surface),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: r.hasReacted ? theme.colorScheme.primary : Colors.grey.withAlpha(50),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.emoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 3),
                Text(
                  '${r.count}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: r.hasReacted ? theme.colorScheme.primary : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return const Icon(Icons.access_time_rounded, size: 13, color: Colors.white70);
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded, size: 14, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded, size: 14, color: Colors.white70);
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF64FFDA));
      case MessageStatus.failed:
        return const Icon(Icons.error_outline_rounded, size: 14, color: Colors.amberAccent);
    }
  }

  Widget _buildMessageComposer(ThemeData theme, ChatProvider provider) {
    final isEditing = provider.editingMessage != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerTheme.color ?? Colors.grey.withAlpha(30),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: isEditing ? 'Edit your message...' : 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _handleSendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _canSend ? theme.colorScheme.primary : Colors.grey.shade400,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _canSend ? _handleSendMessage : null,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Icon(
                  isEditing ? Icons.check_rounded : Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSenderColor(String senderId) {
    const colors = [
      Color(0xFFE542A3),
      Color(0xFF1F7A8C),
      Color(0xFFD97706),
      Color(0xFF25D366),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
    ];
    final hash = senderId.hashCode.abs();
    return colors[hash % colors.length];
  }
}

