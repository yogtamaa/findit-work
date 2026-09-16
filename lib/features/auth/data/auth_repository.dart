import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/security/token_storage.dart';
import 'auth_user.dart';

/// Repository autentikasi: login ke `POST /api/login`, simpan token JWT +
/// profil user di secure storage, dan kelola logout.
class AuthRepository {
  AuthRepository();

  /// Login email + password. Sukses -> token & user disimpan sesuai preferensi
  /// "Ingat Saya": [rememberMe]=true menyimpan permanen (survives app restart),
  /// false menyimpan sementara (hanya di RAM, hilang saat app ditutup).
  Future<LoginResult> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final response = await ApiClient.dio.post(
      '/login',
      data: {'email': email.trim(), 'password': password},
    );
    final data = (response.data as Map)['data'] as Map?;
    if (data == null) throw ApiException('Login gagal. Silakan coba lagi.');
    final result = LoginResult.fromJson(data.cast<String, dynamic>());
    if (rememberMe) {
      await TokenStorage.write(result.token, jsonEncode(result.user.toJson()));
    } else {
      await TokenStorage.writeVolatile(result.token, jsonEncode(result.user.toJson()));
    }
    return result;
  }

  /// Mengambil profil user dari sesi tersimpan (tanpa validasi token ke server).
  Future<AuthUser?> getStoredUser() async {
    final raw = await TokenStorage.readUserJson();
    if (raw == null || raw.isEmpty) return null;
    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  Future<void> logout() => TokenStorage.clear();
}