import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/security/token_storage.dart';
import '../models/auto_fill_result.dart';
import '../models/category.dart';
import '../models/found_item_model.dart';

/// Repository untuk interaksi data barang temuan ke backend FindIt API.
class ReportRepository {
  ReportRepository();

  Dio get _dio => ApiClient.dio;

  /// Mengambil daftar kategori dari `GET /api/categories`.
  Future<List<Category>> getCategories() async {
    final response = await _dio.get('/categories');
    final list = (response.data as Map)['data'] as List?;
    return (list ?? [])
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Mengambil daftar barang temuan (type=found) milik user tertentu.
  ///
  /// Endpoint backend bersifat publik (`GET /reports?type=found`) sehingga
  /// mengembalikan SEMUA laporan found. Kami filter di sisi client
  /// berdasarkan `user_id` supaya RA hanya melihat miliknya.
  ///
  /// **Hutang teknis:** filter `user_id` di client-side bukan solusi ideal
  /// karena semua data se-hotel di-download dulu. Backend perlu
  /// menambahkan query param `?user_id=` atau filter berdasarkan token
  /// di masa depan.
  Future<List<FoundItemModel>> fetchMyFoundReports(int userId) async {
    final response = await _dio.get('/reports', queryParameters: {'type': 'found'});
    final list = (response.data as Map)['data'] as List?;
    return (list ?? [])
        .where((e) => e is Map && e['user_id'].toString() == userId.toString())
        .map((e) => FoundItemModel.fromReportJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Upload foto ke `POST /reports/auto-fill` (endpoint AI + upload sekaligus).
  ///
  /// Backend mengembalikan 200 BAIK saat AI berhasil MAUPUN gagal/timeout
  /// (sifat non-blocking); `photo_url` di `data` selalu terisi pada status 200.
  ///
  /// [onSendProgress] berguna untuk menampilkan progress bar upload,
  /// karena foto kamera HP bisa 2-5 MB dan butuh waktu di jaringan lemah.
  Future<AutoFillResult> autoFill({
    required String photoPath,
    ProgressCallback? onSendProgress,
  }) async {
    final originalFilename = photoPath.split(RegExp(r'[/\\]')).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(photoPath, filename: originalFilename),
    });

    final response = await _dio.post(
      '/reports/auto-fill',
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    final data = (response.data as Map)['data'] as Map?;
    if (data == null) throw ApiException('Response tidak valid dari server.');
    return AutoFillResult.fromJson(data.cast<String, dynamic>());
  }

  /// Upload foto ke `POST /upload` — dipakai SEBAGAI FALLBACK bila auto-fill
  /// gagal total (jaringan putus sebelum respon 200 tiba).
  ///
  /// **JANGAN dipanggil bila auto-fill sukses:** foto sudah ter-upload di
  /// endpoint auto-fill, tidak perlu upload lagi.
  Future<String> uploadPhotoAsFallback({
    required String photoPath,
    ProgressCallback? onSendProgress,
  }) async {
    final originalFilename = photoPath.split(RegExp(r'[/\\]')).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(photoPath, filename: originalFilename),
    });

    final response = await _dio.post(
      '/upload',
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    final data = (response.data as Map)['data'] as Map?;
    return data?['url'] as String? ?? '';
  }

  /// Mengirim barang temuan baru ke `POST /api/reports`.
  ///
  /// Backend membutuhkan `user_id` di payload (walaupun di-override dari
  /// token, handler bind dulu -> wajib ada di body). Kami ambil dari
  /// session yang tersimpan saat login.
  Future<FoundItemModel> createReport({
    required String title,
    String description = '',
    String category = '',
    String roomNumber = '',
    String location = '',
    String photoUrl = '',
    required DateTime itemDate,
  }) async {
    final userId = await _getStoredUserId();

    final body = <String, dynamic>{
      'user_id': userId,
      'type': 'found',
      'title': title,
      'description': description,
      'category': category,
      'room_number': roomNumber,
      'location': location,
      'photo_url': photoUrl,
      'item_date': itemDate.toUtc().toIso8601String(),
    };

    final response = await _dio.post(
      '/reports',
      data: body,
      options: Options(
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );

    final data = (response.data as Map)['data'] as Map?;
    if (data == null) throw ApiException('Gagal menyimpan laporan.');
    return FoundItemModel.fromReportJson(data.cast<String, dynamic>());
  }

  /// Mengubah status laporan ke `PUT /api/reports/:id`.
  Future<void> updateReportStatus(int id, String status) async {
    await _dio.put(
      '/reports/$id',
      data: {'status': status},
      options: Options(
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
  }

  Future<int> _getStoredUserId() async {
    final raw = await TokenStorage.readUserJson();
    if (raw == null || raw.isEmpty) return 0;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (map['id'] as num?)?.toInt() ?? 0;
    } on FormatException {
      return 0;
    }
  }
}