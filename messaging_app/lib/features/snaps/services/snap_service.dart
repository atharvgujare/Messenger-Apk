import '../../../core/network/api_client.dart';
import '../models/snap_model.dart';

class SnapService {
  final ApiClient _client;

  SnapService(this._client);

  Future<String> uploadSnapMedia(List<int> bytes, String filename) async {
    final response = await _client.uploadMultipart(
      '/snaps/media',
      fieldName: 'file',
      fileBytes: bytes,
      filename: filename,
    );
    if (response is Map<String, dynamic> && response.containsKey('mediaUrl')) {
      return response['mediaUrl'].toString();
    }
    throw Exception('Failed to upload snap media.');
  }

  Future<SnapModel> sendSnap({
    required String recipientId,
    required String mediaUrl,
    String? caption,
    int timerSeconds = 5,
    bool isViewOnce = false,
  }) async {
    final response = await _client.post(
      '/snaps',
      body: {
        'recipientId': recipientId,
        'mediaUrl': mediaUrl,
        'caption': caption,
        'timerSeconds': timerSeconds,
        'isViewOnce': isViewOnce,
      },
    );
    return SnapModel.fromJson(response as Map<String, dynamic>);
  }

  Future<List<SnapModel>> getActiveSnaps() async {
    final response = await _client.get('/snaps/active');
    if (response is List) {
      return response.map((s) => SnapModel.fromJson(s as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<SnapModel?> openSnap(String snapId) async {
    try {
      final response = await _client.post('/snaps/$snapId/open');
      return SnapModel.fromJson(response as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
