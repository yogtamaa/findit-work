import 'package:flutter/foundation.dart';

import '../../auth/data/auth_repository.dart';
import '../data/report_repository.dart';
import '../models/found_item_model.dart';

/// State management lokal & mandiri untuk modul Worker Dashboard.
///
/// Tetap memakai `ChangeNotifier` bawaan Flutter (sesuai konvensi project,
/// tanpa package state management eksternal). Data barang temuan sekarang
/// diambil dari backend FindIt API (GET /reports?type=found) milik user
/// yang sedang login, bukan lagi mock.
class FoundItemsController extends ChangeNotifier {
  FoundItemsController();

  final AuthRepository _auth = AuthRepository();
  final ReportRepository _report = ReportRepository();

  final List<FoundItemModel> _items = [];

  bool _loading = false;
  String? _error;

  List<FoundItemModel> get items => List.unmodifiable(_items);

  bool get loading => _loading;

  String? get error => _error;

  bool get hasError => _error != null;

  /// Jumlah barang yang ditemukan hari ini.
  int get todayCount {
    final now = DateTime.now();
    return _items
        .where((i) => i.foundDate.year == now.year && i.foundDate.month == now.month && i.foundDate.day == now.day)
        .length;
  }

  int get claimedCount => _items.where((i) => i.isClaimed).length;

  /// Label shift terdeteksi berdasarkan jam saat ini (untuk header dashboard).
  String get currentShiftLabel {
    final hour = DateTime.now().hour;
    if (hour >= 7 && hour < 15) return 'Shift Pagi (07:00-15:00)';
    if (hour >= 15 && hour < 23) return 'Shift Sore (15:00-23:00)';
    return 'Shift Malam (23:00-07:00)';
  }

  /// Memuat laporan temuan milik user yang sedang login dari backend.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final userId = (await _auth.getStoredUser())?.id ?? 0;
      final fetched = await _report.fetchMyFoundReports(userId);
      _items
        ..clear()
        ..addAll(fetched);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Menambahkan barang temuan (biasanya setelah submit berhasil dari form)
  /// ke paling atas daftar.
  void insertAtTop(FoundItemModel item) {
    _items.insert(0, item);
    notifyListeners();
  }

  /// Menandai barang sudah diambil tamu: update ke backend dulu
  /// (PUT /reports/:id status 'dicocokkan'), lalu sync list lokal.
  Future<bool> markAsClaimed(FoundItemModel item) async {
    try {
      final id = int.tryParse(item.id);
      if (id != null) {
        await _report.updateReportStatus(id, 'dicocokkan');
      }
      final idx = _items.indexWhere((i) => i.id == item.id);
      if (idx != -1) {
        _items[idx].statusRaw = 'dicocokkan';
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}