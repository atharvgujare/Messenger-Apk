import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/auth_models.dart';

class AuthApiService {
  final ApiClient _client;

  AuthApiService(this._client);

  Future<void> sendOtp(String email) async {
    await _client.post(
      ApiEndpoints.sendOtp,
      includeAuth: false,
      body: {'email': email},
    );
  }

  Future<bool> verifyOtp(String email, String otpCode) async {
    final response = await _client.post(
      ApiEndpoints.verifyOtp,
      includeAuth: false,
      body: {'email': email, 'otpCode': otpCode},
    );
    return response is Map<String, dynamic> && response['isValid'] == true;
  }

  Future<AuthResponseModel> registerWithOtp({
    required String email,
    required String otpCode,
    required String username,
    required String displayName,
    required String password,
  }) async {
    final response = await _client.post(
      ApiEndpoints.registerWithOtp,
      includeAuth: false,
      body: {
        'email': email,
        'otpCode': otpCode,
        'username': username,
        'displayName': displayName,
        'password': password,
      },
    );
    return AuthResponseModel.fromJson(response);
  }

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

  Future<UserProfileModel> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (bio != null) body['bio'] = bio;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;

    final response = await _client.put(
      ApiEndpoints.profile,
      body: body,
    );
    return UserProfileModel.fromJson(response);

  }
}

