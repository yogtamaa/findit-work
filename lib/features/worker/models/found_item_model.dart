/// Status internal untuk tampilan: belum diambil tamu / sudah selesai.
/// Pemetaan dari string status backend: `baru` -> logged, `dicocokkan` -> claimed.
enum FoundItemStatus { logged, claimed }

/// Model satu barang temuan yang dicatat worker/petugas kebersihan hotel.
///
/// Memetakan (sebagian besar) field dari model `Report` di backend
/// (`GET /api/reports`). Kategori disimpan sebagai string bebas mengikuti
/// nilai backend (daftar dari `GET /api/categories`), bukan enum lokal.
class FoundItemModel {
  FoundItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.description,
    required this.foundDate,
    this.photoPath,
    this.photoUrl,
    this.roomNumber,
    this.reportIdentifier,
    this.statusRaw = 'baru',
  });

  final String id;
  final String name;

  /// Nama kategori (mis. 'Elektronik', 'Dompet & Tas') sesuai backend.
  final String category;

  /// Lokasi/ruangan, mis. 'Kamar 412' atau 'Lantai 4'.
  final String location;
  final String description;
  final DateTime foundDate;

  /// Path file lokal hasil image_picker (belum tentu ter-upload).
  final String? photoPath;

  /// URL foto dari backend (`/uploads/...`), isinya relatif -> pakai ApiConfig.resolve.
  final String? photoUrl;

  /// Nomor kamar bila diisi (backend: `room_number`).
  final String? roomNumber;

  /// Nomor registrasi/tiket dari backend (mis. `FND-1726486400000000000`).
  final String? reportIdentifier;

  /// Status mentah backend (default `baru`). Diubah lewat
  /// FoundItemsController.markAsClaimed() lalu di-sync ke PUT /reports/:id.
  String statusRaw;

  bool get isClaimed => statusRaw == 'dicocokkan';

  String get statusLabel => isClaimed ? 'Selesai' : 'Belum Diklaim';

  FoundItemStatus get status => isClaimed ? FoundItemStatus.claimed : FoundItemStatus.logged;

  /// Label kamar untuk ditampilkan: pakai room_number bila ada, kalau tidak
  /// coba parsing dari location, terakhir fallback ke location.
  String get roomLabel {
    final rn = roomNumber;
    if (rn != null && rn.trim().isNotEmpty) return 'Kamar $rn';
    final m = RegExp(r'\b\d+\b').firstMatch(location);
    return m != null ? 'Kamar ${m.group(0)}' : location;
  }

  factory FoundItemModel.fromReportJson(Map<String, dynamic> json) {
    return FoundItemModel(
      id: json['id']?.toString() ?? '',
      name: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      location: json['location'] as String? ?? '',
      description: json['description'] as String? ?? '',
      foundDate: _parseDate(json['item_date']) ?? DateTime.now(),
      photoUrl: json['photo_url'] as String?,
      roomNumber: json['room_number'] as String?,
      reportIdentifier: json['report_identifier'] as String?,
      statusRaw: json['status'] as String? ?? 'baru',
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }
}