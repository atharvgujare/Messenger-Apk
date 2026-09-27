import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../storage/local_storage.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, dynamic>? errors;

  ApiException({required this.message, required this.statusCode, this.errors});

  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _client = http.Client();
  final LocalStorage _storage;

  ApiClient(this._storage);

  Map<String, String> _buildHeaders({bool includeAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (includeAuth) {
      final token = _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> get(String endpoint, {bool includeAuth = true}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final response = await _client.get(uri, headers: _buildHeaders(includeAuth: includeAuth));
    return _processResponse(response);
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body, bool includeAuth = true}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final response = await _client.post(
      uri,
      headers: _buildHeaders(includeAuth: includeAuth),
      body: body != null ? jsonEncode(body) : null,
    );
    return _processResponse(response);
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body, bool includeAuth = true}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final response = await _client.put(
      uri,
      headers: _buildHeaders(includeAuth: includeAuth),
      body: body != null ? jsonEncode(body) : null,
    );
    return _processResponse(response);
  }

  Future<dynamic> delete(String endpoint, {bool includeAuth = true}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final response = await _client.delete(uri, headers: _buildHeaders(includeAuth: includeAuth));
    return _processResponse(response);
  }

  Future<dynamic> uploadMultipart(
    String endpoint, {
    required String fieldName,
    required List<int> fileBytes,
    required String filename,
    bool includeAuth = true,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final request = http.MultipartRequest('POST', uri);

    if (includeAuth) {
      final token = _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }

    request.files.add(http.MultipartFile.fromBytes(
      fieldName,
      fileBytes,
      filename: filename,
    ));

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    return _processResponse(response);
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String message = 'Request failed with status: ${response.statusCode}';
    Map<String, dynamic>? fieldErrors;

    try {
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('detail')) {
            message = decoded['detail'].toString();
          } else if (decoded.containsKey('title')) {
            message = decoded['title'].toString();
          } else if (decoded.containsKey('message')) {
            message = decoded['message'].toString();
          }
          if (decoded['errors'] is Map<String, dynamic>) {
            fieldErrors = decoded['errors'] as Map<String, dynamic>;
          }
        }
      }
    } catch (_) {}

    throw ApiException(
      message: message,
      statusCode: response.statusCode,
      errors: fieldErrors,
    );
  }
}
