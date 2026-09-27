import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class AppConfig {
  static const String appName = 'Messenger';

  // Smart base URL resolution:
  // - Web / Windows desktop -> http://localhost:5095
  // - Android physical device (with adb reverse tcp:5095 tcp:5095) -> http://127.0.0.1:5095
  // - Android WiFi LAN -> http://192.168.1.103:5095
  // - Android Emulator -> http://10.0.2.2:5095
  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://localhost:5095';
    try {
      if (Platform.isAndroid) {
        return 'http://127.0.0.1:5095';
      }
    } catch (_) {}
    return 'http://localhost:5095';
  }

  static String baseUrl = defaultBaseUrl;

  static String get apiBaseUrl => '$baseUrl/api';
  static String get chatHubUrl => '$baseUrl/hubs/chat';

  static void setBaseUrl(String url) {
    baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }
}
