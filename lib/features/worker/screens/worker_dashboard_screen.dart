import 'package:flutter/material.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/data/auth_user.dart';
import '../../auth/screens/login_screen.dart';
import '../models/found_item_model.dart';
import '../state/found_items_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/found_item_card.dart';
import '../widgets/found_item_detail_sheet.dart';
import '../widgets/history_filter_bar.dart';
import '../widgets/quick_capture_card.dart';
import '../widgets/worker_header.dart';
import '../widgets/worker_profile_sheet.dart';
import 'quick_report_form_screen.dart';

/// Halaman utama Dashboard Petugas "Find It! — Petugas".
///
/// Menampilkan daftar barang temuan milik user yang login, diambil dari
/// backend. Ada state loading, error, dan empty.
class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  final _controller = FoundItemsController();
  final _auth = AuthRepository();
  AuthUser? _user;
  int _statusFilter = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _init();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _init() async {
    _user = await _auth.getStoredUser();
    if (mounted) setState(() {});
    await _controller.load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openReportForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QuickReportFormScreen()),
    );
    // Kembali dari form (berhasil submit) -> fresh daftar dari server.
    await _controller.load();
  }

  Future<void> _openDetail(FoundItemModel item) async {
    final changed = await showFoundItemDetail(
      context,
      item: item,
      onMarkClaimed: () => _controller.markAsClaimed(item),
    );
    if (changed == true && mounted) await _controller.load();
  }

  List<FoundItemModel> get _filteredItems {
    final all = _controller.items;
    switch (_statusFilter) {
      case 1:
        return all.where((i) => !i.isClaimed).toList();
      case 2:
        return all.where((i) => i.isClaimed).toList();
      default:
        return all;
    }
  }

  int get _unclaimedCount => _controller.items.length - _controller.claimedCount;

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          WorkerHeader(
            leading: const WorkerBrandLogo(),
            subtitle: 'Grand Meliá Jakarta',
            onAvatarTap: () => WorkerProfileSheet.show(
              context,
              user: _user,
              onLogout: () => _logout(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                QuickCaptureCard(onTap: _openReportForm),
                const SizedBox(height: 16),
                HistoryFilterBar(
                  selectedIndex: _statusFilter,
                  total: _controller.items.length,
                  unclaimed: _unclaimedCount,
                  claimed: _controller.claimedCount,
                  onChanged: (i) => setState(() => _statusFilter = i),
                ),
                const SizedBox(height: 12),
                if (_controller.loading && _controller.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_controller.hasError && _controller.items.isEmpty)
                  _errorBox()
                else if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: Text('Belum ada barang di filter ini.')),
                  )
                else
                  ...items.map((item) => FoundItemCard(item: item, onTap: () => _openDetail(item))),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.navy,
        onPressed: _openReportForm,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _errorBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off, color: Color(0xFFE11D48)),
          const SizedBox(height: 8),
          const Text(
            'Gagal memuat data. Periksa koneksi Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9F1239), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _controller.load,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Muat Ulang'),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) {
    _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}