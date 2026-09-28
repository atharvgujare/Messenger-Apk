import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyUserId = 'auth_user_id';
  static const String _keyUsername = 'auth_username';
  static const String _keyDisplayName = 'auth_display_name';
  static const String _keyEmail = 'auth_email';
  static const String _keyAvatarUrl = 'auth_avatar_url';

  final SharedPreferences _prefs;

  LocalStorage(this._prefs);

  static Future<LocalStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorage(prefs);
  }

  Future<void> saveAuthData({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String username,
    required String displayName,
    required String email,
    String? avatarUrl,
  }) async {
    await _prefs.setString(_keyAccessToken, accessToken);
    await _prefs.setString(_keyRefreshToken, refreshToken);
    await _prefs.setString(_keyUserId, userId);
    await _prefs.setString(_keyUsername, username);
    await _prefs.setString(_keyDisplayName, displayName);
    await _prefs.setString(_keyEmail, email);
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      await _prefs.setString(_keyAvatarUrl, avatarUrl);
    }
  }

  Future<void> saveAvatarUrl(String? avatarUrl) async {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      await _prefs.setString(_keyAvatarUrl, avatarUrl);
    } else {
      await _prefs.remove(_keyAvatarUrl);
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _prefs.setString(_keyAccessToken, accessToken);
    await _prefs.setString(_keyRefreshToken, refreshToken);
  }

  String? getAccessToken() => _prefs.getString(_keyAccessToken);
  String? getRefreshToken() => _prefs.getString(_keyRefreshToken);
  String? getUserId() => _prefs.getString(_keyUserId);
  String? getUsername() => _prefs.getString(_keyUsername);
  String? getDisplayName() => _prefs.getString(_keyDisplayName);
  String? getEmail() => _prefs.getString(_keyEmail);
  String? getAvatarUrl() => _prefs.getString(_keyAvatarUrl);

  bool get hasSession => getAccessToken() != null && getUserId() != null;

  Future<void> clearAll() async {
    await _prefs.remove(_keyAccessToken);
    await _prefs.remove(_keyRefreshToken);
    await _prefs.remove(_keyUserId);
    await _prefs.remove(_keyUsername);
    await _prefs.remove(_keyDisplayName);
    await _prefs.remove(_keyEmail);
    await _prefs.remove(_keyAvatarUrl);
  }
}
