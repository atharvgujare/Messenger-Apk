import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/auth_models.dart';

class AuthApiService {
  final ApiClient _client;

  AuthApiService(this._client);

  Future<AuthResponseModel> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _client.post(
      ApiEndpoints.register,
      includeAuth: false,
      body: {
        'username': username,
        'email': email,
        'password': password,
        'displayName': displayName,
      },
    );
    return AuthResponseModel.fromJson(response);
  }

  Future<AuthResponseModel> login({
    required String loginIdentifier,
    required String password,
    String? deviceInfo,
  }) async {
    final response = await _client.post(
      ApiEndpoints.login,
      includeAuth: false,
      body: {
        'loginIdentifier': loginIdentifier,
        'password': password,
        'deviceInfo': deviceInfo ?? 'Flutter Client',
      },
    );
    return AuthResponseModel.fromJson(response);
  }

  Future<AuthResponseModel> refreshToken(String refreshToken) async {
    final response = await _client.post(
      ApiEndpoints.refresh,
      includeAuth: false,
      body: {
        'refreshToken': refreshToken,
      },
    );
    return AuthResponseModel.fromJson(response);
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _client.post(
        ApiEndpoints.logout,
        body: {
          'refreshToken': refreshToken,
        },
      );
    } catch (_) {}
  }

  Future<UserProfileModel> getMe() async {
    final response = await _client.get(ApiEndpoints.me);
    return UserProfileModel.fromJson(response);
  }
}
