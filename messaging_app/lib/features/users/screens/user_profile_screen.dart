import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/models/auth_models.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chats/providers/chat_provider.dart';
import '../../chats/screens/chat_screen.dart';
import '../models/user_search_model.dart';
import 'user_list_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final UserSearchResultModel user;

  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserProfileModel? _profile;
  bool _isLoading = true;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final auth = context.read<AuthProvider>();
    try {
      final p = await auth.getUserProfile(widget.user.userId);
      if (mounted) {
        setState(() {
          _profile = p;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null) return;
    final auth = context.read<AuthProvider>();
    setState(() => _isActionLoading = true);

    try {
      final isFollowing = _profile!.followStatus == 'accepted';
      final isPending = _profile!.followStatus == 'pending';

      if (isFollowing || isPending) {
        // Unfollow or Cancel Request
        await auth.unfollowUser(widget.user.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isPending ? 'Follow request cancelled.' : 'Unfollowed @${widget.user.username}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // Follow
        final res = await auth.followUser(widget.user.userId);
        final status = res['status']?.toString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status == 'pending'
                  ? 'Follow request sent to private account.'
                  : 'You are now following @${widget.user.username}'),
              backgroundColor: status == 'accepted' ? Colors.green : Colors.amber[800],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      await _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _onStartMessage(BuildContext context) async {
    final isPrivate = _profile?.isPrivate ?? false;
    final isFollowing = _profile?.followStatus == 'accepted';

    if (isPrivate && !isFollowing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This account is private. You must follow and be approved before chatting.'),
          backgroundColor: Colors.amber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final chatProvider = context.read<ChatProvider>();
      final conversation = await chatProvider.getOrCreateDirectConversation(widget.user.userId);
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        if (conversation != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(conversation: conversation),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(chatProvider.error ?? 'Could not start conversation.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayName = _profile?.displayName ?? widget.user.displayName;
    final username = _profile?.username ?? widget.user.username;
    final avatarUrl = _profile?.avatarUrl ?? widget.user.avatarUrl;
    final bio = _profile?.bio ?? widget.user.bio;
    final isOnline = _profile?.isOnline ?? widget.user.isOnline;
    final isPrivate = _profile?.isPrivate ?? false;
    final followStatus = _profile?.followStatus;
    final followersCount = _profile?.followersCount ?? 0;
    final followingCount = _profile?.followingCount ?? 0;

    final canMessage = !isPrivate || followStatus == 'accepted';

    return Scaffold(
      appBar: AppBar(
        title: Text('@$username'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),

              // Avatar with Online Badge
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: theme.colorScheme.primary,
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Text(
                              widget.user.initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    if (isOnline)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 3.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Display Name
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isPrivate) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.lock, size: 18, color: Colors.amber),
                  ],
                ],
              ),
              const SizedBox(height: 6),

              // @username tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '@$username',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Online status
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isOnline ? Icons.circle : Icons.circle_outlined,
                    size: 10,
                    color: isOnline ? AppTheme.accentColor : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnline ? 'Online now' : 'Offline',
                    style: TextStyle(
                      color: isOnline ? AppTheme.accentColor : Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Followers / Following Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserListScreen(
                            title: 'Followers',
                            userId: widget.user.userId,
                            isFollowers: true,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          Text('$followersCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('Followers', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  Container(width: 1, height: 28, color: Colors.grey.withAlpha(80)),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserListScreen(
                            title: 'Following',
                            userId: widget.user.userId,
                            isFollowers: false,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          Text('$followingCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('Following', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Buttons Row: Follow Button + Send Message Button
              Row(
                children: [
                  // Follow / Following / Requested Button
                  Expanded(
                    child: _isActionLoading
                        ? const Center(child: CircularProgressIndicator())
                        : OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: followStatus == 'accepted'
                                    ? Colors.grey
                                    : (followStatus == 'pending' ? Colors.amber : theme.colorScheme.primary),
                              ),
                              backgroundColor: followStatus == 'accepted'
                                  ? Colors.transparent
                                  : (followStatus == 'pending'
                                      ? Colors.amber.withAlpha(20)
                                      : theme.colorScheme.primary.withAlpha(20)),
                            ),
                            onPressed: _toggleFollow,
                            icon: Icon(
                              followStatus == 'accepted'
                                  ? Icons.check_circle_outline
                                  : (followStatus == 'pending' ? Icons.hourglass_top_rounded : Icons.person_add_rounded),
                              size: 18,
                              color: followStatus == 'accepted'
                                  ? Colors.grey
                                  : (followStatus == 'pending' ? Colors.amber : theme.colorScheme.primary),
                            ),
                            label: Text(
                              followStatus == 'accepted'
                                  ? 'Following'
                                  : (followStatus == 'pending' ? 'Requested' : 'Follow'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: followStatus == 'accepted'
                                    ? (isDark ? Colors.white70 : Colors.black87)
                                    : (followStatus == 'pending' ? Colors.amber : theme.colorScheme.primary),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),

                  // Message CTA
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: canMessage ? AppTheme.whatsappGreen : Colors.grey[700],
                      ),
                      onPressed: () => _onStartMessage(context),
                      icon: Icon(canMessage ? Icons.chat_rounded : Icons.lock_outline, size: 18),
                      label: Text(canMessage ? 'Message' : 'Private'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Private Account Notice Banner
              if (isPrivate && followStatus != 'accepted') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withAlpha(80)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock, color: Colors.amber, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This account is private. Follow this account to see full details and send direct messages.',
                          style: TextStyle(fontSize: 13, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Bio Card
              if (bio != null && bio.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'About',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            bio,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
