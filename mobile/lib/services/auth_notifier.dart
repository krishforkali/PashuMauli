import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pashumauli/domain/entities/entities.dart';
import 'package:pashumauli/services/secure_storage_service.dart';

/// Authentication state
sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final String userId;
  final String name;
  final String phone;
  final UserRole role;

  const AuthAuthenticated({
    required this.userId,
    required this.name,
    required this.phone,
    required this.role,
  });
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Auth notifier — manages authenticated/unauthenticated state.
/// On startup loads stored token; on logout clears it.
class AuthNotifier extends StateNotifier<AuthState> {
  final SecureStorageService _storage;

  AuthNotifier({SecureStorageService? storage})
      : _storage = storage ?? SecureStorageService(),
        super(const AuthLoading());

  /// Called on app startup to restore session from secure storage.
  Future<void> initialize() async {
    try {
      final hasSession = await _storage.hasSession();
      if (!hasSession) {
        state = const AuthUnauthenticated();
        return;
      }

      final userId = await _storage.getUserId();
      final name = await _storage.getUserName();
      final phone = await _storage.getUserPhone();
      final role = await _storage.getUserRole();

      if (userId == null || name == null || phone == null || role == null) {
        // Corrupted session data — clear and force re-login
        await _storage.clearSession();
        state = const AuthUnauthenticated();
        return;
      }

      state = AuthAuthenticated(
        userId: userId,
        name: name,
        phone: phone,
        role: UserRole.fromString(role),
      );
    } catch (_) {
      state = const AuthUnauthenticated();
    }
  }

  /// Called after successful API login.
  Future<void> login({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String role,
    required String name,
    required String phone,
  }) async {
    await _storage.saveSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      role: role,
      name: name,
      phone: phone,
    );
    state = AuthAuthenticated(
      userId: userId,
      name: name,
      phone: phone,
      role: UserRole.fromString(role),
    );
  }

  /// Called on logout — clears all stored tokens.
  Future<void> logout() async {
    await _storage.clearSession();
    state = const AuthUnauthenticated();
  }

  /// Update the access token after a refresh.
  Future<void> updateAccessToken(String newToken) async {
    await _storage.saveAccessToken(newToken);
    // State remains authenticated; no state rebuild needed.
  }

  bool get isAuthenticated => state is AuthAuthenticated;

  UserRole? get currentRole {
    final s = state;
    if (s is AuthAuthenticated) return s.role;
    return null;
  }

  String? get currentUserId {
    final s = state;
    if (s is AuthAuthenticated) return s.userId;
    return null;
  }
}

// ─── Riverpod Providers ────────────────────────────────────────────────────────

final secureStorageServiceProvider = Provider<SecureStorageService>(
  (_) => SecureStorageService(),
);

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  return AuthNotifier(storage: storage);
});
