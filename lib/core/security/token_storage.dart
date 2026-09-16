import 'package:flutter/foundation.dart';
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

  /// Sesi "jangan ingat saya": hanya disimpan di RAM proses ini dan otomatis
  /// hilang saat aplikasi ditutup. Dipakai saat checkbox "Ingat Saya" mati.
  static String? _memoryToken;
  static String? _memoryUserJson;

  static Future<String?> readToken() async {
    if (_memoryToken != null) return _memoryToken;
    return _storage.read(key: _tokenKey);
  }

  static Future<String?> readUserJson() async {
    if (_memoryUserJson != null) return _memoryUserJson;
    return _storage.read(key: _userKey);
  }

  /// Menyimpan sesi PERMANEN (Ingat Saya dicentang) — survives app restart.
  static Future<void> write(String token, String userJson) async {
    _memoryToken = null;
    _memoryUserJson = null;
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: userJson);
  }

  /// Menyimpan sesi SEMENTARA (Ingat Saya TIDAK dicentang) — hanya di RAM,
  /// terhapus otomatis begitu aplikasi ditutup.
  static Future<void> writeVolatile(String token, String userJson) async {
    _memoryToken = token;
    _memoryUserJson = userJson;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  static Future<void> clear() async {
    _memoryToken = null;
    _memoryUserJson = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  /// Reset sesi in-memory (dipakai di unit test untuk simulasi app restart).
  @visibleForTesting
  static void resetForTest() {
    _memoryToken = null;
    _memoryUserJson = null;
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