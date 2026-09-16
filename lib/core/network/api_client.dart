import 'package:dio/dio.dart';

import '../security/token_storage.dart';
import 'api_config.dart';
import 'api_exception.dart';

/// HTTP client terpusat untuk backend FindIt API.
///
/// Memakai [Dio] dengan:
/// - base URL dari [ApiConfig] (via --dart-define / fallback live).
/// - auto-inject header `Authorization: Bearer <JWT>` untuk setiap request.
/// - error handling terpusat: semua [DioException] dipetakan ke tipe
///   [ApiException] turunan supaya UI tinggal menangkap satu tipe.
///
/// Timeout default 20 detik; panggilan yang butuh waktu lama (mis. foto
/// + inferensi AI) boleh mengirim `Options(timeout: ...)` yang lebih besar,
/// contoh lihat `autoFill()` di ReportRepository (60 detik).
class ApiClient {
  ApiClient._();

  static Dio? _dio;

  /// Digunakan dalam unit test untuk meng-inject mock Dio tanpa
  /// menimpa singleton production. Set `testDio` sebelum test berjalan,
  /// lalu panggil [reset] untuk membersihkan di akhir test.
  static Dio? testDio;

  /// Reset singleton & override ke default (dipakai di setUp/tearDown test).
  static void reset() {
    _dio = null;
    testDio = null;
  }

  static Dio get dio {
    final override = testDio;
    if (override != null) return override;

    final existing = _dio;
    if (existing != null) return existing;

    final client = Dio(
      BaseOptions(
        baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
      ),
    );

    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

    client.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );

    _dio = client;
    return client;
  }

  /// Memetakan [DioException] menjadi [ApiException] terpusat.
  static ApiException toApiException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiTimeoutException();
      case DioExceptionType.transformTimeout:
        return ApiTimeoutException();
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return NetworkException();
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        final message = _backendMessage(error.response?.data) ?? _fallbackMessage(status);
        if (status == 401) return AuthException(message);
        if (status >= 500) return ServerException(message);
        return ApiException(message, statusCode: status, data: error.response?.data);
      case DioExceptionType.cancel:
        return NetworkException('Permintaan dibatalkan.');
      case DioExceptionType.badCertificate:
        return NetworkException('Sertifikat server tidak valid.');
    }
  }

  /// Menampilkan `data.message` dari envelope backend `{status, message, data}`.
  static String? _backendMessage(Object? data) {
    if (data is Map && data['message'] is String) {
      final message = data['message'] as String;
      if (message.isNotEmpty) return message;
    }
    return null;
  }

  static String _fallbackMessage(int status) {
    if (status == 401) return 'Email atau password salah.';
    if (status == 413) return 'Ukuran file terlalu besar (maksimal 5 MB).';
    if (status >= 400 && status < 500) return 'Data tidak valid. Periksa kembali isian Anda.';
    return 'Server sedang bermasalah. Silakan coba lagi.';
  }
}