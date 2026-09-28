import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class UserListScreen extends StatefulWidget {
  final String title;
  final String userId;
  final bool isFollowers; // true = followers, false = following

  const UserListScreen({
    super.key,
    required this.title,
    required this.userId,
    required this.isFollowers,
  });

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    try {
      final list = widget.isFollowers
          ? await auth.getFollowers(widget.userId)
          : await auth.getFollowing(widget.userId);
      if (mounted) {
        setState(() {
          _users = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Text(
                    'No ${widget.title.toLowerCase()} found.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.separated(
                  itemCount: _users.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final u = _users[index];
                    final displayName = u['displayName']?.toString() ?? 'User';
                    final username = u['username']?.toString() ?? '';
                    final avatarUrl = u['avatarUrl']?.toString();
                    final isOnline = u['isOnline'] == true;

                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: isDark ? AppTheme.darkSearchBar : Colors.grey[200],
                            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: (avatarUrl == null || avatarUrl.isEmpty)
                                ? Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                    style: TextStyle(color: theme.colorScheme.primary),
                                  )
                                : null,
                          ),
                          if (isOnline)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.scaffoldBackgroundColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('@$username'),
                    );
                  },
                ),
    );
  }
}
