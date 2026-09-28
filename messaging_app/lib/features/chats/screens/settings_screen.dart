import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'user_profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showThemeDialog(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    final currentMode = themeProvider.themeMode;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                currentMode == ThemeMode.system ? Icons.radio_button_checked : Icons.radio_button_off,
                color: AppTheme.whatsappGreen,
              ),
              title: const Text('System default'),
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.system);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                currentMode == ThemeMode.light ? Icons.radio_button_checked : Icons.radio_button_off,
                color: AppTheme.whatsappGreen,
              ),
              title: const Text('Light'),
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                currentMode == ThemeMode.dark ? Icons.radio_button_checked : Icons.radio_button_off,
                color: AppTheme.whatsappGreen,
              ),
              title: const Text('Dark'),
              onTap: () {
                themeProvider.setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),

          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              minimumSize: const Size(90, 40),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              context.read<AuthProvider>().logout();
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = auth.currentUser;

    final displayName = user?.displayName ?? 'User';
    final username = user?.username ?? 'username';
    final avatarUrl = user?.avatarUrl;

    String themeLabel = 'System default';
    if (themeProvider.themeMode == ThemeMode.dark) themeLabel = 'Dark';
    if (themeProvider.themeMode == ThemeMode.light) themeLabel = 'Light';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        children: [
          // Profile header card (Exact WhatsApp styling from screenshot)
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: isDark ? AppTheme.darkSearchBar : Colors.grey[200],
                    backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? NetworkImage(avatarUrl)
                        : null,
                    onBackgroundImageError: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? (_, _) {}
                        : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? Icon(
                            Icons.person,
                            size: 40,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey[400],
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@$username',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.qr_code, color: AppTheme.whatsappGreen, size: 28),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Email verified card / Finish email setup (matching screenshot)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B2E28) : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_read, color: AppTheme.whatsappGreen, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Email Verified',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified, color: AppTheme.whatsappGreen, size: 20),
                ],
              ),
            ),
          ),

          // Theme Settings Tile
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined, size: 26),
            title: const Text('Theme'),
            subtitle: Text(themeLabel),
            onTap: () => _showThemeDialog(context),
          ),

          // Notifications Tile
          ListTile(
            leading: const Icon(Icons.notifications_none_outlined, size: 26),
            title: const Text('Notifications'),
            subtitle: const Text('Message, group & call tones'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications are active! Background pushes enabled.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          // Privacy & Account
          ListTile(
            leading: const Icon(Icons.lock_outline, size: 26),
            title: const Text('Privacy'),
            subtitle: const Text('Read receipts, last seen, online status'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Privacy settings: Read receipts active for all chats.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          // Chats backup / storage
          ListTile(
            leading: const Icon(Icons.chat_outlined, size: 26),
            title: const Text('Chats'),
            subtitle: const Text('Theme, wallpapers, chat history'),
            onTap: () => _showThemeDialog(context),
          ),

          const Divider(height: 24),

          // Log out Tile
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red, size: 26),
            title: const Text('Log out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }
}
