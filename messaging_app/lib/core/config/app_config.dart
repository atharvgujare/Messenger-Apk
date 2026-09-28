import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'Messenger';

  static const String _envUrl = String.fromEnvironment('BACKEND_URL');

  // Production Live Render Backend URL
  static const String renderProductionUrl = 'https://messenger-apk.onrender.com';
  // Local Backend URL for laptop testing & real Gmail OTP dispatch
  static const String localBackendUrl = 'http://localhost:5095';

  static String get defaultBaseUrl {
    if (_envUrl.isNotEmpty) return _envUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (kIsWeb && (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1')) {
      return localBackendUrl;
    }
    return renderProductionUrl;
  }

  static String baseUrl = defaultBaseUrl;

  static String get apiBaseUrl => '$baseUrl/api';
  static String get chatHubUrl => '$baseUrl/hubs/chat';

  static void setBaseUrl(String url) {
    baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }
}
