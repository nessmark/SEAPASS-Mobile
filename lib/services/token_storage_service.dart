import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure on-device encrypted storage for the Laravel Sanctum Bearer token.
class TokenStorageService {
  const TokenStorageService._();

  static const String _keySanctumToken = 'seapass_sanctum_token';
  static const String _keyUserRole = 'seapass_user_role';

  // Configure Android options to use encrypted shared preferences / KeyStore
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// In-memory cache to avoid disk reads on every HTTP request
  static String? _cachedToken;
  static String? _cachedRole;

  /// Persist the Sanctum plain-text Bearer token securely on the device.
  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: _keySanctumToken, value: token);
  }

  /// Retrieve the current Sanctum token. Returns null if not logged in.
  static Future<String?> getToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }
    try {
      _cachedToken = await _storage.read(key: _keySanctumToken);
      return _cachedToken;
    } catch (_) {
      return null;
    }
  }

  /// Persist the authenticated user role (e.g. 'scanner' or 'passenger').
  static Future<void> saveUserRole(String role) async {
    _cachedRole = role.toLowerCase().trim();
    await _storage.write(key: _keyUserRole, value: _cachedRole);
  }

  /// Retrieve the stored user role. Returns null if not stored.
  static Future<String?> getUserRole() async {
    if (_cachedRole != null && _cachedRole!.isNotEmpty) {
      return _cachedRole;
    }
    try {
      _cachedRole = await _storage.read(key: _keyUserRole);
      return _cachedRole;
    } catch (_) {
      return null;
    }
  }

  /// Check whether an active token exists.
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Delete both token and role from secure storage and clear in-memory cache (e.g. on logout or 401).
  /// Selectively removes ONLY auth/session keys, preserving server configuration (IP / Base URL).
  static Future<void> deleteToken() async {
    _cachedToken = null;
    _cachedRole = null;
    try {
      // 1. Delete encrypted credentials from FlutterSecureStorage
      await _storage.delete(key: _keySanctumToken);
      await _storage.delete(key: _keyUserRole);

      // 2. Selectively delete ONLY auth-related keys in SharedPreferences (NEVER call prefs.clear())
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_role');
      await prefs.remove('user_data');
    } catch (_) {}
  }
}
