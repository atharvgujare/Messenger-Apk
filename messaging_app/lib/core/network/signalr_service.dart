import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../config/app_config.dart';
import '../storage/local_storage.dart';
import '../../features/chats/models/message_model.dart';
import '../../features/chats/models/conversation_model.dart';
import '../../features/calls/models/call_session_model.dart';

class SignalRService {
  final LocalStorage _storage;
  HubConnection? _hubConnection;

  final _messageReceivedController = StreamController<MessageModel>.broadcast();
  final _messageSentController = StreamController<MessageModel>.broadcast();
  final _conversationUpdatedController = StreamController<ConversationModel>.broadcast();
  final _connectionStateController = StreamController<HubConnectionState>.broadcast();

  // Phase 4 Delivery, Read, Presence & Typing Streams
  final _messageDeliveredController = StreamController<Map<String, dynamic>>.broadcast();
  final _messagesReadController = StreamController<Map<String, dynamic>>.broadcast();
  final _userPresenceChangedController = StreamController<Map<String, dynamic>>.broadcast();
  final _userTypingController = StreamController<Map<String, dynamic>>.broadcast();

  // Phase 5 Rich Message Streams
  final _messageEditedController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _reactionUpdatedController = StreamController<Map<String, dynamic>>.broadcast();

  // Calling Streams
  final _incomingCallController = StreamController<CallSessionModel>.broadcast();
  final _callAcceptedController = StreamController<Map<String, dynamic>>.broadcast();
  final _callRejectedController = StreamController<Map<String, dynamic>>.broadcast();
  final _callEndedController = StreamController<String>.broadcast();

  Stream<MessageModel> get onMessageReceived => _messageReceivedController.stream;
  Stream<MessageModel> get onMessageSent => _messageSentController.stream;
  Stream<ConversationModel> get onConversationUpdated => _conversationUpdatedController.stream;
  Stream<HubConnectionState> get onConnectionStateChanged => _connectionStateController.stream;

  Stream<Map<String, dynamic>> get onMessageDelivered => _messageDeliveredController.stream;
  Stream<Map<String, dynamic>> get onMessagesRead => _messagesReadController.stream;
  Stream<Map<String, dynamic>> get onUserPresenceChanged => _userPresenceChangedController.stream;
  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;

  Stream<Map<String, dynamic>> get onMessageEdited => _messageEditedController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted => _messageDeletedController.stream;
  Stream<Map<String, dynamic>> get onReactionUpdated => _reactionUpdatedController.stream;

  Stream<CallSessionModel> get onIncomingCall => _incomingCallController.stream;
  Stream<Map<String, dynamic>> get onCallAccepted => _callAcceptedController.stream;
  Stream<Map<String, dynamic>> get onCallRejected => _callRejectedController.stream;
  Stream<String> get onCallEnded => _callEndedController.stream;

  bool get isConnected => _hubConnection?.state == HubConnectionState.Connected;

  SignalRService(this._storage);

  Future<void> connect() async {
    final token = _storage.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('[SignalR] No access token found. Cannot connect.');
      return;
    }

    if (_hubConnection != null && _hubConnection!.state == HubConnectionState.Connected) {
      debugPrint('[SignalR] Already connected.');
      return;
    }

    try {
      _hubConnection = HubConnectionBuilder()
          .withUrl(
            AppConfig.chatHubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async => _storage.getAccessToken() ?? '',
            ),
          )
          .withAutomaticReconnect()
          .build();

      _hubConnection!.onreconnecting(({error}) {
        debugPrint('[SignalR] Reconnecting: $error');
        _connectionStateController.add(HubConnectionState.Reconnecting);
      });

      _hubConnection!.onreconnected(({connectionId}) {
        debugPrint('[SignalR] Reconnected. Id: $connectionId');
        _connectionStateController.add(HubConnectionState.Connected);
      });

      _hubConnection!.onclose(({error}) {
        debugPrint('[SignalR] Disconnected: $error');
        _connectionStateController.add(HubConnectionState.Disconnected);
      });

      // Register server callbacks
      _hubConnection!.on('MessageReceived', _onMessageReceived);
      _hubConnection!.on('MessageSent', _onMessageSent);
      _hubConnection!.on('ConversationUpdated', _onConversationUpdated);
      _hubConnection!.on('MessageDelivered', _onMessageDelivered);
      _hubConnection!.on('MessagesRead', _onMessagesRead);
      _hubConnection!.on('UserPresenceChanged', _onUserPresenceChanged);
      _hubConnection!.on('UserTyping', _onUserTyping);
      _hubConnection!.on('MessageEdited', _onMessageEdited);
      _hubConnection!.on('MessageDeleted', _onMessageDeleted);
      _hubConnection!.on('MessageReactionUpdated', _onMessageReactionUpdated);

      // Calling callbacks
      _hubConnection!.on('IncomingCall', _onIncomingCall);
      _hubConnection!.on('CallAccepted', _onCallAccepted);
      _hubConnection!.on('CallRejected', _onCallRejected);
      _hubConnection!.on('CallEnded', _onCallEnded);

