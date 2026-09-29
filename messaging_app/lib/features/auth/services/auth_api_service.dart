import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/auth_models.dart';

class AuthApiService {
  final ApiClient _client;

  AuthApiService(this._client);

  Future<String?> sendOtp(String email) async {
    final response = await _client.post(
      ApiEndpoints.sendOtp,
      includeAuth: false,
      body: {'email': email},
    );
    if (response is Map<String, dynamic> && response.containsKey('otpCode')) {
      return response['otpCode']?.toString();
    }
    return null;
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

  Future<AuthResponseModel> phoneLogin({
    required String phoneNumber,
    String? firebaseIdToken,
    String? displayName,
    String? username,
  }) async {
    final body = <String, dynamic>{'phoneNumber': phoneNumber};
    if (firebaseIdToken != null) body['firebaseIdToken'] = firebaseIdToken;
    if (displayName != null) body['displayName'] = displayName;
    if (username != null) body['username'] = username;

    final response = await _client.post(
      ApiEndpoints.phoneLogin,
      includeAuth: false,
      body: body,
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

  Future<String?> forgotPassword(String email) async {
    final response = await _client.post(
      '/auth/forgot-password',
      includeAuth: false,
      body: {'email': email},
    );
    if (response is Map<String, dynamic> && response.containsKey('otpCode')) {
      return response['otpCode']?.toString();
    }
    return null;
  }

  Future<void> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    await _client.post(
      '/auth/reset-password',
      includeAuth: false,
      body: {
        'email': email,
        'otpCode': otpCode,
        'newPassword': newPassword,
      },
    );
  }

  Future<UserProfileModel> getMe() async {
    final response = await _client.get(ApiEndpoints.me);
    return UserProfileModel.fromJson(response);
  }

  Future<UserProfileModel> getUserProfile(String userId) async {
    final response = await _client.get('/users/$userId');
    return UserProfileModel.fromJson(response);
  }

  Future<UserProfileModel> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    bool? isPrivate,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (bio != null) body['bio'] = bio;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
    if (isPrivate != null) body['isPrivate'] = isPrivate;

    final response = await _client.put(
      ApiEndpoints.profile,
      body: body,
    );
    return UserProfileModel.fromJson(response);
  }

  Future<UserProfileModel> uploadAvatar(List<int> bytes, String filename) async {
    final response = await _client.uploadMultipart(
      '/users/me/avatar',
      fieldName: 'file',
      fileBytes: bytes,
      filename: filename,
    );
    return UserProfileModel.fromJson(response);
  }

  Future<void> deleteAccount() async {
    await _client.delete('/users/me');
  }

  // Follow APIs
  Future<Map<String, dynamic>> followUser(String targetUserId) async {
    final response = await _client.post('/users/$targetUserId/follow');
    return response as Map<String, dynamic>;
  }

  Future<bool> unfollowUser(String targetUserId) async {
    final response = await _client.post('/users/$targetUserId/unfollow');
    return response is Map<String, dynamic> && response['success'] == true;
  }

  Future<List<Map<String, dynamic>>> getPendingFollowRequests() async {
    final response = await _client.get('/users/follow-requests');
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    return [];
  }

  Future<bool> acceptFollowRequest(String requestId) async {
    final response = await _client.post('/users/follow-requests/$requestId/accept');
    return response is Map<String, dynamic> && response['success'] == true;
  }

  Future<bool> rejectFollowRequest(String requestId) async {
    final response = await _client.post('/users/follow-requests/$requestId/reject');
    return response is Map<String, dynamic> && response['success'] == true;
  }

  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    final response = await _client.get('/users/$userId/followers');
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    final response = await _client.get('/users/$userId/following');
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    return [];
  }
}

