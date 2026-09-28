import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../users/models/user_search_model.dart';
import '../../users/providers/user_search_provider.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _titleController = TextEditingController();
  final Set<UserSearchResultModel> _selectedUsers = {};
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserSearchProvider>().searchUsers('');
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _toggleUser(UserSearchResultModel user) {
    setState(() {
      if (_selectedUsers.any((u) => u.userId == user.userId)) {
        _selectedUsers.removeWhere((u) => u.userId == user.userId);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  void _createGroup() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a group subject'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least 1 participant must be selected'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);
    final chatProvider = context.read<ChatProvider>();
    final memberIds = _selectedUsers.map((u) => u.userId).toList();

    final groupConv = await chatProvider.createGroup(title, memberIds);
    setState(() => _isCreating = false);

    if (groupConv != null && mounted) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversation: groupConv),
        ),
      );
    } else if (mounted && chatProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chatProvider.error!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final searchProvider = context.watch<UserSearchProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              '${_selectedUsers.length} selected',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Group Subject & Icon input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.whatsappGreen.withAlpha(30),
                  child: const Icon(Icons.groups, color: AppTheme.whatsappGreen, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Type group subject here...',
                      border: UnderlineInputBorder(),
                      enabledBorder: UnderlineInputBorder(),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.whatsappGreen, width: 2),
                      ),
                      filled: false,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Selected Participants horizontal chips
          if (_selectedUsers.isNotEmpty) ...[
            SizedBox(
              height: 75,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _selectedUsers.map((user) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Stack(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.whatsappGreenLight,
                              backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              onBackgroundImageError: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                                  ? (_, _) {}
                                  : null,
                              child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                                  ? Text(
                                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.displayName.split(' ')[0],
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () => _toggleUser(user),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.grey,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
          ],

          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search contacts...',
              ),
              onChanged: (val) => searchProvider.searchUsers(val),
            ),
          ),

          // User list
          Expanded(
            child: searchProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: searchProvider.searchResults.length,
                    itemBuilder: (context, index) {
                      final user = searchProvider.searchResults[index];
                      final isSelected = _selectedUsers.any((u) => u.userId == user.userId);

                      return ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppTheme.whatsappGreen,
                              backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              onBackgroundImageError: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                                  ? (_, _) {}
                                  : null,
                              child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                                  ? Text(
                                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            if (isSelected)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.whatsappGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          user.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          user.bio ?? '@${user.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Checkbox(
                          value: isSelected,
                          activeColor: AppTheme.whatsappGreen,
                          onChanged: (_) => _toggleUser(user),
                        ),
                        onTap: () => _toggleUser(user),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.whatsappVibrantGreen,
        onPressed: _isCreating ? null : _createGroup,
        child: _isCreating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.check, color: Colors.white, size: 28),
      ),
    );
  }
}
