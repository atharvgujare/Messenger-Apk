import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../providers/call_provider.dart';
import '../models/call_session_model.dart';

class CallScreen extends StatefulWidget {
  final CallSessionModel session;

  const CallScreen({super.key, required this.session});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = context.watch<CallProvider>();

    // If call ended, pop back
    if (callProvider.status == CallStatus.idle || callProvider.status == CallStatus.ended) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    }

    final isVideo = widget.session.isVideo;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmEndCall(context, callProvider);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF080B11),
        body: SafeArea(
          child: Stack(
            children: [
              // Main View: Remote Video OR Voice Call Avatar View
              if (isVideo && callProvider.remoteUid != null && callProvider.engine != null)
                _buildRemoteVideo(callProvider)
              else
                _buildVoiceOrConnectingView(callProvider),

              // Local Camera Pip (Small floating preview) for Video Calls
              if (isVideo && callProvider.engine != null && callProvider.isVideoEnabled)
                _buildLocalVideoPip(callProvider),

              // Top Bar with Caller Details & Duration
              _buildTopBar(callProvider),

              // Bottom Control Bar
              _buildBottomControls(callProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemoteVideo(CallProvider callProvider) {
    return Positioned.fill(
      child: AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: callProvider.engine!,
          canvas: VideoCanvas(uid: callProvider.remoteUid),
          connection: RtcConnection(channelId: widget.session.channelName),
        ),
      ),
    );
  }

  Widget _buildLocalVideoPip(CallProvider callProvider) {
    return Positioned(
      top: 90,
      right: 16,
      width: 110,
      height: 155,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF101522),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: callProvider.engine!,
              canvas: const VideoCanvas(uid: 0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceOrConnectingView(CallProvider callProvider) {
    final avatarUrl = widget.session.callerAvatar;
    final name = widget.session.callerName;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    blurRadius: 36,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 64,
                backgroundColor: const Color(0xFF161E31),
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF101522),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              callProvider.status == CallStatus.connected
                  ? _formatDuration(callProvider.callDuration)
                  : widget.session.isVideo ? 'Video Calling...' : 'Calling...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: callProvider.status == CallStatus.connected
                    ? const Color(0xFF10B981)
                    : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(CallProvider callProvider) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF101522).withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.session.isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                  color: const Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.session.isVideo ? 'Video Call' : 'Voice Call',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (callProvider.status == CallStatus.connected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF101522).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDuration(callProvider.callDuration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(CallProvider callProvider) {
    final isVideo = widget.session.isVideo;

    return Positioned(
      bottom: 28,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF101522).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mic Mute Button
            _buildControlButton(
              icon: callProvider.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              isActive: callProvider.isMuted,
              activeColor: Colors.orangeAccent,
              onTap: () => callProvider.toggleMute(),
            ),

            // Video Controls (Camera Flip & Video Toggle)
            if (isVideo) ...[
              _buildControlButton(
                icon: Icons.flip_camera_ios_rounded,
                isActive: false,
                onTap: () => callProvider.switchCamera(),
              ),
              _buildControlButton(
                icon: callProvider.isVideoEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                isActive: !callProvider.isVideoEnabled,
                activeColor: Colors.orangeAccent,
                onTap: () => callProvider.toggleVideo(),
              ),
            ],

            // Speaker Toggle (for voice calls)
            if (!isVideo)
              _buildControlButton(
                icon: callProvider.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                isActive: callProvider.isSpeakerOn,
                activeColor: const Color(0xFF10B981),
                onTap: () => callProvider.toggleSpeaker(),
              ),

            // End Call Button (Big Red)
            GestureDetector(
              onTap: () => callProvider.endCurrentCall(),
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66EF4444),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.call_end_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    Color activeColor = const Color(0xFF10B981),
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.2) : const Color(0xFF161E31),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? activeColor : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? activeColor : Colors.white,
          size: 22,
        ),
      ),
    );
  }

  void _confirmEndCall(BuildContext context, CallProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101522),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Call?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to end this call?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              provider.endCurrentCall();
            },
            child: const Text('End Call', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
