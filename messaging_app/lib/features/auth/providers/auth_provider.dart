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
        _currentUser ??= UserProfileModel(
          userId: _storage.getUserId() ?? '',
          username: _storage.getUsername() ?? '',
          displayName: _storage.getDisplayName() ?? _storage.getUsername() ?? '',
          email: _storage.getEmail(),
          isOnline: true,
        );
        // Try to fetch profile with existing access token
        try {
          _currentUser = await _apiService.getMe();
        } catch (_) {
          // If token expired, try refreshing
          final refreshToken = _storage.getRefreshToken();
          if (refreshToken != null) {
            final authResponse = await _apiService.refreshToken(refreshToken);
            await _storage.saveTokens(
              accessToken: authResponse.accessToken,
              refreshToken: authResponse.refreshToken,
            );
            _currentUser = authResponse.profile;
          } else {
            await _storage.clearAll();
          }
        }
      }
    } catch (_) {
      await _storage.clearAll();
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
    notifyListeners();

    try {
      await _apiService.sendOtp(email);
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

  Future<bool> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedProfile = await _apiService.updateProfile(
        displayName: displayName,
        bio: bio,
        avatarUrl: avatarUrl,
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

