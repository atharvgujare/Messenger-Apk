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
  bool _isLoadingConversations = false;
  bool _isLoadingMessages = false;
  String? _activeConversationId;
  String? _error;

  StreamSubscription? _msgReceivedSub;
  StreamSubscription? _msgSentSub;
  StreamSubscription? _convUpdatedSub;

  List<ConversationModel> get conversations => _conversations;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingMessages => _isLoadingMessages;
  String? get activeConversationId => _activeConversationId;
  String? get error => _error;

  List<MessageModel> getMessagesFor(String conversationId) =>
      _conversationMessages[conversationId] ?? [];

  ChatProvider(this._apiClient, this._signalRService, this._authProvider) {
    _initSignalRSubscriptions();
  }

  void _initSignalRSubscriptions() {
    _msgReceivedSub = _signalRService.onMessageReceived.listen(_handleIncomingMessage);
    _msgSentSub = _signalRService.onMessageSent.listen(_handleMessageConfirmation);
    _convUpdatedSub = _signalRService.onConversationUpdated.listen(_handleConversationUpdated);
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

    _updateConversationLastMessage(convId, message, incrementUnread: _activeConversationId != convId);
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
    super.dispose();
  }
}
