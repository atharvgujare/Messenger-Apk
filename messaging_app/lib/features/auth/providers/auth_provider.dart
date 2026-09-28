import 'package:flutter/foundation.dart';
import '../../../core/storage/local_storage.dart';
import '../models/auth_models.dart';
import '../services/auth_api_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthApiService _apiService;
  final LocalStorage _storage;

  bool _isLoading = false;
  bool _isInitialized = false;
  UserProfileModel? _currentUser;
  String? _errorMessage;
  String? _lastOtpCode;

  AuthProvider(this._apiService, this._storage) {
    if (_storage.hasSession) {
      _currentUser = UserProfileModel(
        userId: _storage.getUserId() ?? '',
        username: _storage.getUsername() ?? '',
        displayName: _storage.getDisplayName() ?? _storage.getUsername() ?? '',
        email: _storage.getEmail(),
        isOnline: true,
      );
    }
  }

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _storage.hasSession;
  UserProfileModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  String? get lastOtpCode => _lastOtpCode;

  String get currentUserId => _currentUser?.userId.isNotEmpty == true
      ? _currentUser!.userId
      : (_storage.getUserId() ?? '');

  String get currentUsername => _currentUser?.username.isNotEmpty == true
      ? _currentUser!.username
      : (_storage.getUsername() ?? '');

  String get currentDisplayName => _currentUser?.displayName.isNotEmpty == true
      ? _currentUser!.displayName
      : (_storage.getDisplayName() ?? _storage.getUsername() ?? '');

  Future<void> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_storage.hasSession) {
        _currentUser = UserProfileModel(
          userId: _storage.getUserId() ?? '',
          username: _storage.getUsername() ?? '',
          displayName: _storage.getDisplayName() ?? _storage.getUsername() ?? '',
          email: _storage.getEmail(),
          isOnline: true,
        );

        // Attempt silent profile sync / token refresh in background
        try {
          _currentUser = await _apiService.getMe();
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          // Only refresh if explicitly an authentication / expired token issue
          if (errStr.contains('401') || errStr.contains('unauthorized') || errStr.contains('token')) {
            final refreshToken = _storage.getRefreshToken();
            if (refreshToken != null) {
              try {
                final authResponse = await _apiService.refreshToken(refreshToken);
                await _storage.saveTokens(
                  accessToken: authResponse.accessToken,
                  refreshToken: authResponse.refreshToken,
                );
                _currentUser = authResponse.profile;
              } catch (refreshErr) {
                // Only wipe tokens if refresh token is genuinely rejected as invalid/revoked
                if (refreshErr.toString().toLowerCase().contains('401') || refreshErr.toString().toLowerCase().contains('invalid')) {
                  await _storage.clearAll();
                  _currentUser = null;
                }
              }
            }
          }
        }
      }
    } catch (_) {
      // Keep existing session on transient errors
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String loginIdentifier,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.login(
        loginIdentifier: loginIdentifier,
        password: password,
      );

      await _storage.saveAuthData(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        userId: response.userId,
        username: response.username,
        displayName: response.displayName,
        email: response.email,
      );

      _currentUser = response.profile;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.register(
        username: username,
        email: email,
        password: password,
        displayName: displayName,
      );

      await _storage.saveAuthData(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        userId: response.userId,
        username: response.username,
        displayName: response.displayName,
        email: response.email,
      );

      _currentUser = response.profile;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendOtp(String email) async {
    _isLoading = true;
    _errorMessage = null;
    _lastOtpCode = null;
    notifyListeners();

    try {
      _lastOtpCode = await _apiService.sendOtp(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String otpCode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final isValid = await _apiService.verifyOtp(email, otpCode);
      _isLoading = false;
      notifyListeners();
      return isValid;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerWithOtp({
    required String email,
    required String otpCode,
    required String username,
    required String displayName,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.registerWithOtp(
        email: email,
        otpCode: otpCode,
        username: username,
        displayName: displayName,
        password: password,
      );

      await _storage.saveAuthData(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        userId: response.userId,
        username: response.username,
        displayName: response.displayName,
        email: response.email,
      );

      _currentUser = response.profile;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.forgotPassword(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.resetPassword(
        email: email,
        otpCode: otpCode,
        newPassword: newPassword,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    bool? isPrivate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedProfile = await _apiService.updateProfile(
        displayName: displayName,
        bio: bio,
        avatarUrl: avatarUrl,
        isPrivate: isPrivate,
      );
      _currentUser = updatedProfile;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> followUser(String targetUserId) async {
    try {
      return await _apiService.followUser(targetUserId);
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> unfollowUser(String targetUserId) async {
    try {
      return await _apiService.unfollowUser(targetUserId);
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingFollowRequests() async {
    try {
      return await _apiService.getPendingFollowRequests();
    } catch (e) {
      return [];
    }
  }

  Future<bool> acceptFollowRequest(String requestId) async {
    try {
      return await _apiService.acceptFollowRequest(requestId);
    } catch (e) {
      return false;
    }
  }

  Future<bool> rejectFollowRequest(String requestId) async {
    try {
      return await _apiService.rejectFollowRequest(requestId);
    } catch (e) {
      return false;
    }
  }

  Future<UserProfileModel> getUserProfile(String userId) async {
    return await _apiService.getUserProfile(userId);
  }

  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    return await _apiService.getFollowers(userId);
  }

  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    return await _apiService.getFollowing(userId);
  }



  Future<bool> uploadAvatar(List<int> bytes, String filename) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedProfile = await _apiService.uploadAvatar(bytes, filename);
      _currentUser = updatedProfile;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final refreshToken = _storage.getRefreshToken();
    if (refreshToken != null) {
      await _apiService.logout(refreshToken);
    }
    await _storage.clearAll();
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.deleteAccount();
      await _storage.clearAll();
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

