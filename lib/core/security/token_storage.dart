import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_exception.dart';

/// Penyimpanan token JWT & profil user yang aman (encrypted storage),
/// bukan shared_preferences biasa.
class TokenStorage {
  TokenStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _tokenKey = 'findit_jwt_token';
  static const _userKey = 'findit_user_json';

  static Future<String?> readToken() => _storage.read(key: _tokenKey);

  static Future<String?> readUserJson() => _storage.read(key: _userKey);

  static Future<void> write(String token, String userJson) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: userJson);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  /// Memastikan sesi masih aktif; melempar [AuthException] bila token kosong.
  static Future<String> requireToken() async {
    final token = await readToken();
    if (token == null || token.isEmpty) {
      throw AuthException('Sesi Anda telah berakhir. Silakan login ulang.');
    }
    return token;
  }
}