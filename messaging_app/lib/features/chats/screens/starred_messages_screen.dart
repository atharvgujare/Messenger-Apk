import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';

class StarredMessagesScreen extends StatelessWidget {
  const StarredMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chatProvider = context.watch<ChatProvider>();
    final starred = chatProvider.starredMessages;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Starred Messages'),
      ),
      body: starred.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(isDark ? 30 : 20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 64,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No starred messages',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Long-press on any message and tap "Star" to save it here for quick access.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: starred.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final message = starred[index];
                final timeStr = DateFormat('dd/MM/yy h:mm a').format(message.createdAtUtc);

                Widget contentWidget;
                if (message.type == MessageType.image) {
                  contentWidget = Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          message.content,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 36),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Photo', style: TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  );
                } else if (message.type == MessageType.voice) {
                  contentWidget = const Row(
                    children: [
                      Icon(Icons.mic, size: 18, color: AppTheme.whatsappGreen),
                      SizedBox(width: 6),
                      Text('Voice message', style: TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  );
                } else {
                  contentWidget = Text(
                    message.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  );
                }

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.whatsappGreenLight,
                    child: Text(
                      message.senderDisplayName.isNotEmpty
                          ? message.senderDisplayName[0].toUpperCase()
                          : (message.senderUsername.isNotEmpty
                              ? message.senderUsername[0].toUpperCase()
                              : '?'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          message.senderDisplayName.isNotEmpty
                              ? message.senderDisplayName
                              : message.senderUsername,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: contentWidget,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                    tooltip: 'Unstar',
                    onPressed: () => chatProvider.toggleStarMessage(message),
                  ),
                  onTap: () {
                    // Find conversation and open
                    final conv = chatProvider.conversations.firstWhere(
                      (c) => c.conversationId == message.conversationId,
                      orElse: () => ConversationModel(
                        conversationId: message.conversationId,
                        type: ConversationType.direct,
                        title: message.senderDisplayName.isNotEmpty
                            ? message.senderDisplayName
                            : message.senderUsername,
                        updatedAtUtc: DateTime.now(),
                      ),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(conversation: conv),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
