import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../users/screens/user_search_screen.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';
import 'settings_screen.dart';
import 'user_profile_screen.dart';
import '../../../core/services/notification_service.dart';
import '../../snaps/providers/snap_provider.dart';
import '../../snaps/screens/create_snap_screen.dart';
import '../../snaps/screens/view_snap_screen.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _navIndex = 0;
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chat = context.read<ChatProvider>();
      chat.connectRealTime();
      chat.loadConversations();
      NotificationService.instance.requestPermission();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'new_group':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
        );
        break;
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        break;
      case 'profile':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserProfileScreen()),
        );
        break;
      case 'read_all':
        final chat = context.read<ChatProvider>();
        for (var c in chat.conversations) {
          if (c.unreadCount > 0) {
            chat.markConversationAsRead(c.conversationId);
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All chats marked as read'), behavior: SnackBarBehavior.floating),
        );
        break;
      case 'logout':
        _confirmLogout();
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$value opened'), behavior: SnackBarBehavior.floating),
        );
        break;
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              minimumSize: const Size(100, 42),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _openChat(ConversationModel conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversation: conversation),
      ),
    );
  }

  void _showChatOptions(ConversationModel conv) {
    final chat = context.read<ChatProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(conv.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
                title: Text(conv.isPinned ? 'Unpin chat' : 'Pin chat'),
                onTap: () {
                  Navigator.pop(ctx);
                  chat.togglePin(conv.conversationId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.mark_chat_read_outlined),
                title: const Text('Mark as read'),
                onTap: () {
                  Navigator.pop(ctx);
                  chat.markConversationAsRead(conv.conversationId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Close chat', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = now.difference(local);

    if (diff.inDays == 0 && now.day == local.day) {
      return DateFormat('h:mm a').format(local).toLowerCase();
    } else if (diff.inDays <= 1 || (diff.inDays <= 2 && now.day != local.day)) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat('EEEE').format(local);
    } else {
      return DateFormat('dd/MM/yyyy').format(local);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chatProvider = context.watch<ChatProvider>();
    final snapProvider = context.watch<SnapProvider>();

    return Scaffold(
      // 1. WhatsApp Top Header
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              AppConfig.appName,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.whatsappGreenLight,
                fontWeight: FontWeight.bold,
                fontSize: 23,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_outlined, size: 24),
            tooltip: 'QR Scanner',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, size: 24),
            tooltip: 'Send Snap 🔥',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateSnapScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 24),
            tooltip: 'Search',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserSearchScreen()),
              );
            },
          ),
          // WhatsApp 3-dots popup menu button
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _onMenuSelected,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'new_group',
                child: Text('New group'),
              ),
              const PopupMenuItem<String>(
                value: 'new_community',
                child: Text('New community'),
              ),
              const PopupMenuItem<String>(
                value: 'broadcast_lists',
                child: Text('Broadcast lists'),
              ),
              const PopupMenuItem<String>(
                value: 'linked_devices',
                child: Text('Linked devices'),
              ),
              const PopupMenuItem<String>(
                value: 'starred',
                child: Text('Starred'),
              ),
              const PopupMenuItem<String>(
                value: 'payments',
                child: Text('Payments'),
              ),
              const PopupMenuItem<String>(
                value: 'read_all',
                child: Text('Read all'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    const Expanded(child: Text('Settings')),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.whatsappGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'profile',
                child: Text('Profile'),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Log out', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          // 2. Full-Width WhatsApp Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSearchBar : AppTheme.lightSearchBar,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Ask Meta AI or Search',
                  hintStyle: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    size: 22,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // 2.5. Ephemeral Snaps & Streaks Tray (Snapchat style)
          _buildSnapsTray(snapProvider, isDark),

          // 3. Filter Chips (All, Unread, Favourites, Groups)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Unread', count: chatProvider.conversations.where((c) => c.unreadCount > 0).length),
                const SizedBox(width: 8),
                _buildFilterChip('Favourites'),
                const SizedBox(width: 8),
                _buildFilterChip('Groups', count: chatProvider.conversations.where((c) => c.type == ConversationType.group).length),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // 4. List of Chats (with real-time sorting & pinned chats at top)
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => chatProvider.loadConversations(),
              child: _buildChatList(chatProvider, isDark),
            ),
          ),
        ],
      ),

      // WhatsApp Floating Action Button (FAB)
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.whatsappVibrantGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserSearchScreen()),
          );
        },
        child: const Icon(Icons.chat, color: Colors.white, size: 26),
      ),

      // WhatsApp 4-Tab Bottom Navigation Bar
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (idx) {
          setState(() => _navIndex = idx);
          if (idx == 1 || idx == 2 || idx == 3) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(idx == 1 ? 'Status Updates' : idx == 2 ? 'Communities' : 'Calls'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 1),
              ),
            );
          }
        },
        indicatorColor: isDark ? const Color(0xFF1B382B) : const Color(0xFFD8FDD2),
        destinations: [
          NavigationDestination(
            icon: Badge(
              label: Text('${chatProvider.conversations.fold<int>(0, (sum, c) => sum + c.unreadCount)}'),
              isLabelVisible: chatProvider.conversations.any((c) => c.unreadCount > 0),
              backgroundColor: AppTheme.whatsappVibrantGreen,
              child: const Icon(Icons.chat),
            ),
            selectedIcon: Badge(
              label: Text('${chatProvider.conversations.fold<int>(0, (sum, c) => sum + c.unreadCount)}'),
              isLabelVisible: chatProvider.conversations.any((c) => c.unreadCount > 0),
              backgroundColor: AppTheme.whatsappVibrantGreen,
              child: const Icon(Icons.chat, color: AppTheme.whatsappGreen),
            ),
            label: 'Chats',
          ),
          const NavigationDestination(
            icon: Badge(
              smallSize: 8,
              backgroundColor: AppTheme.whatsappVibrantGreen,
              child: Icon(Icons.update_outlined),
            ),
            label: 'Updates',
          ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: 'Communities',
          ),
          const NavigationDestination(
            icon: Icon(Icons.call_outlined),
            label: 'Calls',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {int count = 0}) {
    final isSelected = _selectedFilter == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1A382B) : const Color(0xFFE7FCE3))
              : (isDark ? AppTheme.darkSearchBar : const Color(0xFFF0F2F5)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (isDark ? AppTheme.whatsappGreen : AppTheme.whatsappGreenLight)
                    : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.whatsappGreen : Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(ChatProvider chatProvider, bool isDark) {
    if (chatProvider.isLoadingConversations && chatProvider.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    var list = chatProvider.conversations;

    // Apply Filter Chips
    if (_selectedFilter == 'Unread') {
      list = list.where((c) => c.unreadCount > 0).toList();
    } else if (_selectedFilter == 'Groups') {
      list = list.where((c) => c.type == ConversationType.group).toList();
    }

    // Apply Search Query
    if (_searchQuery.isNotEmpty) {
      list = list.where((c) {
        final title = c.title.toLowerCase();
        final content = c.lastMessage?.content.toLowerCase() ?? '';
        return title.contains(_searchQuery) || content.contains(_searchQuery);
      }).toList();
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: isDark ? AppTheme.darkTextSecondary : Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No chats found matching "$_searchQuery"' : 'No conversations yet',
              style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(160, 42),
                backgroundColor: AppTheme.whatsappGreen,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserSearchScreen()),
                );
              },
              icon: const Icon(Icons.person_search, color: Colors.white),
              label: const Text('Start a chat'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, index) => const Divider(indent: 78, height: 1, thickness: 0.5),
      itemBuilder: (context, index) {

        final conv = list[index];
        final lastMsg = conv.lastMessage;
        final isOnline = conv.otherParticipant?.isOnline == true;
        final isGroup = conv.type == ConversationType.group;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: isGroup
                    ? const Color(0xFF00A884).withAlpha(40)
                    : AppTheme.whatsappGreenLight,
                backgroundImage: (conv.avatarUrl != null && conv.avatarUrl!.isNotEmpty)
                    ? NetworkImage(conv.avatarUrl!)
                    : null,
                child: (conv.avatarUrl == null || conv.avatarUrl!.isEmpty)
                    ? (isGroup
                        ? const Icon(Icons.groups, color: AppTheme.whatsappGreen, size: 28)
                        : Text(
                            conv.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ))
                    : null,
              ),
              if (isOnline && !isGroup)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.whatsappVibrantGreen,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppTheme.darkSurface : Colors.white,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  conv.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
              ),
              if (lastMsg != null)
                Text(
                  _formatTimestamp(lastMsg.createdAtUtc),
                  style: TextStyle(
                    fontSize: 12,
                    color: conv.unreadCount > 0
                        ? AppTheme.whatsappVibrantGreen
                        : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                    fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
            ],
          ),
          subtitle: Builder(
            builder: (context) {
              final auth = context.read<AuthProvider>();
              final myUserId = auth.currentUserId.trim().toLowerCase();
              final myUsername = auth.currentUsername.trim().toLowerCase();
              final isSentByMe = lastMsg != null &&
                  ((myUserId.isNotEmpty && lastMsg.senderId.trim().toLowerCase() == myUserId) ||
                   (myUsername.isNotEmpty && lastMsg.senderUsername.trim().toLowerCase() == myUsername));

              return Row(
                children: [
                  // Delivery Status Checkmark (if sent by current user)
                  if (isSentByMe) ...[
                    _buildMessageStatusIcon(lastMsg.status),
                    const SizedBox(width: 4),
                  ],
              // Group sender prefix if in a group
              if (isGroup && lastMsg != null && lastMsg.senderDisplayName.isNotEmpty) ...[
                Text(
                  '~ ${lastMsg.senderDisplayName.split(' ')[0]}: ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ],
              // Last message content
              Expanded(
                child: Text(
                  lastMsg != null ? lastMsg.content : 'Tap to start messaging',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              ),
              // Pin indicator & Unread badge
              if (conv.isPinned) ...[
                const SizedBox(width: 6),
                const Icon(Icons.push_pin, size: 16, color: Colors.grey),
              ],
              if (conv.unreadCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppTheme.whatsappVibrantGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${conv.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
          onTap: () => _openChat(conv),
          onLongPress: () => _showChatOptions(conv),
        );
      },
    );
  }

  Widget _buildMessageStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return const Icon(Icons.access_time, size: 14, color: Colors.grey);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 16, color: Colors.grey);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 16, color: Colors.grey);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 16, color: AppTheme.whatsappBlueCheck);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, size: 14, color: Colors.red);
    }
  }

  Widget _buildSnapsTray(SnapProvider snapProvider, bool isDark) {
    final snaps = snapProvider.activeSnaps;

    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 1 + snaps.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            // New Snap button
            return InkWell(
              borderRadius: BorderRadius.circular(35),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateSnapScreen()),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: isDark ? AppTheme.darkSearchBar : Colors.grey[200],
                        child: const Icon(Icons.camera_alt, color: AppTheme.whatsappGreen),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppTheme.whatsappGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('New Snap', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          final snap = snaps[index - 1];
          return InkWell(
            borderRadius: BorderRadius.circular(35),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ViewSnapScreen(snap: snap)),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.deepOrange, Colors.purpleAccent, Colors.amber],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.black,
                    backgroundImage: (snap.senderAvatarUrl != null && snap.senderAvatarUrl!.isNotEmpty)
                        ? NetworkImage(snap.senderAvatarUrl!)
                        : null,
                    child: (snap.senderAvatarUrl == null || snap.senderAvatarUrl!.isEmpty)
                        ? Text(
                            snap.senderDisplayName.isNotEmpty ? snap.senderDisplayName[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 58,
                  child: Text(
                    snap.senderDisplayName,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}

