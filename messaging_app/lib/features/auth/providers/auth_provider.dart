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

  AuthProvider(this._apiService, this._storage);

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _storage.hasSession;
  UserProfileModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;

  Future<void> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_storage.hasSession) {
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

  Future<void> logout() async {
    final refreshToken = _storage.getRefreshToken();
    if (refreshToken != null) {
      await _apiService.logout(refreshToken);
    }
    await _storage.clearAll();
    _currentUser = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
