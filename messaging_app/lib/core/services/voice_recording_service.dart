import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecordingService {
  VoiceRecordingService._();
  static final VoiceRecordingService instance = VoiceRecordingService._();

  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;

  bool get isRecording => _isRecording;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startRecording() async {
    if (_isRecording) return;

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      throw Exception('Microphone permission not granted');
    }

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _currentPath = filePath;

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    _isRecording = true;
  }

  Future<File?> stopRecording() async {
    if (!_isRecording) return null;

    final path = await _recorder.stop();
    _isRecording = false;

    if (path != null && File(path).existsSync()) {
      return File(path);
    }
    if (_currentPath != null && File(_currentPath!).existsSync()) {
      return File(_currentPath!);
    }
    return null;
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      if (path != null && File(path).existsSync()) {
        await File(path).delete();
      }
    } catch (_) {}
  }

  void dispose() {
    _recorder.dispose();
  }
}
