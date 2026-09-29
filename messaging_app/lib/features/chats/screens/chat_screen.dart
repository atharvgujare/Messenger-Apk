import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/services/media_upload_service.dart';
import '../../../core/services/voice_recording_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';
import '../widgets/typing_indicator_bubble.dart';
import '../widgets/voice_message_bubble.dart';
import 'image_viewer_screen.dart';

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

  // Media & Voice State
  bool _isUploading = false;
  bool _isRecordingVoice = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

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

  Future<void> _startRecording() async {
    try {
      final hasPerm = await VoiceRecordingService.instance.hasPermission();
      if (!hasPerm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required for voice notes'), behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }
      await VoiceRecordingService.instance.startRecording();
      setState(() {
        _isRecordingVoice = true;
        _recordingSeconds = 0;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) setState(() => _recordingSeconds++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordingTimer?.cancel();
    final file = await VoiceRecordingService.instance.stopRecording();
    setState(() => _isRecordingVoice = false);

    if (file != null && await file.exists()) {
      setState(() => _isUploading = true);
      try {
        final url = await MediaUploadService.instance.uploadVoiceNote(
          file: file,
          conversationId: widget.conversation.conversationId,
        );
        if (mounted) {
          await context.read<ChatProvider>().sendMessage(
            conversationId: widget.conversation.conversationId,
            content: url,
            type: MessageType.voice,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload voice note: $e'), behavior: SnackBarBehavior.floating),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    await VoiceRecordingService.instance.cancelRecording();
    if (mounted) setState(() => _isRecordingVoice = false);
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1920);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final url = await MediaUploadService.instance.uploadImage(
        file: File(picked.path),
        conversationId: widget.conversation.conversationId,
      );
      if (mounted) {
        await context.read<ChatProvider>().sendMessage(
          conversationId: widget.conversation.conversationId,
          content: url,
          type: MessageType.image,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: Colors.pink,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendImage(ImageSource.camera);
                    },
                  ),
                  _buildAttachOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color.withAlpha(35),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
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

                // Star / Unstar Option
                ListTile(
                  leading: Icon(
                    provider.isMessageStarred(message.id) ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                  ),
                  title: Text(provider.isMessageStarred(message.id) ? 'Unstar message' : 'Star message'),
                  onTap: () {
                    final wasStarred = provider.isMessageStarred(message.id);
                    Navigator.pop(bottomSheetContext);
                    provider.toggleStarMessage(message);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(wasStarred ? 'Message unstarred' : 'Message starred'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
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
    _recordingTimer?.cancel();
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
                    backgroundImage: (liveConv.avatarUrl != null && liveConv.avatarUrl!.isNotEmpty)
                        ? NetworkImage(liveConv.avatarUrl!)
                        : null,
                    onBackgroundImageError: (liveConv.avatarUrl != null && liveConv.avatarUrl!.isNotEmpty)
                        ? (_, _) {}
                        : null,
                    child: (liveConv.avatarUrl == null || liveConv.avatarUrl!.isEmpty)
                        ? Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        : null,
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
          actions: [
            IconButton(
              icon: const Icon(Icons.videocam_outlined),
              tooltip: 'Video Call',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Video call ringing...'), behavior: SnackBarBehavior.floating),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.call_outlined),
              tooltip: 'Voice Call',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Voice call ringing...'), behavior: SnackBarBehavior.floating),
                );
              },
            ),
          ],
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
                        final msgSenderId = msg.senderId.trim().toLowerCase();
                        final msgSenderUsername = msg.senderUsername.trim().toLowerCase();

                        final matchesMe = (currentUserId.isNotEmpty &&
                                (msgSenderId == currentUserId || msgSenderId.replaceAll('-', '') == currentUserId.replaceAll('-', ''))) ||
                            (currentUsername.isNotEmpty && msgSenderUsername == currentUsername);

                        final isMe = msg.status == MessageStatus.pending || matchesMe;

                        return _buildMessageBubble(context, theme, msg, isMe, provider);
                      },
                    );
                  },
                ),
              ),
              if (chatProvider.getTypingUser(widget.conversation.conversationId) != null)
                TypingIndicatorBubble(
                  username: chatProvider.getTypingUser(widget.conversation.conversationId)!,
                ),
              if (_isUploading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: AppTheme.whatsappGreen.withAlpha(25),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.whatsappGreen),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Uploading media...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.whatsappGreen,
                        ),
                      ),
                    ],
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
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 6),
                      bottomRight: Radius.circular(isMe ? 6 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 20 : 10),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
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
                              color: isMe
                                  ? (isDark ? Colors.white70 : const Color(0xFF667781))
                                  : (isDark ? Colors.white60 : Colors.grey.shade600),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'This message was deleted',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: isMe
                                    ? (isDark ? Colors.white70 : const Color(0xFF667781))
                                    : (isDark ? Colors.white60 : Colors.grey.shade600),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                      else if (message.type == MessageType.image)
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ImageViewerScreen(
                                imageUrl: message.content,
                                senderName: message.senderDisplayName,
                                timestamp: message.createdAtUtc,
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Hero(
                              tag: message.content,
                              child: Image.network(
                                message.content,
                                width: 220,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    width: 220,
                                    height: 160,
                                    color: Colors.black12,
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 220,
                                  height: 100,
                                  color: Colors.grey.withAlpha(40),
                                  child: const Center(
                                    child: Icon(Icons.broken_image, size: 36, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (message.type == MessageType.voice)
                        VoiceMessageBubble(
                          audioUrl: message.content,
                          isMe: isMe,
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

                      // Timestamp, Star indicator, Edited Tag & Status Icon
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (provider.isMessageStarred(message.id)) ...[
                            const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                            const SizedBox(width: 4),
                          ],
                          if (message.isEdited && !isDeleted) ...[
                            Text(
                              '(edited) ',
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: isMe
                                    ? (isDark ? Colors.white60 : const Color(0xFF667781))
                                    : (isDark ? Colors.white60 : const Color(0xFF667781)),
                              ),
                            ),
                          ],
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: isMe
                                  ? (isDark ? Colors.white70 : const Color(0xFF667781))
                                  : (isDark ? Colors.white60 : const Color(0xFF667781)),
                            ),
                          ),
                          if (isMe && !isDeleted) ...[
                            const SizedBox(width: 4),
                            _buildStatusIcon(message.status, isDark),
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
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe
            ? (isDark ? Colors.black.withAlpha(50) : const Color(0x18005C4B))
            : (isDark ? Colors.black.withAlpha(35) : const Color(0x0C000000)),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe
                ? (isDark ? Colors.white70 : AppTheme.whatsappGreenLight)
                : theme.colorScheme.primary,
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
              color: isMe
                  ? (isDark ? Colors.white : AppTheme.whatsappGreenLight)
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message.replyToContent ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : const Color(0xFF111B21),
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

  Widget _buildStatusIcon(MessageStatus status, bool isDark) {
    final defaultTickColor = isDark ? Colors.white70 : const Color(0xFF667781);
    const readTickColor = AppTheme.whatsappBlueCheck; // Color(0xFF53BDEB)

    switch (status) {
      case MessageStatus.pending:
        return Icon(
          Icons.access_time_rounded,
          size: 13,
          color: isDark ? Colors.white60 : const Color(0xFF667781),
        );
      case MessageStatus.sent:
        return Icon(Icons.check_rounded, size: 14, color: defaultTickColor);
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 14, color: defaultTickColor);
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded, size: 14, color: readTickColor);
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: isDark ? Colors.amberAccent : Colors.redAccent,
        );
    }
  }

  Widget _buildMessageComposer(ThemeData theme, ChatProvider provider) {
    final isEditing = provider.editingMessage != null;

    if (_isRecordingVoice) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              tooltip: 'Cancel recording',
              onPressed: _cancelRecording,
            ),
            const SizedBox(width: 8),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(_recordingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordingSeconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent),
            ),
            const Spacer(),
            const Text('Recording...', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(width: 12),
            Material(
              color: AppTheme.whatsappGreen,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _stopAndSendRecording,
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 24, color: AppTheme.whatsappGreen),
            tooltip: 'Share photo',
            onPressed: _isUploading ? null : _showAttachmentSheet,
          ),
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
            color: (_canSend || isEditing) ? theme.colorScheme.primary : AppTheme.whatsappGreen,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                if (isEditing || _canSend) {
                  _handleSendMessage();
                } else {
                  _startRecording();
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Icon(
                  isEditing
                      ? Icons.check_rounded
                      : (_canSend ? Icons.send_rounded : Icons.mic_rounded),
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

