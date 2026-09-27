import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/signalr_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class ChatProvider extends ChangeNotifier {
  final ApiClient _apiClient;
  final SignalRService _signalRService;
  final AuthProvider _authProvider;
  final Uuid _uuid = const Uuid();

  List<ConversationModel> _conversations = [];
  final Map<String, List<MessageModel>> _conversationMessages = {};
  final Map<String, String?> _typingStatus = {};
  final Map<String, Timer?> _typingTimers = {};

  bool _isLoadingConversations = false;
  bool _isLoadingMessages = false;
  String? _activeConversationId;
  String? _error;

  StreamSubscription? _msgReceivedSub;
  StreamSubscription? _msgSentSub;
  StreamSubscription? _convUpdatedSub;
  StreamSubscription? _msgDeliveredSub;
  StreamSubscription? _msgsReadSub;
  StreamSubscription? _presenceSub;
  StreamSubscription? _typingSub;

  List<ConversationModel> get conversations => _conversations;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get activeConversationId => _activeConversationId;
  String? get error => _error;

  List<MessageModel> getMessagesFor(String conversationId) =>
      _conversationMessages[conversationId] ?? [];

  String? getTypingUser(String conversationId) => _typingStatus[conversationId];

  ChatProvider(this._apiClient, this._signalRService, this._authProvider) {
    _initSignalRSubscriptions();
  }

  void _initSignalRSubscriptions() {
    _msgReceivedSub = _signalRService.onMessageReceived.listen(_handleIncomingMessage);
    _msgSentSub = _signalRService.onMessageSent.listen(_handleMessageConfirmation);
    _convUpdatedSub = _signalRService.onConversationUpdated.listen(_handleConversationUpdated);
    _msgDeliveredSub = _signalRService.onMessageDelivered.listen(_handleMessageDelivered);
    _msgsReadSub = _signalRService.onMessagesRead.listen(_handleMessagesRead);
    _presenceSub = _signalRService.onUserPresenceChanged.listen(_handleUserPresenceChanged);
    _typingSub = _signalRService.onUserTyping.listen(_handleUserTyping);
  }

  Future<void> connectRealTime() async {
    await _signalRService.connect();
  }

  Future<void> loadConversations() async {
    _isLoadingConversations = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/conversations');
      if (response is List) {
        _conversations = response
            .map((c) => ConversationModel.fromJson(c as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  Future<ConversationModel?> getOrCreateDirectConversation(String recipientUserId) async {
    try {
      final response = await _apiClient.post(
        '/conversations/direct',
        body: {'recipientUserId': recipientUserId},
      );
      if (response is Map<String, dynamic>) {
        final conversation = ConversationModel.fromJson(response);
        final index = _conversations.indexWhere((c) => c.conversationId == conversation.conversationId);
        if (index != -1) {
          _conversations[index] = conversation;
        } else {
          _conversations.insert(0, conversation);
        }
        notifyListeners();
        return conversation;
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
    return null;
  }

  Future<void> enterConversation(String conversationId) async {
    _activeConversationId = conversationId;
    await _signalRService.joinConversation(conversationId);
    await loadMessages(conversationId);
    await markConversationAsRead(conversationId);
  }

  Future<void> leaveConversation() async {
    if (_activeConversationId != null) {
      await _signalRService.leaveConversation(_activeConversationId!);
      _activeConversationId = null;
    }
  }

  Future<void> loadMessages(String conversationId) async {
    _isLoadingMessages = true;
    notifyListeners();

    try {
      final response = await _apiClient.get('/conversations/$conversationId/messages?limit=50');
      if (response is List) {
        final messages = response
            .map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
            .toList();

        // Sort chronological (oldest at index 0, latest at the end)
        messages.sort((a, b) => a.createdAtUtc.compareTo(b.createdAtUtc));
        _conversationMessages[conversationId] = messages;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage({
    required String conversationId,
    required String content,
    String? replyToMessageId,
  }) async {
    if (content.trim().isEmpty) return;

    final clientGeneratedId = _uuid.v4();
    final currentUser = _authProvider.currentUser;

    // Create optimistic message
    final optimisticMessage = MessageModel(
      id: clientGeneratedId,
      conversationId: conversationId,
      senderId: currentUser?.id ?? '',
      senderUsername: currentUser?.username ?? '',
      senderDisplayName: currentUser?.displayName ?? currentUser?.username ?? 'You',
      type: MessageType.text,
      content: content.trim(),
      createdAtUtc: DateTime.now(),
      status: MessageStatus.pending,
      replyToMessageId: replyToMessageId,
      clientGeneratedId: clientGeneratedId,
    );

    // Add optimistically to UI
    if (!_conversationMessages.containsKey(conversationId)) {
      _conversationMessages[conversationId] = [];
    }
    _conversationMessages[conversationId]!.add(optimisticMessage);
    _updateConversationLastMessage(conversationId, optimisticMessage);
    notifyListeners();

    final payload = {
      'conversationId': conversationId,
      'content': content.trim(),
      'type': 0, // text
      'replyToMessageId': replyToMessageId,
      'clientGeneratedId': clientGeneratedId,
    };

    try {
      MessageModel? confirmed;
      // 1. Try real-time SignalR
      try {
        confirmed = await _signalRService.sendMessage(payload);
      } catch (signalREx) {
        debugPrint('[ChatProvider] SignalR send failed, trying HTTP fallback: $signalREx');
      }

      // 2. HTTP Fallback if SignalR returned null or failed
      if (confirmed == null) {
        final httpResponse = await _apiClient.post(
          '/conversations/$conversationId/messages',
          body: payload,
        );
        if (httpResponse is Map<String, dynamic>) {
          confirmed = MessageModel.fromJson(httpResponse);
        }
      }

      if (confirmed != null) {
        _handleMessageConfirmation(confirmed);
      }
    } catch (e) {
      debugPrint('[ChatProvider] Failed to send message: $e');
      // Mark as failed
      final list = _conversationMessages[conversationId];
      if (list != null) {
        final idx = list.indexWhere((m) => m.clientGeneratedId == clientGeneratedId);
        if (idx != -1) {
          list[idx] = list[idx].copyWith(status: MessageStatus.failed);
          notifyListeners();
        }
      }
    }
  }

  Future<void> markMessageDelivered(String messageId, String conversationId) async {
    await _signalRService.markMessageDelivered(messageId, conversationId);
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final idx = _conversations.indexWhere((c) => c.conversationId == conversationId);
    if (idx != -1 && _conversations[idx].unreadCount > 0) {
      _conversations[idx] = _conversations[idx].copyWith(unreadCount: 0);
      notifyListeners();
    }

    try {
      await _signalRService.markConversationAsRead(conversationId);
    } catch (_) {
      try {
        await _apiClient.post('/conversations/$conversationId/read');
      } catch (_) {}
    }
  }

  void sendTyping(String conversationId, bool isTyping) {
    _signalRService.sendTypingIndicator(conversationId, isTyping);
  }

  void _handleIncomingMessage(MessageModel message) {
    final convId = message.conversationId;
    if (!_conversationMessages.containsKey(convId)) {
      _conversationMessages[convId] = [];
    }

    final list = _conversationMessages[convId]!;
    final alreadyExists = list.any((m) =>
        m.id == message.id ||
        (message.clientGeneratedId != null && m.clientGeneratedId == message.clientGeneratedId));

    if (!alreadyExists) {
      list.add(message);
      list.sort((a, b) => a.createdAtUtc.compareTo(b.createdAtUtc));
    }

    final isCurrentActive = _activeConversationId == convId;
    _updateConversationLastMessage(convId, message, incrementUnread: !isCurrentActive);

    // Auto mark delivered and read if we are actively in this conversation
    markMessageDelivered(message.id, convId);
    if (isCurrentActive) {
      markConversationAsRead(convId);
    }

    notifyListeners();
  }

  void _handleMessageConfirmation(MessageModel message) {
    final convId = message.conversationId;
    final list = _conversationMessages[convId];
    if (list != null) {
      final idx = list.indexWhere((m) =>
          m.id == message.id ||
          (message.clientGeneratedId != null && m.clientGeneratedId == message.clientGeneratedId));

      if (idx != -1) {
        list[idx] = message;
      } else {
        list.add(message);
      }
      list.sort((a, b) => a.createdAtUtc.compareTo(b.createdAtUtc));
    }

    _updateConversationLastMessage(convId, message);
    notifyListeners();
  }

  void _handleMessageDelivered(Map<String, dynamic> data) {
    final messageId = data['messageId'] as String?;
    final convId = data['conversationId'] as String?;
    if (convId == null || messageId == null) return;

    final list = _conversationMessages[convId];
    if (list != null) {
      final idx = list.indexWhere((m) => m.id == messageId);
      if (idx != -1 && list[idx].status == MessageStatus.sent) {
        list[idx] = list[idx].copyWith(status: MessageStatus.delivered);
        _updateConversationLastMessage(convId, list[idx]);
        notifyListeners();
      }
    }
  }

  void _handleMessagesRead(Map<String, dynamic> data) {
    final convId = data['conversationId'] as String?;
    final readByUserId = data['readByUserId'] as String?;
    final readAtUtc = data['readAtUtc'] as DateTime?;
    if (convId == null) return;

    final currentUserId = _authProvider.currentUser?.id;

    // If current user read it, clear unread count
    if (readByUserId == currentUserId) {
      final idx = _conversations.indexWhere((c) => c.conversationId == convId);
      if (idx != -1) {
        _conversations[idx] = _conversations[idx].copyWith(unreadCount: 0);
      }
    }

    // Mark messages sent before readAtUtc as Read
    final list = _conversationMessages[convId];
    if (list != null && readAtUtc != null) {
      bool updated = false;
      for (int i = 0; i < list.length; i++) {
        if (list[i].status != MessageStatus.read &&
            !list[i].createdAtUtc.isAfter(readAtUtc)) {
          list[i] = list[i].copyWith(status: MessageStatus.read);
          updated = true;
        }
      }
      if (updated) {
        if (list.isNotEmpty) {
          _updateConversationLastMessage(convId, list.last);
        }
        notifyListeners();
      }
    }
  }

  void _handleUserPresenceChanged(Map<String, dynamic> data) {
    final userId = data['userId'] as String?;
    final isOnline = data['isOnline'] == true;
    final lastSeen = data['lastSeenAtUtc'] as DateTime?;
    if (userId == null) return;

    bool updated = false;
    for (int i = 0; i < _conversations.length; i++) {
      final c = _conversations[i];
      if (c.otherParticipant?.userId == userId) {
        final updatedParticipant = c.otherParticipant!.copyWith(
          isOnline: isOnline,
          lastSeenAtUtc: lastSeen ?? c.otherParticipant!.lastSeenAtUtc,
        );
        _conversations[i] = c.copyWith(otherParticipant: updatedParticipant);
        updated = true;
      }
    }

    if (updated) {
      notifyListeners();
    }
  }

  void _handleUserTyping(Map<String, dynamic> data) {
    final convId = data['conversationId'] as String?;
    final username = data['username'] as String?;
    final isTyping = data['isTyping'] == true;
    if (convId == null) return;

    _typingTimers[convId]?.cancel();

    if (isTyping) {
      _typingStatus[convId] = username;
      _typingTimers[convId] = Timer(const Duration(seconds: 4), () {
        _typingStatus[convId] = null;
        notifyListeners();
      });
    } else {
      _typingStatus[convId] = null;
    }

    notifyListeners();
  }

  void _handleConversationUpdated(ConversationModel conversation) {
    final idx = _conversations.indexWhere((c) => c.conversationId == conversation.conversationId);
    if (idx != -1) {
      _conversations[idx] = conversation;
    } else {
      _conversations.insert(0, conversation);
    }
    notifyListeners();
  }

  void _updateConversationLastMessage(String conversationId, MessageModel message, {bool incrementUnread = false}) {
    final idx = _conversations.indexWhere((c) => c.conversationId == conversationId);
    if (idx != -1) {
      final existing = _conversations[idx];
      final unread = incrementUnread ? existing.unreadCount + 1 : existing.unreadCount;
      final updated = existing.copyWith(
        lastMessage: message,
        updatedAtUtc: message.createdAtUtc,
        unreadCount: unread,
      );
      _conversations.removeAt(idx);
      _conversations.insert(0, updated);
    }
  }

  @override
  void dispose() {
    _msgReceivedSub?.cancel();
    _msgSentSub?.cancel();
    _convUpdatedSub?.cancel();
    _msgDeliveredSub?.cancel();
    _msgsReadSub?.cancel();
    _presenceSub?.cancel();
    _typingSub?.cancel();
    for (var t in _typingTimers.values) {
      t?.cancel();
    }
    super.dispose();
  }
}
