import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/snap_model.dart';
import '../providers/snap_provider.dart';

class ViewSnapScreen extends StatefulWidget {
  final SnapModel snap;

  const ViewSnapScreen({super.key, required this.snap});

  @override
  State<ViewSnapScreen> createState() => _ViewSnapScreenState();
}

class _ViewSnapScreenState extends State<ViewSnapScreen> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late int _secondsRemaining;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.snap.timerSeconds > 0 ? widget.snap.timerSeconds : 5;

    // Mark opened on backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SnapProvider>().openSnap(widget.snap.id);
    });

    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _secondsRemaining),
    );

    _progressController.forward();
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _closeSnap();
      }
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  void _closeSnap() {
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snap;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _closeSnap,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 100) {
            _closeSnap();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Snap Media Image
            Center(
              child: Image.network(
                snap.mediaUrl,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (ctx, _, _) => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                      SizedBox(height: 12),
                      Text('Media unavailable or expired', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),
            ),

            // Top Header & Countdown Timer Bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // Top Progress Bar
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 1.0 - _progressController.value,
                          minHeight: 4,
                          backgroundColor: Colors.white.withAlpha(80),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sender Profile and Countdown
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: (snap.senderAvatarUrl != null && snap.senderAvatarUrl!.isNotEmpty)
                              ? NetworkImage(snap.senderAvatarUrl!)
                              : null,
                          onBackgroundImageError: (snap.senderAvatarUrl != null && snap.senderAvatarUrl!.isNotEmpty)
                              ? (_, _) {}
                              : null,
                          child: (snap.senderAvatarUrl == null || snap.senderAvatarUrl!.isEmpty)
                              ? Text(
                                  snap.senderDisplayName.isNotEmpty ? snap.senderDisplayName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    snap.senderDisplayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (snap.streakCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.deepOrange.withAlpha(200),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Text('🔥', style: TextStyle(fontSize: 12)),
                                          Text(
                                            ' ${snap.streakCount}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '@${snap.senderUsername}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                        // Timer seconds bubble
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(150),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 16, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                '$_secondsRemaining s',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: _closeSnap,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Caption overlay at bottom
            if (snap.caption != null && snap.caption!.isNotEmpty)
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(180),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      snap.caption!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
