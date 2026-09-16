/// Konfigurasi endpoint backend FindIt API.
///
/// Base URL diambil dari `--dart-define=API_BASE_URL=...` saat build/run,
/// dengan fallback ke server live (VPS). Dengan begitu environment
/// dev/staging/prod tinggal ganti flag waktu menjalankan app, tanpa
/// hardcode di banyak file.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://139-190-96-203.sslip.io/findit',
  );

  /// Endpoint dikelompokkan di `/api`.
  static const String apiPrefix = '/api';

  /// Menghasilkan URL lengkap dari path relatif seperti `/uploads/abc.jpg`
  /// atau `/api/health`. Kalau sudah URL absolut, langsung dikembalikan.
  static String resolve(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    if (!pathOrUrl.startsWith('/')) {
      return '$baseUrl/$pathOrUrl';
    }
    return '$baseUrl$pathOrUrl';
  }
}