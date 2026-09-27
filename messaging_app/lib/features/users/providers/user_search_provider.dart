import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_search_model.dart';
import '../services/user_api_service.dart';

class UserSearchProvider extends ChangeNotifier {
  final UserApiService _apiService;
  Timer? _debounce;

  List<UserSearchResultModel> _results = [];
  bool _isLoading = false;
  String _currentQuery = '';
  String? _errorMessage;

  UserSearchProvider(this._apiService);

  List<UserSearchResultModel> get results => _results;
  bool get isLoading => _isLoading;
  String get currentQuery => _currentQuery;
  String? get errorMessage => _errorMessage;

  void onQueryChanged(String query) {
    _currentQuery = query;
    _debounce?.cancel();

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _results = [];
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      await _executeSearch(trimmed);
    });
  }

  Future<void> _executeSearch(String query) async {
    try {
      final list = await _apiService.searchUsers(query);
      // Only update if query hasn't changed in the meantime
      if (_currentQuery.trim() == query) {
        _results = list;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      if (_currentQuery.trim() == query) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void clearSearch() {
    _debounce?.cancel();
    _currentQuery = '';
    _results = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
