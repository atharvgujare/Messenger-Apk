import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../auth/models/auth_models.dart';
import '../models/user_search_model.dart';

class UserApiService {
  final ApiClient _client;

  UserApiService(this._client);

  Future<List<UserSearchResultModel>> searchUsers(String query, {int limit = 20}) async {
    final response = await _client.get(
      '${ApiEndpoints.userSearch}?q=${Uri.encodeComponent(query)}&limit=$limit',
    );
    if (response is List) {
      return response.map((item) => UserSearchResultModel.fromJson(item)).toList();
    }
    return [];
  }

  Future<UserProfileModel> getUserById(String id) async {
    final response = await _client.get('/users/$id');
    return UserProfileModel.fromJson(response);
  }

  Future<UserProfileModel> updateProfile(Map<String, dynamic> data) async {
    final response = await _client.put('/users/me', body: data);
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
}
