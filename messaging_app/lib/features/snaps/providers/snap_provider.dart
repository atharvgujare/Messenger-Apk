import 'package:flutter/material.dart';
import '../models/snap_model.dart';
import '../services/snap_service.dart';

class SnapProvider extends ChangeNotifier {
  final SnapService _snapService;

  List<SnapModel> _activeSnaps = [];
  bool _isLoading = false;
  String? _errorMessage;

  SnapProvider(this._snapService);

  List<SnapModel> get activeSnaps => _activeSnaps;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchActiveSnaps() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _activeSnaps = await _snapService.getActiveSnaps();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<SnapModel?> openSnap(String snapId) async {
    try {
      final snap = await _snapService.openSnap(snapId);
      // Remove opened snap from active snaps
      _activeSnaps.removeWhere((s) => s.id == snapId);
      notifyListeners();
      return snap;
    } catch (_) {
      return null;
    }
  }

  Future<bool> sendSnap({
    required String recipientId,
    required List<int> mediaBytes,
    required String fileName,
    String? caption,
    int timerSeconds = 5,
    bool isViewOnce = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final mediaUrl = await _snapService.uploadSnapMedia(mediaBytes, fileName);
      await _snapService.sendSnap(
        recipientId: recipientId,
        mediaUrl: mediaUrl,
        caption: caption,
        timerSeconds: timerSeconds,
        isViewOnce: isViewOnce,
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
}
