import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/network/signalr_service.dart';
import '../models/call_session_model.dart';

enum CallStatus { idle, calling, incoming, connected, ended }

class CallProvider extends ChangeNotifier {
  final SignalRService _signalRService;

  RtcEngine? _engine;
  RtcEngine? get engine => _engine;

  CallSessionModel? _currentCall;
  CallSessionModel? get currentCall => _currentCall;

  CallSessionModel? _incomingCall;
  CallSessionModel? get incomingCall => _incomingCall;

  CallStatus _status = CallStatus.idle;
  CallStatus get status => _status;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isSpeakerOn = false;
  bool get isSpeakerOn => _isSpeakerOn;

  bool _isVideoEnabled = true;
  bool get isVideoEnabled => _isVideoEnabled;

  bool _isFrontCamera = true;
  bool get isFrontCamera => _isFrontCamera;

  int? _remoteUid;
  int? get remoteUid => _remoteUid;

  int _callDuration = 0;
  int get callDuration => _callDuration;
  Timer? _durationTimer;

  StreamSubscription? _incomingCallSub;
  StreamSubscription? _callAcceptedSub;
  StreamSubscription? _callRejectedSub;
  StreamSubscription? _callEndedSub;

  CallProvider(this._signalRService) {
    _initSignalRListeners();
  }

  void _initSignalRListeners() {
    _incomingCallSub = _signalRService.onIncomingCall.listen((session) {
      if (_status != CallStatus.idle) {
        // Already on a call, auto-reject busy
        _signalRService.rejectCall(session.callId, 'Busy');
        return;
      }
      _incomingCall = session;
      _status = CallStatus.incoming;
      notifyListeners();
    });

    _callAcceptedSub = _signalRService.onCallAccepted.listen((data) async {
      if (_status == CallStatus.calling && _currentCall != null) {
        debugPrint('[CallProvider] Call accepted by remote party');
        _status = CallStatus.connected;
        _startTimer();
        notifyListeners();
      }
    });

    _callRejectedSub = _signalRService.onCallRejected.listen((data) {
      debugPrint('[CallProvider] Call rejected: ${data['reason']}');
      _cleanupCall();
    });

    _callEndedSub = _signalRService.onCallEnded.listen((callId) {
      debugPrint('[CallProvider] Call ended by remote user');
      _cleanupCall();
    });
  }

  Future<bool> startOutgoingCall({
    required String receiverId,
    required String conversationId,
    required String callType,
  }) async {
    try {
      final hasPerms = await _requestPermissions(callType == 'video');
      if (!hasPerms) {
        debugPrint('[CallProvider] Camera/Microphone permissions denied');
        return false;
      }

      final session = await _signalRService.initiateCall(receiverId, conversationId, callType);
      if (session == null) {
        debugPrint('[CallProvider] Failed to initiate call on server');
        return false;
      }

      _currentCall = session;
      _status = CallStatus.calling;
      _isMuted = false;
      _isSpeakerOn = session.isVideo;
      _isVideoEnabled = session.isVideo;
      _remoteUid = null;
      notifyListeners();

      await _initAgoraEngine(session);
      return true;
    } catch (e) {
      debugPrint('[CallProvider] Error starting call: $e');
      _cleanupCall();
      return false;
    }
  }

  Future<bool> acceptIncomingCall() async {
    final session = _incomingCall;
    if (session == null) return false;

    try {
      final hasPerms = await _requestPermissions(session.isVideo);
      if (!hasPerms) {
        await rejectIncomingCall('Permission denied');
        return false;
      }

      final answer = await _signalRService.acceptCall(session.callId);
      final token = answer?['token']?.toString() ?? session.token;

      _currentCall = CallSessionModel(
        callId: session.callId,
        callerId: session.callerId,
        callerName: session.callerName,
        callerAvatar: session.callerAvatar,
        receiverId: session.receiverId,
        conversationId: session.conversationId,
        callType: session.callType,
        channelName: session.channelName,
        agoraAppId: session.agoraAppId,
        token: token,
        createdAtUtc: session.createdAtUtc,
      );

      _incomingCall = null;
      _status = CallStatus.connected;
      _isMuted = false;
      _isSpeakerOn = session.isVideo;
      _isVideoEnabled = session.isVideo;
      _remoteUid = null;
      _startTimer();
      notifyListeners();

      await _initAgoraEngine(_currentCall!);
      return true;
    } catch (e) {
      debugPrint('[CallProvider] Error accepting call: $e');
      _cleanupCall();
      return false;
    }
  }

  Future<void> rejectIncomingCall([String reason = 'Declined']) async {
    if (_incomingCall != null) {
      await _signalRService.rejectCall(_incomingCall!.callId, reason);
    }
    _cleanupCall();
  }

  Future<void> endCurrentCall() async {
    if (_currentCall != null) {
      await _signalRService.endCall(_currentCall!.callId);
    }
    _cleanupCall();
  }

  Future<bool> _requestPermissions(bool isVideo) async {
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) return false;

    if (isVideo) {
      final camStatus = await Permission.camera.request();
      if (camStatus != PermissionStatus.granted) return false;
    }

    return true;
  }

  Future<void> _initAgoraEngine(CallSessionModel session) async {
    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: session.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('[Agora] Successfully joined channel: ${connection.channelId}');
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('[Agora] Remote user joined: $remoteUid');
            _remoteUid = remoteUid;
            _status = CallStatus.connected;
            _startTimer();
            notifyListeners();
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint('[Agora] Remote user offline: $remoteUid, reason: $reason');
            _cleanupCall();
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[Agora] Error: $err, message: $msg');
          },
        ),
      );

      if (session.isVideo) {
        await _engine!.enableVideo();
        await _engine!.startPreview();
      } else {
        await _engine!.enableAudio();
      }

      await _engine!.setEnableSpeakerphone(_isSpeakerOn);

      await _engine!.joinChannel(
        token: session.token,
        channelId: session.channelName,
        uid: 0,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishCameraTrack: session.isVideo,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: session.isVideo,
        ),
      );
    } catch (e) {
      debugPrint('[Agora] Error initializing engine: $e');
    }
  }

  Future<void> toggleMute() async {
    if (_engine == null) return;
    _isMuted = !_isMuted;
    await _engine!.muteLocalAudioStream(_isMuted);
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    if (_engine == null) return;
    _isSpeakerOn = !_isSpeakerOn;
    await _engine!.setEnableSpeakerphone(_isSpeakerOn);
    notifyListeners();
  }

  Future<void> toggleVideo() async {
    if (_engine == null) return;
    _isVideoEnabled = !_isVideoEnabled;
    await _engine!.muteLocalVideoStream(!_isVideoEnabled);
    notifyListeners();
  }

  Future<void> switchCamera() async {
    if (_engine == null) return;
    await _engine!.switchCamera();
    _isFrontCamera = !_isFrontCamera;
    notifyListeners();
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _callDuration = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDuration++;
      notifyListeners();
    });
  }

  void _cleanupCall() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _callDuration = 0;

    if (_engine != null) {
      try {
        _engine!.leaveChannel();
        _engine!.release();
      } catch (e) {
        debugPrint('[Agora] Error cleaning up engine: $e');
      }
      _engine = null;
    }

    _currentCall = null;
    _incomingCall = null;
    _remoteUid = null;
    _status = CallStatus.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _incomingCallSub?.cancel();
    _callAcceptedSub?.cancel();
    _callRejectedSub?.cancel();
    _callEndedSub?.cancel();
    _cleanupCall();
    super.dispose();
  }
}