      await _hubConnection!.start();
      debugPrint('[SignalR] Connected successfully to ${AppConfig.chatHubUrl}');
      _connectionStateController.add(HubConnectionState.Connected);
    } catch (e) {
      debugPrint('[SignalR] Connection error: $e');
      _connectionStateController.add(HubConnectionState.Disconnected);
    }
  }

  void _onMessageReceived(List<Object?>? args) {
    if (args != null && args.isNotEmpty && args[0] is Map) {
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        final message = MessageModel.fromJson(data);
        _messageReceivedController.add(message);
      } catch (e) {
        debugPrint('[SignalR] Error parsing incoming MessageReceived: $e');
      }
    }
  }

  void _onMessageSent(List<Object?>? args) {
    if (args != null && args.isNotEmpty && args[0] is Map) {
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        final message = MessageModel.fromJson(data);
        _messageSentController.add(message);
      } catch (e) {
        debugPrint('[SignalR] Error parsing MessageSent: $e');
      }
    }
  }

  void _onConversationUpdated(List<Object?>? args) {
    if (args != null && args.isNotEmpty && args[0] is Map) {
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        final conversation = ConversationModel.fromJson(data);
        _conversationUpdatedController.add(conversation);
      } catch (e) {
        debugPrint('[SignalR] Error parsing ConversationUpdated: $e');
      }
    }
  }

  void _onMessageDelivered(List<Object?>? args) {
    if (args != null && args.length >= 2) {
      _messageDeliveredController.add({
        'messageId': args[0]?.toString() ?? '',
        'conversationId': args[1]?.toString() ?? '',
      });
    }
  }

  void _onMessagesRead(List<Object?>? args) {
    if (args != null && args.length >= 3) {
      _messagesReadController.add({
        'conversationId': args[0]?.toString() ?? '',
        'readByUserId': args[1]?.toString() ?? '',
        'readAtUtc': DateTime.tryParse(args[2]?.toString() ?? '') ?? DateTime.now(),
      });
    }
  }

  void _onUserPresenceChanged(List<Object?>? args) {
    if (args != null && args.length >= 2) {
      _userPresenceChangedController.add({
        'userId': args[0]?.toString() ?? '',
        'isOnline': args[1] == true,
        'lastSeenAtUtc': args.length > 2 && args[2] != null
            ? DateTime.tryParse(args[2]!.toString())
            : null,
      });
    }
  }

  void _onUserTyping(List<Object?>? args) {
    if (args != null && args.length >= 4) {
      _userTypingController.add({
        'conversationId': args[0]?.toString() ?? '',
        'userId': args[1]?.toString() ?? '',
        'username': args[2]?.toString() ?? '',
        'isTyping': args[3] == true,
      });
    }
  }

  void _onMessageEdited(List<Object?>? args) {
    if (args != null && args.length >= 4) {
      _messageEditedController.add({
        'messageId': args[0]?.toString() ?? '',
        'conversationId': args[1]?.toString() ?? '',
        'newContent': args[2]?.toString() ?? '',
        'editedAtUtc': DateTime.tryParse(args[3]?.toString() ?? '') ?? DateTime.now(),
      });
    }
  }

  void _onMessageDeleted(List<Object?>? args) {
    if (args != null && args.length >= 3) {
      _messageDeletedController.add({
        'messageId': args[0]?.toString() ?? '',
        'conversationId': args[1]?.toString() ?? '',
        'isDeletedForEveryone': args[2] == true,
      });
    }
  }

  void _onMessageReactionUpdated(List<Object?>? args) {
    if (args != null && args.length >= 3) {
      final rawList = args[2] as List<dynamic>?;
      final parsedReactions = rawList != null
          ? rawList.map((r) => MessageReactionModel.fromJson(Map<String, dynamic>.from(r as Map))).toList()
          : <MessageReactionModel>[];

      _reactionUpdatedController.add({
        'messageId': args[0]?.toString() ?? '',
        'conversationId': args[1]?.toString() ?? '',
        'reactions': parsedReactions,
      });
    }
  }

  Future<MessageModel?> sendMessage(Map<String, dynamic> request) async {
    if (!isConnected) {
      debugPrint('[SignalR] Not connected, attempting reconnection...');
      await connect();
      if (!isConnected) {
        throw Exception('Unable to connect to real-time chat server.');
      }
    }

    final result = await _hubConnection!.invoke('SendMessage', args: [request]);
    if (result is Map) {
      return MessageModel.fromJson(Map<String, dynamic>.from(result));
    }
    return null;
  }

  Future<void> editMessage(String messageId, String newContent) async {
    if (isConnected) {
      await _hubConnection!.invoke('EditMessage', args: [messageId, newContent]);
    }
  }

  Future<void> deleteMessage(String messageId, String conversationId, bool forEveryone) async {
    if (isConnected) {
      await _hubConnection!.invoke('DeleteMessage', args: [messageId, conversationId, forEveryone]);
    }
  }

  Future<void> toggleReaction(String messageId, String conversationId, String emoji) async {
    if (isConnected) {
      await _hubConnection!.invoke('ToggleReaction', args: [messageId, conversationId, emoji]);
    }
  }

  Future<void> markMessageDelivered(String messageId, String conversationId) async {
    if (isConnected) {
      try {
        await _hubConnection!.invoke('MarkMessageDelivered', args: [messageId, conversationId]);
      } catch (e) {
        debugPrint('[SignalR] Error calling MarkMessageDelivered: $e');
      }
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    if (isConnected) {
      try {
        await _hubConnection!.invoke('MarkConversationAsRead', args: [conversationId]);
      } catch (e) {
        debugPrint('[SignalR] Error calling MarkConversationAsRead: $e');
      }
    }
  }

  Future<void> sendTypingIndicator(String conversationId, bool isTyping) async {
    if (isConnected) {
      try {
        await _hubConnection!.invoke('SendTypingIndicator', args: [conversationId, isTyping]);
      } catch (e) {
        debugPrint('[SignalR] Error calling SendTypingIndicator: $e');
      }
    }
  }

  Future<void> joinConversation(String conversationId) async {
    if (isConnected) {
      await _hubConnection!.invoke('JoinConversation', args: [conversationId]);
    }
  }

  Future<void> leaveConversation(String conversationId) async {
    if (isConnected) {
      await _hubConnection!.invoke('LeaveConversation', args: [conversationId]);
    }
  }

  // --- Calling Signaling ---

  Future<CallSessionModel?> initiateCall(String receiverId, String conversationId, String callType) async {
    if (isConnected) {
      try {
        final result = await _hubConnection!.invoke('InitiateCall', args: [receiverId, conversationId, callType]);
        if (result != null && result is Map) {
          return CallSessionModel.fromJson(Map<String, dynamic>.from(result));
        }
      } catch (e) {
        debugPrint('[SignalR] Error calling InitiateCall: $e');
        rethrow;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> acceptCall(String callId) async {
    if (isConnected) {
      try {
        final result = await _hubConnection!.invoke('AcceptCall', args: [callId]);
        if (result != null && result is Map) {
          return Map<String, dynamic>.from(result);
        }
      } catch (e) {
        debugPrint('[SignalR] Error calling AcceptCall: $e');
        rethrow;
      }
    }
    return null;
  }

  Future<void> rejectCall(String callId, [String reason = 'Declined']) async {
    if (isConnected) {
      try {
        await _hubConnection!.invoke('RejectCall', args: [callId, reason]);
      } catch (e) {
        debugPrint('[SignalR] Error calling RejectCall: $e');
      }
    }
  }

  Future<void> endCall(String callId) async {
    if (isConnected) {
      try {
        await _hubConnection!.invoke('EndCall', args: [callId]);
      } catch (e) {
        debugPrint('[SignalR] Error calling EndCall: $e');
      }
    }
  }

  void _onIncomingCall(List<Object?>? args) {
    if (args != null && args.isNotEmpty && args[0] is Map) {
      try {
        final data = Map<String, dynamic>.from(args[0] as Map);
        final session = CallSessionModel.fromJson(data);
        _incomingCallController.add(session);
      } catch (e) {
        debugPrint('[SignalR] Error parsing IncomingCall: $e');
      }
    }
  }

  void _onCallAccepted(List<Object?>? args) {
    if (args != null && args.length >= 4) {
      try {
        _callAcceptedController.add({
          'callId': args[0]?.toString() ?? '',
          'channelName': args[1]?.toString() ?? '',
          'agoraAppId': args[2]?.toString() ?? '',
          'token': args[3]?.toString() ?? '',
        });
      } catch (e) {
        debugPrint('[SignalR] Error parsing CallAccepted: $e');
      }
    }
  }

  void _onCallRejected(List<Object?>? args) {
    if (args != null && args.length >= 2) {
      try {
        _callRejectedController.add({
          'callId': args[0]?.toString() ?? '',
          'reason': args[1]?.toString() ?? 'Declined',
        });
      } catch (e) {
        debugPrint('[SignalR] Error parsing CallRejected: $e');
      }
    }
  }

  void _onCallEnded(List<Object?>? args) {
    if (args != null && args.isNotEmpty) {
      try {
        _callEndedController.add(args[0]?.toString() ?? '');
      } catch (e) {
        debugPrint('[SignalR] Error parsing CallEnded: $e');
      }
    }
  }

  Future<void> disconnect() async {
    if (_hubConnection != null) {
      await _hubConnection!.stop();
      _hubConnection = null;
      _connectionStateController.add(HubConnectionState.Disconnected);
    }
  }

  void dispose() {
    disconnect();
    _messageReceivedController.close();
    _messageSentController.close();
    _conversationUpdatedController.close();
    _connectionStateController.close();
    _messageDeliveredController.close();
    _messagesReadController.close();
    _userPresenceChangedController.close();
    _userTypingController.close();
    _messageEditedController.close();
    _messageDeletedController.close();
    _reactionUpdatedController.close();

    _incomingCallController.close();
    _callAcceptedController.close();
    _callRejectedController.close();
    _callEndedController.close();
  }
}
