/// Hasil auto-fill dari `POST /api/reports/auto-fill`.
///
/// Foto selalu ter-upload (base endpoint tidak blocking), jadi [photoUrl]
/// selalu terisi kalau sukses 200. Bila AI gagal, [title]/[description]/
/// [category] kosong dan [confidence] = 0 -> UI harus biarkan RA isi manual.
class AutoFillResult {
  AutoFillResult({
    required this.photoUrl,
    this.title = '',
    this.description = '',
    this.category = '',
    this.confidence = 0,
  });

  final String photoUrl;
  final String title;
  final String description;
  final String category;

  /// Skor keyakinan AI 0.0 - 1.0 (backend memetakan high/medium/low ke 1.0/0.5/0.2).
  final double confidence;

  /// Apakah AI berhasil memberi data draft (title/category/description).
  bool get hasData =>
      title.trim().isNotEmpty ||
      description.trim().isNotEmpty ||
      category.trim().isNotEmpty;

  /// Skor confidence dalam persen bulat untuk ditampilkan (mis. "90%").
  int get confidencePercent => (confidence * 100).round().clamp(0, 100);

  /// Draft diragukan bila confidence < 0.7 -> UI tampilkan badge "Perlu dicek".
  bool get needsReview => confidence < 0.7;

  factory AutoFillResult.fromJson(Map<String, dynamic> json) {
    return AutoFillResult(
      photoUrl: json['photo_url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }
}