import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/snap_provider.dart';

class CreateSnapScreen extends StatefulWidget {
  final String? targetRecipientId;
  final String? targetRecipientName;

  const CreateSnapScreen({
    super.key,
    this.targetRecipientId,
    this.targetRecipientName,
  });

  @override
  State<CreateSnapScreen> createState() => _CreateSnapScreenState();
}

class _CreateSnapScreenState extends State<CreateSnapScreen> {
  XFile? _selectedFile;
  final _captionController = TextEditingController();
  int _timerSeconds = 5;
  bool _isViewOnce = false;
  bool _isSending = false;

  String? _selectedRecipientId;
  String? _selectedRecipientName;
  List<Map<String, dynamic>> _friends = [];
  bool _loadingFriends = false;

  @override
  void initState() {
    super.initState();
    _selectedRecipientId = widget.targetRecipientId;
    _selectedRecipientName = widget.targetRecipientName;

    if (_selectedRecipientId == null) {
      _loadFriends();
    }
  }

  Future<void> _loadFriends() async {
    setState(() => _loadingFriends = true);
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.currentUser?.userId ?? '';
    try {
      final following = await auth.getFollowing(currentUserId);
      if (mounted) {
        setState(() {
          _friends = following;
          _loadingFriends = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 1440,
        maxHeight: 2560,
        imageQuality: 85,
      );
      if (file != null && mounted) {
        setState(() => _selectedFile = file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open ${source == ImageSource.camera ? "camera" : "gallery"}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendSnap() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or capture a photo first.')),
      );
      return;
    }

    if (_selectedRecipientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a friend to send this snap to.')),
      );
      return;
    }

    setState(() => _isSending = true);
    final snapProvider = context.read<SnapProvider>();
    final bytes = await _selectedFile!.readAsBytes();

    final ok = await snapProvider.sendSnap(
      recipientId: _selectedRecipientId!,
      mediaBytes: bytes,
      fileName: _selectedFile!.name,
      caption: _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
      timerSeconds: _timerSeconds,
      isViewOnce: _isViewOnce,
    );

    setState(() => _isSending = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Snap sent to ${_selectedRecipientName ?? "friend"}! 🔥'),
          backgroundColor: AppTheme.whatsappGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snapProvider.errorMessage ?? 'Failed to send snap.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _selectedRecipientName != null ? 'Snap to ${_selectedRecipientName!}' : 'New Snap',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_selectedFile != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Retake',
              onPressed: () => setState(() => _selectedFile = null),
            ),
        ],
      ),
      body: _selectedFile == null ? _buildCapturePicker() : _buildPreviewAndSend(theme, isDark),
    );
  }

  Widget _buildCapturePicker() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 72, color: Colors.amber),
              ),
              const SizedBox(height: 24),
              const Text(
                'Create a Disappearing Snap',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Capture or select a photo that disappears after viewing with streak tracking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.whatsappGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(125, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                    label: const Text('Camera', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      minimumSize: const Size(125, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
                    label: const Text('Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewAndSend(ThemeData theme, bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Media Image
        Image.file(
          File(_selectedFile!.path),
          fit: BoxFit.contain,
        ),

        // Controls Overlay
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Recipient Selector if not predefined
              if (widget.targetRecipientId == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(180),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: _loadingFriends
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          )
                        : _friends.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                child: Text(
                                  'Follow a friend to send them snaps',
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              )
                            : DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  dropdownColor: const Color(0xFF222222),
                                  hint: const Text('Select Friend to Send', style: TextStyle(color: Colors.white70)),
                                  value: _friends.any((f) => f['userId']?.toString() == _selectedRecipientId)
                                      ? _selectedRecipientId
                                      : null,
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                  items: _friends.map((f) {
                                    final id = f['userId']?.toString() ?? '';
                                    final name = f['displayName']?.toString() ?? f['username']?.toString() ?? 'Friend';
                                    return DropdownMenuItem<String>(
                                      value: id,
                                      child: Text(name, style: const TextStyle(color: Colors.white)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      final match = _friends.firstWhere((f) => f['userId'] == val, orElse: () => {});
                                      setState(() {
                                        _selectedRecipientId = val;
                                        _selectedRecipientName = match['displayName']?.toString() ?? match['username']?.toString();
                                      });
                                    }
                                  },
                                ),
                              ),
                  ),
                )
              else
                const SizedBox.shrink(),

              // Bottom configuration & Send
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withAlpha(220)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Caption input
                    TextField(
                      controller: _captionController,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Add a caption...',
                        hintStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.black.withAlpha(150),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Timer selector chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        _buildTimerChip(3, '3s'),
                        const SizedBox(width: 8),
                        _buildTimerChip(5, '5s'),
                        const SizedBox(width: 8),
                        _buildTimerChip(10, '10s'),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('1 View 🔂', style: TextStyle(fontSize: 12)),
                          selected: _isViewOnce,
                          selectedColor: Colors.amber,
                          backgroundColor: Colors.grey[850],
                          labelStyle: TextStyle(
                            color: _isViewOnce ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            setState(() {
                              _isViewOnce = val;
                              if (val) _timerSeconds = 5;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Send Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.whatsappGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: _isSending ? null : _sendSnap,
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _isSending ? 'Sending Snap...' : 'Send Snap 🔥',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimerChip(int seconds, String label) {
    final selected = !_isViewOnce && _timerSeconds == seconds;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      selectedColor: AppTheme.whatsappGreen,
      backgroundColor: Colors.grey[850],
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {
        setState(() {
          _isViewOnce = false;
          _timerSeconds = seconds;
        });
      },
    );
  }
}
