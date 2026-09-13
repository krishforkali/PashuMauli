import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pashumauli/services/secure_storage_service.dart';

/// Default API base URL from compile-time environment variable `API_BASE_URL`.
/// Can be overridden at build time via `--dart-define=API_BASE_URL=<URL>`.
///
/// If missing, a StateError is thrown to prevent the app from silently
/// falling back to a localhost address on physical devices.
/// The only exception is during automated unit testing where it defaults
/// to `127.0.0.1:8000`.
String get kDefaultApiBaseUrl {
  const url = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (url.isNotEmpty) return url;

  bool isTest = false;
  try {
    isTest = Platform.environment.containsKey('FLUTTER_TEST');
  } catch (_) {}

  if (isTest) {
    return 'http://127.0.0.1:8000';
  }

  throw StateError(
    'API_BASE_URL is missing! '
    'You must build/run with --dart-define=API_BASE_URL=https://YOUR-TUNNEL-URL '
    'Localhost is no longer silently used for physical devices.'
  );
}

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
    final url = '$baseUrl/api/v1/auth/login';
    debugPrint('[API] POST $url');
    try {
      final response = await _httpClient.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'password': password}),
      );
      debugPrint('[API] POST $url -> ${response.statusCode}');
      return _parse(response);
    } catch (e) {
      debugPrint('[API] login FAILED: ${e.runtimeType}: $e');
      return ApiResponse.networkError(e);
    }
  }

  /// POST /api/v1/auth/register
  Future<ApiResponse> register({
    required String name,
    required String phone,
    required String password,
    required String role,
  }) async {
    final url = '$baseUrl/api/v1/auth/register';
    debugPrint('[API] POST $url');
    try {
      final response = await _httpClient.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'password': password,
          'role': role,
        }),
      );
      debugPrint('[API] POST $url -> ${response.statusCode}');
      return _parse(response);
    } catch (e) {
      debugPrint('[API] register FAILED: ${e.runtimeType}: $e');
      return ApiResponse.networkError(e);
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

  /// Build a network-level error from a caught Dart exception.
  /// Preserves the exception type for diagnostics (e.g. SocketException,
  /// HandshakeException) rather than collapsing everything to 'Network error'.
  factory ApiResponse.networkError(Object e) {
    final type = e.runtimeType.toString();
    // Provide a user-friendly summary while keeping the raw detail.
    String friendly;
    final raw = e.toString();
    if (raw.contains('Connection refused') ||
        raw.contains('ECONNREFUSED') ||
        raw.contains('connection refused')) {
      friendly = 'Connection refused — is the backend running?';
    } else if (raw.contains('SocketException') ||
        raw.contains('Network is unreachable') ||
        raw.contains('No address associated')) {
      friendly = 'Socket error — check network connection.';
    } else if (raw.contains('HandshakeException') ||
        raw.contains('CERTIFICATE_VERIFY_FAILED')) {
      friendly = 'TLS/certificate error: $raw';
    } else if (raw.contains('TimeoutException') ||
        raw.contains('Connection timed out')) {
      friendly = 'Connection timed out — check backend and network.';
    } else {
      friendly = '$type: $raw';
    }
    return ApiResponse._(
      isSuccess: false,
      statusCode: 0,
      errorCode: 'NETWORK_ERROR',
      errorMessage: friendly,
    );
  }

  bool get isNetworkError => statusCode == 0;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isConflict => statusCode == 409;
}
