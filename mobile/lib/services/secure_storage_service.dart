import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction over flutter_secure_storage.
/// Never stores provider secrets — SECURITY.md rule.
class SecureStorageService {
  static const String _accessTokenKey = 'pm_access_token';
  static const String _refreshTokenKey = 'pm_refresh_token';
  static const String _userIdKey = 'pm_user_id';
  static const String _userRoleKey = 'pm_user_role';
  static const String _userNameKey = 'pm_user_name';
  static const String _userPhoneKey = 'pm_user_phone';

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  Future<String?> getAccessToken() =>
      _storage.read(key: _accessTokenKey);

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  Future<String?> getRefreshToken() =>
      _storage.read(key: _refreshTokenKey);

  Future<void> saveUserId(String id) =>
      _storage.write(key: _userIdKey, value: id);

  Future<String?> getUserId() => _storage.read(key: _userIdKey);

  Future<void> saveUserRole(String role) =>
      _storage.write(key: _userRoleKey, value: role);

  Future<String?> getUserRole() => _storage.read(key: _userRoleKey);

  Future<void> saveUserName(String name) =>
      _storage.write(key: _userNameKey, value: name);

  Future<String?> getUserName() => _storage.read(key: _userNameKey);

  Future<void> saveUserPhone(String phone) =>
      _storage.write(key: _userPhoneKey, value: phone);

  Future<String?> getUserPhone() => _storage.read(key: _userPhoneKey);

  /// Save all session data atomically.
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String role,
    required String name,
    required String phone,
  }) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
      saveUserId(userId),
      saveUserRole(role),
      saveUserName(name),
      saveUserPhone(phone),
    ]);
  }

  /// Clear all session data on logout.
  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _userRoleKey),
      _storage.delete(key: _userNameKey),
      _storage.delete(key: _userPhoneKey),
    ]);
  }

  /// True if there is a stored access token (app has been logged in before).
  Future<bool> hasSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
