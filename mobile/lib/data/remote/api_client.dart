import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pashumauli/services/secure_storage_service.dart';

/// Typed HTTP client for Phase 2 backend endpoints.
/// Only endpoints defined in docs/API_CONTRACTS.md are implemented.
/// Do NOT add endpoints not in that contract.
class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  final SecureStorageService _storage;

  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    SecureStorageService? storage,
  })  : _httpClient = httpClient ?? http.Client(),
        _storage = storage ?? SecureStorageService();

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  ApiResponse _parse(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(body, response.statusCode);
      }
      final error = body['error'] as Map<String, dynamic>?;
      return ApiResponse.error(
        error?['code'] as String? ?? 'UNKNOWN',
        error?['message'] as String? ?? response.reasonPhrase ?? 'Error',
        response.statusCode,
      );
    } catch (e) {
      return ApiResponse.error('PARSE_ERROR', e.toString(), response.statusCode);
    }
  }

  // ─── Auth Endpoints ─────────────────────────────────────────────────────────

  /// POST /api/v1/auth/login
  Future<ApiResponse> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'password': password}),
      );
      return _parse(response);
    } catch (e) {
      debugPrint('[API] login error: $e');
      return ApiResponse.error('NETWORK_ERROR', e.toString(), 0);
    }
  }

  /// POST /api/v1/auth/register
  Future<ApiResponse> register({
    required String name,
    required String phone,
    required String password,
    required String role,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/v1/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'password': password,
          'role': role,
        }),
      );
      return _parse(response);
    } catch (e) {
      debugPrint('[API] register error: $e');
      return ApiResponse.error('NETWORK_ERROR', e.toString(), 0);
    }
  }

  /// POST /api/v1/auth/refresh
  Future<ApiResponse> refreshToken(String refreshToken) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/v1/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      return _parse(response);
    } catch (e) {
      debugPrint('[API] refresh error: $e');
      return ApiResponse.error('NETWORK_ERROR', e.toString(), 0);
    }
  }

  /// GET /api/v1/auth/me
  Future<ApiResponse> getMe() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/api/v1/auth/me'),
        headers: await _authHeaders(),
      );
      return _parse(response);
    } catch (e) {
      debugPrint('[API] getMe error: $e');
      return ApiResponse.error('NETWORK_ERROR', e.toString(), 0);
    }
  }

  // ─── Farmers Endpoints ───────────────────────────────────────────────────────

  /// POST /api/v1/farmers
  Future<ApiResponse> createFarmer(Map<String, dynamic> payload) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/v1/farmers'),
        headers: await _authHeaders(),
        body: jsonEncode(payload),
      );
      return _parse(response);
    } catch (e) {
      return ApiResponse.error('NETWORK_ERROR', e.toString(), 0);
    }
  }

  /// GET /api/v1/farmers
  Future<ApiResponse> listFarmers({int page = 1, int size = 20}) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/api/v1/farmers?page=$page&size=$size'),
        headers: await _authHeaders(),
      );
      return _parse(response);
    } catch (e) {
      return ApiResponse.error('NETWORK_ERROR', e.toString(), 0);
    }
  }

  /// GET /api/v1/farmers/{id}
  Future<ApiResponse> getFarmer(String id) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/api/v1/farmers/$id'),
        headers: await _authHeaders(),
      );
      return _parse(response);
    } catch (e) {
      return ApiResponse.error('NETWORK_ERROR', e.toString(), 0);
    }
  }

  // ─── Animals Endpoints ───────────────────────────────────────────────────────

  /// POST /api/v1/animals
  Future<ApiResponse> createAnimal(Map<String, dynamic> payload) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/v1/animals'),
        headers: await _authHeaders(),
        body: jsonEncode(payload),
      );
      return _parse(response);
    } catch (e) {
      return ApiResponse.error('NETWORK_ERROR', e.toString(), 0);
    }
  }

  /// GET /api/v1/animals
  Future<ApiResponse> listAnimals({
    String? farmerId,
    int page = 1,
    int size = 20,
  }) async {
    try {
      final params = {
        'page': page.toString(),
        'size': size.toString(),
        if (farmerId != null) 'farmer_id': farmerId,
      };
      final uri = Uri.parse('$baseUrl/api/v1/animals')
          .replace(queryParameters: params);
      final response = await _httpClient.get(
        uri,
        headers: await _authHeaders(),
      );
      return _parse(response);
    } catch (e) {
      return ApiResponse.error('NETWORK_ERROR', e.toString(), 0);
    }
  }

  /// GET /api/v1/animals/{id}
  Future<ApiResponse> getAnimal(String id) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/api/v1/animals/$id'),
        headers: await _authHeaders(),
      );
      return _parse(response);
    } catch (e) {
      return ApiResponse.error('NETWORK_ERROR', e.toString(), 0);
    }
  }

  // ─── Health Cases Endpoints ──────────────────────────────────────────────────

  /// POST /api/v1/cases
  Future<ApiResponse> createCase(Map<String, dynamic> payload) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/api/v1/cases'),
        headers: await _authHeaders(),
        body: jsonEncode(payload),
      );
      return _parse(response);
    } catch (e) {
      return ApiResponse.error('NETWORK_ERROR', e.toString(), 0);
    }
  }

  /// GET /api/v1/cases
  Future<ApiResponse> listCases({int page = 1, int size = 20}) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/api/v1/cases?page=$page&size=$size'),
        headers: await _authHeaders(),
      );
      return _parse(response);
    } catch (e) {
      return ApiResponse.error('NETWORK_ERROR', e.toString(), 0);
    }
  }

  /// GET /api/v1/cases/{id}
  Future<ApiResponse> getCase(String id) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/api/v1/cases/$id'),
        headers: await _authHeaders(),
      );
      return _parse(response);
    } catch (e) {
      return ApiResponse.error('NETWORK_ERROR', e.toString(), 0);
    }
  }
}

/// Typed API response envelope.
class ApiResponse {
  final bool isSuccess;
  final int statusCode;
  final Map<String, dynamic>? data;
  final String? errorCode;
  final String? errorMessage;

  const ApiResponse._({
    required this.isSuccess,
    required this.statusCode,
    this.data,
    this.errorCode,
    this.errorMessage,
  });

  factory ApiResponse.success(Map<String, dynamic> data, int statusCode) =>
      ApiResponse._(isSuccess: true, statusCode: statusCode, data: data);

  factory ApiResponse.error(
          String code, String message, int statusCode) =>
      ApiResponse._(
        isSuccess: false,
        statusCode: statusCode,
        errorCode: code,
        errorMessage: message,
      );

  bool get isNetworkError => statusCode == 0;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isConflict => statusCode == 409;
}
