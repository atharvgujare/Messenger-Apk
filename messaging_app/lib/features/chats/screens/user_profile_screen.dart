import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  void _editName(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Display name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 40),
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final auth = context.read<AuthProvider>();
                final ok = await auth.updateProfile(displayName: newName);
                if (ok && mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Name updated successfully'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },

            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editAbout(BuildContext context, String currentAbout) {
    final controller = TextEditingController(text: currentAbout);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Add a bio or status...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(80, 40),
            ),
            onPressed: () async {
              final newAbout = controller.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              final ok = await auth.updateProfile(bio: newAbout);
              if (ok && mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('About updated successfully'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },

            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPhotoOptions(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final hasPhoto = auth.currentUser?.avatarUrl != null && auth.currentUser!.avatarUrl!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Profile photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.link, color: AppTheme.whatsappGreenLight),
                ),
                title: const Text('Enter Image URL / Preset'),
                onTap: () {
                  Navigator.pop(ctx);
                  _enterImageUrlDialog(context);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.auto_awesome, color: Colors.blue),
                ),
                title: const Text('Choose Avatar Style'),
                onTap: () {
                  Navigator.pop(ctx);
                  _choosePresetAvatar(context);
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE),
                    child: Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: const Text('Remove photo', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    await auth.updateProfile(avatarUrl: '');
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Profile photo removed'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },

                ),
            ],
          ),
        ),
      ),
    );
  }

  void _enterImageUrlDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Profile Photo URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com/avatar.jpg',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(ctx);
                final auth = context.read<AuthProvider>();
                await auth.updateProfile(avatarUrl: url);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _choosePresetAvatar(BuildContext context) {
    final presets = [
      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=200&q=80',
      'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=200&q=80',
      'https://images.unsplash.com/photo-1633332755192-727a05c4013d?auto=format&fit=crop&w=200&q=80',
      'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=200&q=80',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Avatar'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: presets.length,
            itemBuilder: (c, idx) => InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: () async {
                Navigator.pop(ctx);
                final auth = context.read<AuthProvider>();
                await auth.updateProfile(avatarUrl: presets[idx]);
              },
              child: CircleAvatar(
                backgroundImage: NetworkImage(presets[idx]),
              ),
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    final displayName = user?.displayName ?? 'User';
    final username = user?.username ?? 'username';
    final bio = (user?.bio != null && user!.bio!.isNotEmpty) ? user.bio! : 'Available';
    final email = user?.email ?? '';
    final avatarUrl = user?.avatarUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Large Circular Avatar with Camera badge (Exact WhatsApp styling from screenshot)
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 75,
                    backgroundColor: isDark ? AppTheme.darkSearchBar : Colors.grey[200],
                    backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? Icon(
                            Icons.person,
                            size: 90,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey[400],
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => _showPhotoOptions(context),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: AppTheme.whatsappGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // Name Tile
            ListTile(
              leading: const Icon(Icons.person_outline, size: 28),
              title: Text(
                'Name',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              subtitle: Text(
                displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit, size: 20, color: AppTheme.whatsappGreen),
                onPressed: () => _editName(context, displayName),
              ),
              onTap: () => _editName(context, displayName),
            ),
            const Divider(indent: 72, height: 1),

            // About Tile
            ListTile(
              leading: const Icon(Icons.info_outline, size: 28),
              title: Text(
                'About',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              subtitle: Text(
                bio,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit, size: 20, color: AppTheme.whatsappGreen),
                onPressed: () => _editAbout(context, bio),
              ),
              onTap: () => _editAbout(context, bio),
            ),
            const Divider(indent: 72, height: 1),

            // Reserved Username Tile
            ListTile(
              leading: const Icon(Icons.alternate_email, size: 28),
              title: Text(
                'Reserved username',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              subtitle: Text(
                '@$username',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
            ),
            const Divider(indent: 72, height: 1),

            // Email Tile
            ListTile(
              leading: const Icon(Icons.email_outlined, size: 28),
              title: Text(
                'Email',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
              subtitle: Text(
                email,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              trailing: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: AppTheme.whatsappGreen, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'Verified',
                    style: TextStyle(color: AppTheme.whatsappGreen, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
