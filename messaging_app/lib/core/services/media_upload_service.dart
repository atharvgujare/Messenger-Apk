import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class MediaUploadService {
  MediaUploadService._();
  static final MediaUploadService instance = MediaUploadService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  /// Uploads an image file to Firebase Storage and returns the permanent download URL.
  Future<String> uploadImage({
    required File file,
    required String conversationId,
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}.jpg';
    final ref = _storage.ref().child('chat_media/$conversationId/images/$fileName');

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {'conversationId': conversationId},
    );

    final uploadTask = ref.putFile(file, metadata);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  /// Uploads a voice recording to Firebase Storage and returns the permanent download URL.
  Future<String> uploadVoiceNote({
    required File file,
    required String conversationId,
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}.m4a';
    final ref = _storage.ref().child('chat_media/$conversationId/voice/$fileName');

    final metadata = SettableMetadata(
      contentType: 'audio/m4a',
      customMetadata: {'conversationId': conversationId},
    );

    final uploadTask = ref.putFile(file, metadata);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}
