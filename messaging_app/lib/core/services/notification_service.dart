import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    try {
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      // Create notification channel (Android 8.0+ / 15 strictly requires this!)
      const channel = AndroidNotificationChannel(
        'whatsapp_messenger_channel',
        'WhatsApp Messages',
        description: 'Notifications for new WhatsApp messages',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(channel);
        await androidImplementation.requestNotificationsPermission();
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  Future<bool?> requestPermission() async {
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      return await androidImplementation.requestNotificationsPermission();
    }
    return null;
  }

  Future<void> showMessageNotification({
    required String title,
    required String body,
    String? conversationId,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'whatsapp_messenger_channel',
        'WhatsApp Messages',
        channelDescription: 'Notifications for new WhatsApp messages',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: conversationId,
      );
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }
}
