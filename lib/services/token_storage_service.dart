import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure on-device encrypted storage for the Laravel Sanctum Bearer token.
class TokenStorageService {
  const TokenStorageService._();

  static const String _keySanctumToken = 'seapass_sanctum_token';

  // Configure Android options to use encrypted shared preferences / KeyStore
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// In-memory cache to avoid disk reads on every HTTP request
  static String? _cachedToken;

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

  /// Check whether an active token exists.
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Delete the token from secure storage and clear in-memory cache (e.g. on logout or 401).
  static Future<void> deleteToken() async {
    _cachedToken = null;
    try {
      await _storage.delete(key: _keySanctumToken);
    } catch (_) {}
  }
}
