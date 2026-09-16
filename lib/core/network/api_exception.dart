/// Pengecualian terpusat untuk semua panggilan API.
///
/// UI cukup menangkap [ApiException] (atau turunannya) dan menampilkan
/// `message` yang sudah user-friendly. Bedakan:
/// - [NetworkException]: koneksi bermasalah / server tak terjangkau.
/// - [TimeoutExceptionNonNull]: koneksi timeout.
/// - [ApiException]: respon 4xx dengan pesan validasi dari backend.
/// - [ServerException]: respon 5xx (salah backend, coba lagi nanti).
/// - [AuthException]: 401 -> token hilang/kedaluwarsa, perlu login ulang.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.data});

  final String message;
  final int? statusCode;
  final Object? data;

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException([String? message])
      : super(message ?? 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
}

class ApiTimeoutException extends ApiException {
  ApiTimeoutException([String? message])
      : super(message ?? 'Permintaan terlalu lama. Silakan coba lagi.');
}

class ServerException extends ApiException {
  ServerException([String? message])
      : super(message ?? 'Server sedang bermasalah. Silakan coba beberapa saat lagi.');
}

class AuthException extends ApiException {
  AuthException([String? message]) : super(message ?? 'Sesi Anda telah berakhir. Silakan login ulang.');
}